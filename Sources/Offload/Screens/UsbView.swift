import SwiftUI

/// Screen 3 — iPhone connection check with an explicit demo toggle.
/// (Full rework at CP3: layout per mockup + right-side connection visual.)
struct UsbView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 16) {
            Text(model.deviceConnected
                ? "iPhone connected: \(WizardModel.deviceName) (demo)"
                : "Connect your iPhone with a USB cable.")
            Button(model.deviceConnected ? "Remove it (demo)" : "(demo: simulate iPhone)") {
                model.deviceConnected.toggle()
            }
        }
    }
}