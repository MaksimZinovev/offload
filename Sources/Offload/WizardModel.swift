import Foundation
import PhotosExportCore

/// The wizard's state machine. Single-threaded on the main actor; all state
/// is enum/Bool/URL values — no optional piles.
///
/// Types consumed from PhotosExportCore (ExportEvent, ExportRequest,
/// ExportSummary, YearSelection, LineLogger) are the real engine's types;
/// only the event source is fake (see MockEngine).
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

    // MARK: - Device (simulated; the unfolded details rows)

    static let deviceName = "iPhone 13 Pro"
    static var devicePhotos: Int { yearCounts.values.reduce(0, +) } // 62,539 — stays consistent with yearCounts
    static let deviceVideos = 1_842
    static let deviceSizeGB = 84
    static let deviceYearRange = 2018 ... 2026
    /// ~540 photos/min, rounded up (same rate as the scope estimate).
    static var deviceExportMinutes: Int { exportMinutes(for: devicePhotos) }

    /// Demo default (agreed): ~/Downloads/Offload, shown home-relative.
    static let defaultDestination = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads", isDirectory: true)
        .appendingPathComponent("Offload", isDirectory: true)

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

    func startExport() {
        guard let destination, case .idle = run, scopeTotal > 0 else { return }
        step = .progress
        let selection: YearSelection
        if latestSelected {
            // The latest 10 — a count-based fetch the real engine grows later;
            // the mock treats .currentYear as "whatever the wizard showed".
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
        // The real engine will take no `limit`; the mock uses it to know the
        // displayed total (see MockEngine). This is the one call site to
        // change when swapping in the real engine.
        let request = ExportRequest(exportBase: destination, selection: selection)
        exportTask = Task {
            do {
                let summary = try await MockEngine.exportAssets(request, limit: scopeTotal) { [weak self] event in
                    self?.handleEvent(event)
                }
                run = .finished(summary)
                step = .summary
            } catch {
                // Cancellation (or a fatal mock error) returns to the selection step.
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
            break
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
        deviceConnected = false
        step = .welcome
    }

    private var exportTask: Task<Void, Never>?
}