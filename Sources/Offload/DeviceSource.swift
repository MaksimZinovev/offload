import Foundation
import ImageCaptureCore
import PhotosExportCore
import UniformTypeIdentifiers

/// One device seen through the ImageCaptureCore browser — the wizard's
/// real-mode truth (IC1). Photo/video split falls out of item UTIs for free;
/// stats we cannot derive (GB size, year range) are not here at all.
struct DeviceSnapshot {
    var connected = false
    var deviceName: String?
    /// Media files on the camera (`camera.mediaFiles`: image, movie, audio;
    /// folders excluded). 0 while the session opens / enumerates — nothing is
    /// fabricated meanwhile; the completed-catalog signal is the final word.
    var itemCount = 0
    var photoCount = 0
    var videoCount = 0
}

/// Real iPhone discovery (OFFLOAD_DEVICE=real): ICDeviceBrowser over USB
/// cameras; the first ICCameraDevice gets an open session (which triggers the
/// phone-side "Allow This Device to Access Photos and Videos" prompt — the
/// user's native approval); counts read `camera.mediaFiles` at each publish —
/// batch boundaries (didAdd/didRemove, catalog completion), never per-frame.
/// The only ImageCaptureCore import in this target (IC1 contract).
///
/// Threading: ICC delegate callbacks can arrive off-main — every callback
/// hops to the main actor before touching state. ICDevice delegates are
/// `assign` (not retained), so `stop()` nils them before teardown.
@MainActor
final class DeviceSource: NSObject, ObservableObject {
    @Published private(set) var snapshot = DeviceSnapshot()

    private var browser: ICDeviceBrowser?
    private var camera: ICCameraDevice?
    /// Completion outlet of the live download run (nil between runs); the
    /// download loop consumes it, and teardown/removal finish() it.
    private var downloadStream: AsyncStream<DownloadResult>.Continuation?

    private enum ItemKind { case photo, video, other }

    /// One iPhone is the shape of the product; extra cameras stay ignored.
    /// The default browsedDeviceTypeMask already covers USB-attached cameras
    /// (camera type + local/shared location bits, per Apple's docs) — the
    /// Swift enum import cannot express the ObjC OR-d mask otherwise.
    func start() {
        guard browser == nil else { return }
        let browser = ICDeviceBrowser()
        browser.delegate = self
        browser.start()
        self.browser = browser
    }

    /// Idempotent stop — the single teardown path (model deinit); "Export
    /// more" restarts reuse the one browser. Delegates are nil'd before the
    /// framework objects are released (ICDevice delegates are assign).
    func stop() {
        browser?.delegate = nil
        camera?.delegate = nil
        camera?.requestCloseSession()
        camera = nil
        browser?.stop()
        browser = nil
        downloadStream?.finish() // aborts a run in progress
        downloadStream = nil
        snapshot = DeviceSnapshot()
    }

    // MARK: - Main-actor handlers (delegate bridge targets)

    private func cameraAdded(_ device: ICDevice) {
        guard camera == nil, let camera = device as? ICCameraDevice else { return }
        self.camera = camera
        camera.delegate = self
        camera.requestOpenSession()
        publishSnapshot()
    }

    private func cameraRemoved(_ device: ICDevice) {
        guard camera != nil, device === camera else { return }
        camera = nil
        downloadStream?.finish() // a run in progress aborts with its stream
        downloadStream = nil
        publishSnapshot()
    }

