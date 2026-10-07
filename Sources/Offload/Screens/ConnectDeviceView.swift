import SwiftUI

/// Screen 3 — connect device: instruction + demo toggle (both ways) at left,
/// right-side box reserved for the future connection visual (empty styled
/// box for now). Continue is gated on the device being connected.
struct ConnectDeviceView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect your iPhone and Mac with a USB cable.")
                // Demo-only simulated device; the whole wizard mirrors it live.
                Button(model.deviceConnected ? "Remove it (demo)" : "Connected - test it") {
                    model.deviceConnected.toggle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            placeholderBox
        }
    }

    /// Reserved spot for the connection visual (mockup: 218x268 box labelled
    /// "simplified mockup visualising connection" — an empty styled box is
    /// fine for now).
    private var placeholderBox: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3), lineWidth: 1))
            .frame(width: 200, height: 220)
            .accessibilityHidden(true)
    }
}