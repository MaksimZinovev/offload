import SwiftUI

/// Screen 5 — one-tap scope presets with fictional counts and estimates.
struct ScopeView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        VStack(spacing: 10) {
            ForEach(ScopePreset.allCases, id: \.self) { preset in
                Button {
                    model.selectPreset(preset)
                } label: {
                    HStack {
                        Text(model.preset == preset ? "✓" : " ")
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text(preset.label)
                            Text("\(preset.photoCount.formatted()) photos · est ~\(preset.estimatedMinutes) min")
                        }
                    }
                }
            }
            Button("Custom range (later)") {}
                .disabled(true)
        }
    }
}