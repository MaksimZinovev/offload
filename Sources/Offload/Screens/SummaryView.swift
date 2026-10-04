import SwiftUI
import AppKit
import PhotosExportCore

/// Screen 7 — run summary, delete section (demo only), fresh-run / quit.
struct SummaryView: View {
    @ObservedObject var model: WizardModel

    @State private var deleteArmed = false
    @State private var deleteNote: String?

    var body: some View {
        if case .finished(let summary) = model.run {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library: \(ScopePreset.allYears.photoCount.formatted()) photos — unchanged")
                    Text("Exported: \(summary.exported.formatted()) to \(destinationText)")
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete exported photos?")
                    HStack(spacing: 12) {
                        Toggle("Delete (demo)", isOn: $deleteArmed)
                        Button("Delete (demo)") { deleteNote = "Nothing was deleted (demo)" }
                            .disabled(!deleteArmed)
                    }
                    if let deleteNote {
                        Text(deleteNote)
                    }
                }
                Divider()
                HStack(spacing: 12) {
                    Button("Export more") { model.exportMore() }
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
    }

    private var destinationText: String {
        let base = model.destination?.path(percentEncoded: false) ?? "?"
        return base + "/Offload"
    }
}