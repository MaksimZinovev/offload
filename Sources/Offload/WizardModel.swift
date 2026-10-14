import Combine
import Foundation
import PhotosExportCore

/// The wizard's state machine. Single-threaded on the main actor; all state
/// is enum/Bool/URL values — no optional piles.
///
/// Types consumed from PhotosExportCore (ExportEvent, ExportRequest,
/// ExportSummary, YearSelection, LineLogger) are the real engine's types;
/// the event source is the mock by default (see MockEngine;
/// `OFFLOAD_ENGINE=real` runs the real engine instead).
@MainActor
final class WizardModel: ObservableObject {
    enum Step: Int {
        case welcome = 1, nextSteps, connectDevice, destination, photos, progress, summary
    }

    enum RunState {
        case idle
        case running(done: Int, total: Int)
        case finished(ExportSummary)
    }

    @Published private(set) var step: Step = .welcome
    @Published var deviceConnected = false
    /// Real-mode mirrors of DeviceSource's snapshot; mock mode never touches
    /// these (the name stays the fiction default, counts stay 0).
    @Published private(set) var deviceName = WizardModel.fictionDeviceName
    @Published private(set) var deviceItemCount = 0
    @Published private(set) var devicePhotoCount = 0
    @Published private(set) var deviceVideoCount = 0
    /// Default destination counts as chosen (grilling Q19) — never nil in practice.
    @Published var destination: URL? = WizardModel.defaultDestination
    // Screen 5: independent checkboxes. "The last 10 photos" is the
    // preselected default; "This year" is selectedYears = [currentYear].
    @Published private(set) var latestSelected = true
    @Published private(set) var selectedYears: Set<Int> = []
    /// No UI on the mockup's checkbox screen (the 10/50/100/All chips were
    /// dropped); kept per confirmed plan for the real-ops count cap.
    @Published private(set) var exportCount: Int? = 10
    @Published private(set) var run: RunState = .idle
    /// The estimate frozen at run start (FB1.1) — the progress ETA reads
    /// this, not the live scope walk (no O(n²) main-thread re-walk per
    /// transfer tick, and no live-count drift mid-run).
    private(set) var runEstimateMinutes = 0

    /// Fictional per-year photo counts. All four sum to 62,539 — the same
    /// whole-device total the Summary shows.
    static let yearCounts: [Int: Int] = [2026: 4_812, 2025: 11_234, 2024: 18_976, 2023: 27_517]
    static let currentYear = 2026

    // MARK: - Device mode (env OFFLOAD_DEVICE > in-app pref > demo fiction)

    /// The in-app toggle pref (APP1): "real" / "demo"; ABSENT = demo. Set from
    /// the Connect-device screen so the family flips it inside the app — no
    /// Terminal. In the app bundle, the `defaults`-CLI domain is the bundle
    /// id (com.maksimzinovev.Offload).
    static let deviceModePrefKey = "offload.deviceMode"

    /// Launch-time env override (dev/CI contract, unchanged): `OFFLOAD_DEVICE`
    /// set at all is decisive — exactly "real" forces real mode; ANY other
    /// value (incl. "off") forces demo EVEN IF the pref says real (escape
    /// hatch so tests/CI stay deterministic). nil = unset → the persisted
    /// pref decides.
    private static let envDeviceMode: Bool? =
        ProcessInfo.processInfo.environment["OFFLOAD_DEVICE"].map { $0 == "real" }

    /// Env-forced runs (dev/CI): the in-app toggle shows the resolved truth
    /// but cannot flip it (env-wins contract; deterministic for CI).
    static var deviceModeEnvForced: Bool { envDeviceMode != nil }

    /// Resolved real-vs-demo device mode (env > pref > demo). DYNAMIC after
    /// the in-app toggle (APP1) — every device-mode branch reads this, never
    /// a stored copy. Demo default: no pref + no env = false (today's
    /// behavior, byte-for-byte: no source, no extra publishes).
    @Published private(set) var usesRealDevice = false

    /// The demo (fiction) device name.
    static let fictionDeviceName = "iPhone 13 Pro"

    /// Real device plumbing (real mode only; nil in demo): the browser
    /// source starts at init in real mode, later on first toggle-to-real
    /// (a demo launch creates nothing); reused across toggles and "Export
    /// more" restarts, stopped at deinit. start()/stop() are a restartable
    /// pair (IC2 era).
    private var deviceSource: DeviceSource?
    private var deviceCancellable: AnyCancellable?

    init() {
        // Resolution order (APP1): env wins; else the persisted pref
        // (string "real" only); else the demo fiction default.
        if let forced = Self.envDeviceMode {
            usesRealDevice = forced
        } else {
            usesRealDevice = UserDefaults.standard.string(forKey: Self.deviceModePrefKey) == "real"
        }
        if usesRealDevice {
            ensureDeviceSource().start()
        }
    }

