import SwiftUI

/// Screen 1 — simulated library analysis.
struct IntroView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        switch model.analysis {
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text("Looking at your library…")
            }
        case .done(let photos, let gb, let minutes):
            VStack(alignment: .leading, spacing: 8) {
                Text("\(photos.formatted()) photos this year")
                Text("\(gb) GB")
                Text("about \(minutes) min estimated")
            }
        }
    }
}