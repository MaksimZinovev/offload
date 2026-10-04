import SwiftUI
import AppKit

/// Screen 4 — the one real system picker. Displays (only) that Offload
/// would create a subfolder; no directory is actually created.
struct DestinationView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Where should the copies go?")
            Button("Choose folder…") { chooseFolder() }
            if let destination = model.destination {
                Text("Offload will create: \(destination.path(percentEncoded: false))/Offload")
            } else {
                Text("No folder chosen yet.")
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose where Offload will copy your photos"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.destination = url
    }
}