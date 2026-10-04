import SwiftUI

/// Screen 3 — iPhone connection check with an explicit demo toggle.
struct UsbView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 16) {
            Text(model.driveConnected
                ? "iPhone connected: Dad's iPhone (demo)"
                : "Connect your iPhone with a USB cable.")
            Button(model.driveConnected ? "Remove it (demo)" : "(demo: simulate iPhone)") {
                model.driveConnected.toggle()
            }
        }
    }
}