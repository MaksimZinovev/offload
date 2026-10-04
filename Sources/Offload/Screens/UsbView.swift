import SwiftUI

/// Screen 3 — backup-drive check with an explicit demo toggle.
struct UsbView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 16) {
            Text(model.driveConnected
                ? "Drive connected: UNTITLED (demo)"
                : "No drive detected — connect your backup drive.")
            Button(model.driveConnected ? "Remove it (demo)" : "(demo: simulate drive)") {
                model.driveConnected.toggle()
            }
        }
    }
}