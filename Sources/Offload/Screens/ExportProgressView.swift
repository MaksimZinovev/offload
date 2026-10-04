import SwiftUI
import AppKit

/// Screen 6 — mock copy progress. Show in Finder opens the real demo
/// folder; Cancel confirms before it does anything.
struct ExportProgressView: View {
    @ObservedObject var model: WizardModel
    @State private var showCancelConfirm = false

    var body: some View {
        if case .running(let done, let total) = model.run {
            VStack(spacing: 16) {
                Text("Copying \(done.formatted()) of \(total.formatted())")
                    .font(.title2)
                ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                Text(etaLabel(model.etaMinutes))
                HStack(spacing: 12) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.open(MockEngine.demoFolderURL)
                    }
                    Button("Cancel", role: .destructive) { showCancelConfirm = true }
                }
            }
            .confirmationDialog(
                "Cancel the copy?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Stop copying and go back", role: .destructive) {
                    model.cancelExport()
                }
            }
        }
    }

    private func etaLabel(_ minutes: Int) -> String {
        minutes == 1 ? "about 1 minute left" : "about \(minutes) minutes left"
    }
}