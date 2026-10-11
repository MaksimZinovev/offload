import Foundation
import ImageCaptureCore
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