    deinit {
        // Nonisolated cleanup; the model deinits on the main thread
        // (@StateObject teardown), so the isolated hop below is safe.
        MainActor.assumeIsolated {
            deviceSource?.stop()
        }
    }

    /// Mirror the browser snapshot into the chrome fields (the sink exists
    /// only in real mode).
    private func applyDeviceSnapshot(_ snap: DeviceSnapshot) {
        deviceConnected = snap.connected
        if let name = snap.deviceName, !name.isEmpty { deviceName = name }
        deviceItemCount = snap.itemCount
        devicePhotoCount = snap.photoCount
        deviceVideoCount = snap.videoCount
    }

    // MARK: - In-app device-mode toggle (APP1; Connect-device screen only)

    /// Switch to the real phone: persist the pref and start the live browser
    /// (idempotent). Belt-and-braces idle guard — the toggle lives only on
    /// the Connect-device screen, which is unreachable mid-run.
    func enableRealDeviceMode() {
        guard case .idle = run, !usesRealDevice else { return }
        usesRealDevice = true
        UserDefaults.standard.set("real", forKey: Self.deviceModePrefKey)
        ensureDeviceSource().start()
    }

    /// Switch back to the demo fiction: stop the browser (the source object
    /// stays alive but stopped — same call deinit makes), restore the
    /// fiction device branch, persist "demo".
    func disableRealDeviceMode() {
        guard case .idle = run, usesRealDevice else { return }
        usesRealDevice = false
        UserDefaults.standard.set("demo", forKey: Self.deviceModePrefKey)
        // stop() publishes the empty snapshot, resetting connected/counts;
        // the name is deliberately left alone by the snapshot mirror, so the
        // fiction name is restored explicitly.
        deviceSource?.stop()
        deviceName = Self.fictionDeviceName
        deviceConnected = false
    }

    /// The real browser, created on first need (a demo launch has none) and
    /// reused across toggles; start()/stop() are the restart pair.
    private func ensureDeviceSource() -> DeviceSource {
        if let source = deviceSource { return source }
        let source = DeviceSource()
        deviceSource = source
        deviceCancellable = source.$snapshot.sink { [weak self] in
            self?.applyDeviceSnapshot($0)
        }
        return source
    }
    static var devicePhotos: Int { yearCounts.values.reduce(0, +) } // 62,539 — stays consistent with yearCounts
    static let deviceVideos = 1_842
    static let deviceSizeGB = 84
    static let deviceYearRange = 2018 ... 2026
    /// ~540 photos/min, rounded up (same rate as the scope estimate).
    static var deviceExportMinutes: Int { exportMinutes(for: devicePhotos) }

    /// Demo default (agreed): ~/Downloads — the picked BASE folder; the app
    /// creates `<base>/Offload` (grilling model), see `exportTargetURL`.
    static let defaultDestination = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads", isDirectory: true)

    /// The copy target: `<picked base>/Offload` — derived (nil-safe), never stored.
    /// In real mode this is the engine's exportBase (the engine writes <target>/YYYY/MM).
    var exportTargetURL: URL? { destination?.appendingPathComponent("Offload") }

