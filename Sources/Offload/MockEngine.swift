import Foundation
import PhotosExportCore

/// Placeholder engine, shaped like the real call:
/// `PhotosExportCore.exportAssets(_:logger:onEvent:)` plus a demo `limit`.
/// No Photos import, no real copying — the only real touch is creating a
/// temp demo folder with a few dummy files so "Show in Finder" has content.
///
/// Pacing: one event every `tickInterval` seconds (350ms). The engine makes
/// at most `min(displayTotal, 120)` ticks; the displayed index accelerates,
/// advancing `ceil(displayTotal / tickCount)` per tick so the run always
/// completes in roughly 40 seconds for large selections:
///
///   recent10: displayTotal = 10    -> 10 ticks × 1 = 10        (~3.5s)
///   thisYear: displayTotal = 4812  -> ceil(4812/120) = 41/tick, 118 ticks (~41s)
///   allYears: displayTotal = 62539 -> ceil(62539/120) = 522/tick, 120 ticks (~42s)
///
/// ETA is not emitted; the model shows the scope screen's estimate.
enum MockEngine {
    static let tickInterval: TimeInterval = 0.35

    /// The demo folder the mock pre-creates — the one real "Show in Finder"
    /// target (plus the folder picker).
    static let demoFolderURL: URL =
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Offload-Demo-Export", isDirectory: true)

    static func exportAssets(
        _ request: ExportRequest,
        limit: Int? = nil,
        logger: LineLogger? = nil,
        onEvent: @escaping (ExportEvent) -> Void
    ) async throws -> ExportSummary {
        _ = request
        _ = logger

        // Real touch (agreed): tiny demo folder with dummy content.
        try FileManager.default.createDirectory(at: demoFolderURL, withIntermediateDirectories: true)
        let demoFiles = [
            "demo_photo_001.jpg",
            "demo_photo_002.jpg",
            "readme_from_offload.txt",
        ]
        for (i, name) in demoFiles.enumerated() {
            let body = Data("Offload demo export placeholder file \(i + 1).\n".utf8)
            FileManager.default.createFile(
                atPath: demoFolderURL.appendingPathComponent(name).path,
                contents: body
            )
        }
        let errorLogURL = demoFolderURL.appendingPathComponent("export_errors.log")

        let displayTotal = limit ?? 4812 // fictional count per .currentYear selection
        let tickCount = min(displayTotal, 120)
        let perTick = max(1, Int((Double(displayTotal) / Double(tickCount)).rounded(.up)))

        onEvent(.started(total: displayTotal))

        var shown = 0
        for tick in 0..<tickCount {
            try await Task.sleep(for: .seconds(tickInterval))
            try Task.checkCancellation()
            shown = min(perTick * (tick + 1), displayTotal)
            // The real engine's indices are 0-based — mirror that exactly.
            onEvent(.assetExported(index: shown - 1, total: displayTotal, isVideo: tick % 5 == 4))
            if shown == displayTotal { break }
        }

        return ExportSummary(
            exported: shown,
            failed: 0,
            total: displayTotal,
            errorLogURL: errorLogURL
        )
    }
}