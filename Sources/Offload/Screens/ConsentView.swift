import SwiftUI

/// Screen 2 — informed-consent plan. The footer's Continue IS the consent.
struct ConsentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here's the plan:")
            Text("I'll look at your library.")
            Text("You pick a drive; your photos are copied to it.")
            Text("Nothing is deleted.")
        }
    }
}