    /// Path text without a trailing slash (URLs of directory targets keep one).
    static func displayPath(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Path text abbreviated under the home directory (for the suggested default).
    static func homeRelativePath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = displayPath(url)
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Selection (screen 5)

    func setLatestSelected(_ on: Bool) {
        latestSelected = on
    }

    /// Independent checkbox semantics — year checks leave the last-10 box alone.
    func toggleYear(_ year: Int) {
        if !selectedYears.insert(year).inserted {
            selectedYears.remove(year)
        }
    }

    /// Footer's "Clear selection": everything off (Continue disables on empty).
    func clearSelection() {
        latestSelected = false
        selectedYears = []
    }

    /// Photos the current selection matches.
    /// - Real-device mode (env or the in-app pref): the LIVE phone-catalog count
    ///   (DeviceSource.selectionCount — same walk semantics as the IC2
    ///   download prep). Catalog mid-enumeration shows the live count as-is
    ///   (possibly 0 → Continue stays disabled). Empty selection → 0.
    /// - Real-engine mode (OFFLOAD_ENGINE=real, Mac libraries): STILL the
    ///   fictional yearCounts — an engine-side count API is the later
    ///   bridge; no PHAsset fetches are invented here.
    var scopeTotal: Int {
        if usesRealDevice, let source = deviceSource {
            return source.selectionCount(
                for: latestSelected ? DeviceSelection.latest(exportCount ?? 10) : .years(selectedYears.sorted())
            )
        }
        return (latestSelected ? 10 : 0) + selectedYears.reduce(0) { $0 + (Self.yearCounts[$1] ?? 0) }
    }

    /// ~540 photos/min, rounded up — the transfer-rate fiction stays for
    /// now; in real-device mode the SCALE it applies to is the real count.
    var estimatedMinutes: Int { Self.exportMinutes(for: scopeTotal) }

    static func exportMinutes(for photos: Int) -> Int {
        max(1, Int((Double(photos) / 540).rounded(.up)))
    }

    // MARK: - Navigation

    var canGoBack: Bool {
        switch step {
        case .welcome, .progress, .summary: false
        default: true
        }
    }

    func back() {
        guard canGoBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Continue on the current step. Gates mirror the per-screen button
    /// disabling; the button is the primary gate, this guards behind it.
    /// Destination has no gate — the default counts as chosen (Q19).
    func next() {
        switch step {
        case .connectDevice: guard deviceConnected else { return }
        default: break
        }
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    // MARK: - Export (screens 5-7)

    /// Engine switch: `OFFLOAD_ENGINE=real` runs the real engine; unset or any
    /// other value keeps the mock, so plain `swift run` behaves exactly as
    /// before. Read once, at first export.
    private static let usesRealEngine =
        ProcessInfo.processInfo.environment["OFFLOAD_ENGINE"] == "real"

    func startExport() {
        guard case .idle = run, scopeTotal > 0, let exportBase = exportTargetURL else { return }
        step = .progress
        let selection: YearSelection
        if latestSelected {
            // The latest 10 — a count-based fetch the real engine grows later;
            // .currentYear is the documented approximation (whole current year,
            // real mode included). The mock treats .currentYear as
            // "whatever the wizard showed".
            selection = .currentYear
        } else {
            let years = selectedYears.sorted()
            if years.count == 1 {
                selection = .year(years[0])
            } else if let first = years.first, let last = years.last {
                selection = .range(start: first, end: last)
            } else {
                return
            }
        }
        // The engine writes <exportBase>/YYYY/MM, so exportBase is the product
        // target <picked>/Offload (Q19, derived) — not the picked base; the mock
        // ignores the path. Device mode (OFFLOAD_DEVICE=real) downloads from
        // the live phone instead — its .latest choice maps to the N most
        // recent items by capture date (real device semantics; supersedes the
        // .currentYear approximation for the device path only).
        let request = ExportRequest(exportBase: exportBase, selection: selection)
        // Freeze the progress ETA once per run (FB1.1): one scope walk here,
        // not one per transfer tick. Same number outside device mode anyway.
        runEstimateMinutes = estimatedMinutes
        exportTask = Task {
            do {
                let summary: ExportSummary
                if usesRealDevice, let source = deviceSource {
                    summary = try await source.download(
                        selection: latestSelected ? DeviceSelection.latest(exportCount ?? 10) : .years(selectedYears.sorted()),
                        target: exportBase
                    ) { [weak self] event in
                        self?.handleEvent(event)
                    }
                } else if Self.usesRealEngine {
                    summary = try await PhotosExportCore.exportAssets(request) { [weak self] event in
                        self?.handleEvent(event)
                    }
                } else {
                    summary = try await MockEngine.exportAssets(request, limit: scopeTotal) { [weak self] event in
                        self?.handleEvent(event)
                    }
                }
                run = .finished(summary)
                step = .summary
            } catch {
                // Cancellation (or a fatal engine error) returns to the selection step.
                run = .idle
                step = .photos
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    private func handleEvent(_ event: ExportEvent) {
        switch event {
        case .started(let total):
            run = .running(done: 0, total: total)
        case .assetExported(let index, let total, _):
            // The engine emits 0-based indices; `done` is 1-based.
            run = .running(done: index + 1, total: total)
        case .assetFailed, .warning:
            break // by design (mock, device, engine alike): the run continues; ExportSummary carries the numbers
        }
    }

    /// Progress screen's ETA: the selection estimate frozen at run start
    /// (FB1.1: per-tick re-renders read the stored capture — no per-item
    /// catalog walk on main, and the number can't drift mid-run). Idle
    /// falls back to the live computed estimate (no own pacing model; the
    /// rate-fiction note above applies).
    var etaMinutes: Int {
        switch run {
        case .idle: estimatedMinutes
        case .running, .finished: runEstimateMinutes
        }
    }

    // MARK: - Fresh run (after summary)

    /// "Export more": full reset to a fresh run — defaults restored, back to
    /// Welcome (nothing kept).
    func exportMore() {
        exportTask?.cancel()
        run = .idle
        latestSelected = true
        selectedYears = []
        destination = Self.defaultDestination
        if !usesRealDevice {
            // Real phone stays connected — the browser keeps the truth.
            deviceConnected = false
        }
        step = .welcome
    }

    private var exportTask: Task<Void, Never>?
}