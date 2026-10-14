import SwiftUI

/// Screen 3 — connect device (APP1): the in-app mode toggle + mode
/// instruction at left, right-side box reserved for the future connection
/// visual (empty styled box for now). The toggle's value IS the model's
/// resolved mode (no local @State drift); in env-forced runs it shows the
/// truth and is disabled. Real mode mirrors honest state only (name +
/// counts when derivable, nothing fabricated); the demo fiction branch is
/// exactly as CP3. Continue stays gated on the device being connected.
struct ConnectDeviceView: View {
    @ObservedObject var model: WizardModel

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(instruction)
                // APP1: the no-Terminal mode switch — value flows from the
                // resolved mode; picks apply through the idle-guarded helpers.
                Picker("Device mode", selection: deviceMode) {
                    Text("Demo device (sample photos)").tag(false)
                    Text("My iPhone (real transfer)").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Device mode")
                .disabled(WizardModel.deviceModeEnvForced)
                if model.usesRealDevice {
                    if model.deviceConnected {
                        // Counts only when the catalog says > 0 (0 also covers
                        // "connected, still enumerating" — nothing invented).
                        deviceStateLine
                    }
                } else {
                    // Demo-only simulated device; the whole wizard mirrors it live.
                    Button(model.deviceConnected ? "Remove it (demo)" : "Connected - test it") {
                        model.deviceConnected.toggle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            placeholderBox
        }
    }

    /// Demo keeps the CP3 instruction; real mode swaps in the DMG Read Me
    /// line verbatim (user verdict — the family already read it there).
    private var instruction: String {
        model.usesRealDevice
            ? "Plug the phone in and keep it unlocked; approve the trust prompt if one appears."
            : "Connect your iPhone and Mac with a USB cable."
    }

    /// Real-mode state line — same derivable-truth policy as
    /// DeviceDetailsRows: name, then counts only when > 0.
    private var deviceStateLine: some View {
        Group {
            if model.deviceItemCount > 0 {
                Text("\(model.deviceName) · \(model.devicePhotoCount.formatted()) photos · \(model.deviceVideoCount.formatted()) videos")
            } else {
                Text(model.deviceName)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    /// Binding via the helpers: the picker can only flip the resolved mode via
    /// enable/disableRealDeviceMode(); a pick that a guard bounces just
    /// never changes the get — truth stays model-side, never in @State.
    private var deviceMode: Binding<Bool> {
        Binding(
            get: { model.usesRealDevice },
            set: { $0 ? model.enableRealDeviceMode() : model.disableRealDeviceMode() }
        )
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