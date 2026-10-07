import SwiftUI

/// Screen 5 — "What photos do you want to copy?": independent checkboxes per
/// the mockup (chips + count-cap UI dropped; the model keeps `exportCount`,
/// unwired, for the real-ops cap). Counts + estimate always live below;
/// footer's "Clear selection" empties everything and Continue disables on an
/// empty selection.
struct ScopeView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What photos do you want to copy?")
            Toggle("The last 10 photos", isOn: latestBinding)
            Toggle("This year", isOn: yearBinding(WizardModel.currentYear))
            ForEach([2025, 2024, 2023], id: \.self) { year in
                Toggle(String(year), isOn: yearBinding(year))
            }
            Text("≈ \(model.scopeTotal.formatted()) photos · est ~\(model.estimatedMinutes) min")
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    /// "The last 10 photos" — preselected default, user-uncheckable.
    private var latestBinding: Binding<Bool> {
        Binding(
            get: { model.latestSelected },
            set: { model.setLatestSelected($0) }
        )
    }

    /// A year checkbox ("This year" is simply the current year's row).
    private func yearBinding(_ year: Int) -> Binding<Bool> {
        Binding(
            get: { model.selectedYears.contains(year) },
            set: { _ in model.toggleYear(year) }
        )
    }
}