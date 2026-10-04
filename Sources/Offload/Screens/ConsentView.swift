import SwiftUI

/// Screen 2 — the plan, verbatim from user-experience.md ("Step 3 —
/// Show user concise list of what to expect"). Footer's Continue IS the consent.
struct ConsentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here's the plan:")
            Text("1. Connect iPhone via USB cable.")
            Text("2. Select photos to copy")
            Text("3. Select destination folder")
            Text("4. Complete copying process")
            Text("5. Confirm if you want to delete photos from iPhone")
            Text("6. Nothing is deleted.")
        }
    }
}