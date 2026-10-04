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
    @Published private(set) var preset: ScopePreset?

    /// Screen 5's one-tap selection.
    func selectPreset(_ preset: ScopePreset) {
        self.preset = preset
    }
    @Published private(set) var run: RunState = .idle

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
        case .scope: guard preset != nil else { return }
        default: break
        }
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    // MARK: - Export (screens 5-7)

    func startExport() {
        guard let destination, let preset, case .idle = run else { return }
        step = .progress
        // The real engine will take no `limit`; the mock uses it to know the
        // displayed total (see MockEngine). This is the one call site to
        // change when swapping in the real engine.
        let limit = preset.photoCount
        let request = ExportRequest(exportBase: destination, selection: .currentYear)
        exportTask = Task {
            do {
                let summary = try await MockEngine.exportAssets(request, limit: limit) { [weak self] event in
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

    /// Progress screen's ETA: the scope estimate the user already saw on
    /// the Scope screen (the mock is fictional; no own pacing model).
    var etaMinutes: Int { preset?.estimatedMinutes ?? 1 }

    // MARK: - Fresh run (after summary)

    /// "Export more": full reset to a fresh run — re-scan, nothing kept.
    func exportMore() {
        exportTask?.cancel()
        run = .idle
        preset = nil
        destination = nil
        driveConnected = false
        step = .intro
        beginAnalysis()
    }
}

/// The three scope presets. Value-type data; counts and estimates derive
/// from the fictional library numbers.
enum ScopePreset: CaseIterable, Hashable {
    case recent10
    case thisYear
    case allYears

    var label: String {
        switch self {
        case .recent10: "The last 10 photos"
        case .thisYear: "This year"
        case .allYears: "All years"
        }
    }

    /// Fictional counts: 10 / 4,812 (this year) / 62,539 (all years).
    var photoCount: Int {
        switch self {
        case .recent10: 10
        case .thisYear: 4812
        case .allYears: 62539
        }
    }

    /// ~540 photos/min, rounded up.
    var estimatedMinutes: Int {
        max(1, Int((Double(photoCount) / 540).rounded(.up)))
    }
}