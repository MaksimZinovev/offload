import SwiftUI

/// Screen 2 — the plan as a system-driven checklist: the user's 6 items
/// verbatim (never paraphrase), not user-checkable; item 1 auto-ticks when
/// the simulated device connects. Footer's Continue IS the consent.
struct NextStepsView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Here's the plan:")
            planRow("1. Connect iPhone via USB cable.", ticked: model.deviceConnected)
            planRow("2. Select photos to copy")
            planRow("3. Select destination folder")
            planRow("4. Complete copying process")
            planRow("5. Confirm if you want to delete photos from iPhone")
            planRow("6. Nothing is deleted.")
        }
    }

    /// A plan row: checkbox glyph (system-driven, no tap target) + verbatim text.
    private func planRow(_ text: String, ticked: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ticked ? "checkmark.square" : "square")
                .foregroundStyle(ticked ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
            Text(text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(ticked ? "checked" : "not checked")")
    }
}