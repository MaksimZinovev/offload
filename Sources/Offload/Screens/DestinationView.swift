import SwiftUI
import AppKit

/// Screen 4 — the one real system picker. The default (~/Downloads) counts
/// as chosen; the app creates `<base>/Offload` — offload target shown below.
struct DestinationView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Where should the copied photos be saved?")
            Button("Choose folder…") { chooseFolder() }
            if let target = model.exportTargetURL {
                if model.destination == WizardModel.defaultDestination {
                    // Mockup: the suggested default in grey.
                    Text("Save in folder: \(WizardModel.homeRelativePath(target))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Will create: \(WizardModel.displayPath(target))")
                }
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