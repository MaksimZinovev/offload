import SwiftUI

/// Screen 5 — selection. Checkbox layout per mockup lands at CP4; chips keep
/// the screen working with the new independent-selection model in the
/// meantime (2026 is "This year", not a separate chip).
struct ScopeView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                chip("The last 10 photos", selected: model.latestSelected) {
                    model.setLatestSelected(!model.latestSelected)
                }
                chip("This year", selected: model.selectedYears.contains(WizardModel.currentYear)) {
                    model.toggleYear(WizardModel.currentYear)
                }
            }
            HStack(spacing: 8) {
                ForEach([2025, 2024, 2023], id: \.self) { year in
                    chip("\(year)", selected: model.selectedYears.contains(year)) {
                        model.toggleYear(year)
                    }
                }
            }
            Text("≈ \(model.scopeTotal.formatted()) photos · est ~\(model.estimatedMinutes) min")
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}