    private static func itemKind(_ item: ICCameraItem) -> ItemKind {
        guard let uti = item.uti, let type = UTType(uti) else { return .other }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .image) { return .photo }
        return .other
    }

    private func publishSnapshot() {
        var snap = DeviceSnapshot()
        snap.connected = camera != nil
        if let camera {
            snap.deviceName = camera.name ?? camera.productKind ?? "iPhone"
            // One walk per publish; publishes are batch-boundary events, so
            // this stays at batch cost even for the full 2,425-item catalog.
            let mediaFiles = camera.mediaFiles ?? []
            snap.itemCount = mediaFiles.count
            for item in mediaFiles {
                switch Self.itemKind(item) {
                case .photo: snap.photoCount += 1
                case .video: snap.videoCount += 1
                case .other: break
                }
            }
        }
        snapshot = snap
    }

    // MARK: - Download (IC2: real device source)

    /// Downloads the selection into `target/YYYY/MM` (capture date, native
    /// camera filenames) and drives the wizard's existing event stream.
    /// Sequential: one ICC transfer in flight, next issued on completion —
    /// ICC serializes over USB anyway; abort/cancellation stay trivial.
    func download(
        selection: DeviceSelection,
        target: URL,
        onEvent: @escaping (ExportEvent) -> Void
    ) async throws -> ExportSummary {
        guard let camera, camera.hasOpenSession, let mediaFiles = camera.mediaFiles else {
            // Breadcrumb: camera/session gone at export time (unplug or the
            // locked-phone teardown) — throws into the wizard's catch.
            throw DeviceDownloadError.cameraUnavailable
        }

        // Prep: photo/video media only (mediaFiles also carries audio);
        // missing creation date → skipped (never crashed, never attempted);
        // destination YYYY/MM from the capture date; ICC saves with the
        // item's native filename (ICSaveAsFilename not set).
        let calendar = Calendar.current
        var preparedItems: [(file: ICCameraFile, isVideo: Bool, date: Date, directory: URL)] = []
        for item in mediaFiles {
            guard let file = item as? ICCameraFile,
                  let date = file.creationDate,
                  let year = calendar.dateComponents([.year, .month], from: date).year,
                  let month = calendar.dateComponents([.year, .month], from: date).month
            else { continue }
            let isVideo: Bool
            switch Self.itemKind(item) {
            case .photo: isVideo = false
            case .video: isVideo = true
            case .other: continue // audio/sidecars: not this product's media
            }
            let directory = target
                .appendingPathComponent(String(year))
                .appendingPathComponent(String(format: "%02d", month))
            preparedItems.append((file, isVideo, date, directory))
        }
        switch selection {
        case .latest(let count):
            // Real device semantics: the 10 most recent by capture date (this
            // supersedes the .currentYear approximation for the device path;
            // the engine's file-source path keeps .currentYear).
            preparedItems.sort { $0.date > $1.date }
            preparedItems = Array(preparedItems.prefix(count))
        case .years(let years):
            preparedItems = preparedItems.filter { years.contains(calendar.component(.year, from: $0.date)) }
        }

        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        onEvent(.started(total: preparedItems.count))

        let (stream, continuation) = AsyncStream<DownloadResult>.makeStream()
        self.downloadStream = continuation
        defer {
            downloadStream = nil
            continuation.finish()
        }

        var iterator = stream.makeAsyncIterator()
        var exportedCount = 0
        var failedCount = 0
        var errorLines: [String] = []

        for (index, prepared) in preparedItems.enumerated() {
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: prepared.directory, withIntermediateDirectories: true)
            // Overwrite left off: rerun collisions surface as logged failures,
            // not silent overwrites (incremental mode is a later slice).
            _ = prepared.file.requestDownload(
                options: [.downloadsDirectoryURL: prepared.directory]
            ) { filename, error in
                Self.onMain {
                    // Late completions after a finish() are discarded by the
                    // finished stream — no continuation hazards.
                    continuation.yield(DownloadResult(saved: filename, error: error))
                }
            }
            guard let result = await iterator.next() else {
                // Device removed / teardown mid-run; CancellationError when
                // the wizard cancelled. An in-flight transfer may still land
                // its file in the folder — harmless leftover.
                throw Task.isCancelled ? CancellationError() : DeviceDownloadError.cameraUnavailable
            }
            if let error = result.error {
                failedCount += 1
                errorLines.append(
                    "\(Date()) device=download name=\(prepared.file.name ?? "?") dest=\(prepared.directory.path) \(error.localizedDescription)"
                )
                onEvent(.assetFailed(index: index, total: preparedItems.count, isVideo: prepared.isVideo, summary: error.localizedDescription))
                let nsError = error as NSError
                if nsError.domain == "com.apple.ImageCaptureCore", nsError.code == -9943 {
                    // Breadcrumb for the UX pass: surface "unlock the phone"
                    // on the copying screen; IC2 fails the run into the
                    // wizard's catch (back to .photos).
                    throw DeviceDownloadError.phoneLocked
                }
            } else {
                exportedCount += 1
                onEvent(.assetExported(index: index, total: preparedItems.count, isVideo: prepared.isVideo))
            }
        }

        let logURL = target.appendingPathComponent("export_errors.log")
        if failedCount > 0, !errorLines.isEmpty {
            try? errorLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
        }
        return ExportSummary(
            exported: exportedCount,
            failed: failedCount,
            total: preparedItems.count,
            errorLogURL: logURL
        )
    }

    // MARK: - Selection count (FB1: real numbers on the estimate line)

    /// Live-catalog count for a screen-5 selection — the estimator-side
    /// mirror of the IC2 download prep (same walk: photo/video media only,
    /// missing creation date skipped, never crash). Pull-style: the model
    /// calls this on need (a ~2.4K-item walk is bounded; no new publishes).
    /// Catalog 0/incomplete shows the live count as-is — never a placeholder.
    func selectionCount(for selection: DeviceSelection) -> Int {
        guard let camera, camera.hasOpenSession, let mediaFiles = camera.mediaFiles else { return 0 }
        let calendar = Calendar.current
        var eligibleDates: [Date] = []
        for item in mediaFiles {
            guard let file = item as? ICCameraFile, let date = file.creationDate,
                  Self.itemKind(item) != .other else { continue }
            eligibleDates.append(date)
        }
        switch selection {
        case .latest(let count):
            // N most recent by capture date → min(N, eligible).
            return min(count, eligibleDates.count)
        case .years(let years):
            let yearSet = Set(years)
            return eligibleDates.filter { yearSet.contains(calendar.component(.year, from: $0)) }.count
        }
    }

    /// ICC callbacks arrive off-main; all state above is main-actor.
    private nonisolated static func onMain(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            Task { @MainActor in body() }
        }
    }
}

