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
        case intro = 1, consent, usb, destination, scope, progress, summary
    }

    enum Analysis: Equatable {
        case scanning
        case done(photos: Int, gb: Int, minutes: Int)
    }

    enum RunState {
        case idle
        case running(done: Int, total: Int)
        case finished(ExportSummary)
    }

    @Published private(set) var step: Step = .intro
    @Published private(set) var analysis: Analysis = .scanning
    @Published var driveConnected = false
    @Published var destination: URL?
    // Scope (screen 5): "The last 10 photos" is the preselected small-batch
    // default; year chips + export count refine it (per user-experience.md).
    @Published private(set) var latestSelected = true
    @Published private(set) var selectedYears: Set<Int> = []
    @Published private(set) var exportCount: Int? = 10
    @Published private(set) var run: RunState = .idle

    /// Fictional per-year library counts (sums to 62,539 = "all years").
    static let yearCounts: [Int: Int] = [2026: 4_812, 2025: 11_234, 2024: 18_976, 2023: 27_517]
    static let currentYear = 2026

    // MARK: - Scope (screen 5)

    func selectLatest() {
        latestSelected = true
        selectedYears = []
    }

    func selectThisYear() {
        latestSelected = false
        selectedYears = [Self.currentYear]
    }

    func toggleYear(_ year: Int) {
        latestSelected = false
        if !selectedYears.insert(year).inserted {
            selectedYears.remove(year)
        }
    }

    /// Number of photos to export; nil = All.
    func setExportCount(_ count: Int?) {
        exportCount = count
    }

    /// Photos the current scope matches (fictional).
    var scopeTotal: Int {
        if latestSelected { return 10 }
        let yearsSum = selectedYears.reduce(0) { $0 + (Self.yearCounts[$1] ?? 0) }
        return exportCount.map { min($0, yearsSum) } ?? yearsSum
    }

    /// ~540 photos/min, rounded up.
    var estimatedMinutes: Int {
        max(1, Int((Double(scopeTotal) / 540).rounded(.up)))
    }

    private var scanTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?

    init() {
        beginAnalysis()
    }

    // MARK: - Analysis (screen 1)

    /// Simulated library scan: ~2s spinner, then fictional numbers.
    func beginAnalysis() {
        scanTask?.cancel()
        analysis = .scanning
        scanTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            analysis = .done(photos: 4812, gb: 38, minutes: 9)
        }
    }

    // MARK: - Navigation

    var canGoBack: Bool {
        switch step {
        case .intro, .progress, .summary: false
        default: true
        }
    }

    func back() {
        guard canGoBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Continue on the current step. Gates mirror the per-screen button
    /// disabling; the button is the primary gate, this guards behind it.
    func next() {
        switch step {
        case .usb: guard driveConnected else { return }
        case .destination: guard destination != nil else { return }
        case .scope: guard scopeTotal > 0 else { return }
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
                // Cancellation (or a fatal mock error) returns to the scope step.
                run = .idle
                step = .scope
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

    /// Progress screen's ETA: the scope estimate (fictional; no own pacing
    /// model in the mock).
    var etaMinutes: Int { estimatedMinutes }

    // MARK: - Fresh run (after summary)

    /// "Export more": full reset to a fresh run — re-scan, nothing kept.
    func exportMore() {
        exportTask?.cancel()
        run = .idle
        selectLatest()
        exportCount = 10
        destination = nil
        driveConnected = false
        step = .intro
        beginAnalysis()
    }
}