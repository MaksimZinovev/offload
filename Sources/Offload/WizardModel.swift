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

    /// Fictional per-year photo counts. All four sum to 62,539 — the same
    /// whole-device total the Summary shows.
    static let yearCounts: [Int: Int] = [2026: 4_812, 2025: 11_234, 2024: 18_976, 2023: 27_517]
    static let currentYear = 2026

    // MARK: - Device (OFFLOAD_DEVICE=real: live browser truth; demo fiction otherwise)

    /// Mirrors the engine gate: OFFLOAD_DEVICE=real runs the live
    /// ICDeviceBrowser (DeviceSource); anything else/absent keeps the demo
    /// toggle fiction byte-for-byte.
    static let usesRealDevice =
        ProcessInfo.processInfo.environment["OFFLOAD_DEVICE"] == "real"

    /// The demo (fiction) device name.
    static let fictionDeviceName = "iPhone 13 Pro"

    /// Real device plumbing (real mode only; nil otherwise): one browser
    /// started at init, reused across "Export more" restarts, stopped at
    /// deinit (no leak between wizard restarts).
    private let deviceSource: DeviceSource?
    private var deviceCancellable: AnyCancellable?

    init() {
        if Self.usesRealDevice {
            let source = DeviceSource()
            deviceSource = source
            deviceCancellable = source.$snapshot.sink { [weak self] in
                self?.applyDeviceSnapshot($0)
            }
            source.start()
        } else {
            deviceSource = nil
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

    /// Photos the current selection matches (fictional; sums the checked boxes).
    var scopeTotal: Int {
        (latestSelected ? 10 : 0) + selectedYears.reduce(0) { $0 + (Self.yearCounts[$1] ?? 0) }
    }

    /// ~540 photos/min, rounded up.
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
        // ignores the path. The real engine takes no `limit` (the mock uses it
        // for the displayed total, see MockEngine). OFFLOAD_ENGINE=real swaps
        // the mock for the real engine; the event mapping and catch are shared.
        let request = ExportRequest(exportBase: exportBase, selection: selection)
        exportTask = Task {
            do {
                let summary: ExportSummary
                if Self.usesRealEngine {
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
            break // by design (mock included): the run continues; ExportSummary carries the numbers
        }
    }

    /// Progress screen's ETA: the selection estimate (fictional; no own pacing
    /// model in the mock).
    var etaMinutes: Int { estimatedMinutes }

    // MARK: - Fresh run (after summary)

    /// "Export more": full reset to a fresh run — defaults restored, back to
    /// Welcome (nothing kept).
    func exportMore() {
        exportTask?.cancel()
        run = .idle
        latestSelected = true
        selectedYears = []
        destination = Self.defaultDestination
        if !Self.usesRealDevice {
            // Real phone stays connected — the browser keeps the truth.
            deviceConnected = false
        }
        step = .welcome
    }

    private var exportTask: Task<Void, Never>?
}