import SwiftUI

/// Screen 1 — Welcome: large "Connected devices:" block mirroring the
/// simulated device state live (the demo toggle lives on step 3); the device
/// row unfolds into the detail rows (n photos / … / z mins). The old analysis
/// screen is gone — device details carry the stats.
struct WelcomeView: View {
    @ObservedObject var model: WizardModel
    @State private var detailsUnfolded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Connected devices: \(model.deviceConnected ? WizardModel.deviceName : "none")")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if model.deviceConnected {
                    Button {
                        detailsUnfolded.toggle()
                    } label: {
                        Image(systemName: detailsUnfolded ? "chevron.down" : "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(detailsUnfolded ? "Hide device details" : "Show device details")
                }
            }
            if model.deviceConnected, detailsUnfolded {
                DeviceDetailsRows()
                    .padding(.leading, 16)
            }
        }
    }
}