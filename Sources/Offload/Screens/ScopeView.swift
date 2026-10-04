import SwiftUI
import PhotosExportCore

/// Screen 5 — scope: "The last 10 photos" preselected by default, plus
/// "This year" and year chips (multi-select) with a photos-to-export count.
/// Matched-photo count + estimate always visible (fictional numbers).
struct ScopeView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                chip("The last 10 photos", selected: model.latestSelected) {
                    model.selectLatest()
                }
                chip("This year", selected: model.selectedYears == [WizardModel.currentYear]) {
                    model.selectThisYear()
                }
            }
            HStack(spacing: 8) {
                ForEach([2026, 2025, 2024, 2023], id: \.self) { year in
                    chip("\(year)", selected: model.selectedYears.contains(year)) {
                        model.toggleYear(year)
                    }
                }
            }
            if !model.latestSelected {
                HStack(spacing: 8) {
                    Text("Number of photos:")
                    ForEach(counts, id: \.self) { count in
                        chip(count.map(String.init) ?? "All", selected: model.exportCount == count) {
                            model.setExportCount(count)
                        }
                    }
                }
            }
            Text("≈ \(model.scopeTotal.formatted()) photos · est ~\(model.estimatedMinutes) min")
        }
    }

    private let counts: [Int?] = [10, 50, 100, nil]

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