// MARK: - ICDeviceBrowserDelegate (required: didAdd / didRemove)

extension DeviceSource: @preconcurrency ICDeviceBrowserDelegate {
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        Self.onMain { self.cameraAdded(device) }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        Self.onMain { self.cameraRemoved(device) }
    }
}

// MARK: - ICCameraDeviceDelegate (inherits ICDeviceDelegate's required trio)

extension DeviceSource: @preconcurrency ICCameraDeviceDelegate {
    func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {
        // Open result — the phone-side allow/deny is the user's business; if
        // denied, the device shows named-but-unenumerated, which is honest.
        // Breadcrumb for IC2 (downloads): ICC returns -9943
        // "Please unlock <name>" here while the phone is locked — yet a
        // cached catalog still arrives; downloads need the unlocked state.
        Self.onMain {}
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {
        Self.onMain {}
    }

    func didRemove(_ device: ICDevice) {
        Self.onMain { self.cameraRemoved(device) }
    }

    func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
        Self.onMain { self.publishSnapshot() }
    }

    func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {
        Self.onMain { self.publishSnapshot() }
    }

    func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        Self.onMain { self.publishSnapshot() } // final read after all batches
    }

    // Required by the protocol; the discovery slice has nothing for them.
    func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: (any Error)?) {}
    func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: (any Error)?) {}
    func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
    func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}
    func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}
}

// MARK: - Download types (IC2)

/// Screen-5 selection in real device semantics (see DeviceSource.download).
enum DeviceSelection {
    case latest(Int)
    case years([Int])
}

/// Failures that abort a device download run into the wizard's catch.
enum DeviceDownloadError: Error {
    /// No ICCameraDevice with an open session at export time.
    case cameraUnavailable
    /// ICC -9943: the phone is locked (or the phone-side prompt was denied).
    case phoneLocked
}

private struct DownloadResult {
    let saved: String?
    let error: Error?
}