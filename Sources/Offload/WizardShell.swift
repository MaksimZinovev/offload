import SwiftUI

/// The 7-screen wizard chrome: step header + pips, connected-devices line
/// (steps 2+), center screen, footer controls.
struct WizardShell: View {
    @StateObject private var model = WizardModel()
    /// Unfold state of the compact devices line — persists across steps 2-5.
    /// Welcome owns its own (large) device block instead.
    @State private var deviceDetailsUnfolded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if model.step != .welcome {
                    ConnectedDevicesLine(model: model, unfolded: $deviceDetailsUnfolded)
                }
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .padding(16)
    }

    private var stepTitle: String {
        switch model.step {
        case .welcome: "Welcome"
        case .nextSteps: "Next steps"
        case .connectDevice: "Connect device"
        case .destination: "Select destination folder"
        case .photos: "Select photos"
        case .progress: "Copying"
        case .summary: "Summary"
        }
    }

    private var header: some View {
        HStack {
            Text("Step \(model.step.rawValue) of 7 - \(stepTitle)")
            Spacer()
            pips
        }
        .padding(.bottom, 8)
    }

    /// Seven square pips — filled through the current step (mockup).
    private var pips: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { pip in
                RoundedRectangle(cornerRadius: 2)
                    .fill(pip <= model.step.rawValue ? Color.accentColor : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(.secondary, lineWidth: 1))
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(model.step.rawValue) of 7")
    }

    @ViewBuilder
    private var screen: some View {
        switch model.step {
        case .welcome: WelcomeView(model: model)
        case .nextSteps: NextStepsView(model: model)
        case .connectDevice: UsbView(model: model)
        case .destination: DestinationView(model: model)
        case .photos: ScopeView(model: model)
        case .progress: ExportProgressView(model: model)
        case .summary: SummaryView(model: model)
        }
    }

    private var footer: some View {
        HStack {
            if model.canGoBack {
                Button("Back") { model.back() }
            }
            Spacer()
            if model.step == .photos {
                Button("Clear selection") { model.clearSelection() }
            }
            Spacer()
            if showsPrimary {
                Button("Continue") { primaryAction() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nextEnabled)
            }
        }
        .padding(.top, 8)
    }

    private var showsPrimary: Bool {
        switch model.step {
        case .progress, .summary: false
        default: true
        }
    }

    private var nextEnabled: Bool {
        switch model.step {
        case .connectDevice: model.deviceConnected
        case .photos: model.scopeTotal > 0
        default: true
        }
    }

    private func primaryAction() {
        if model.step == .photos {
            model.startExport()
        } else {
            model.next()
        }
    }
}

/// Compact "Connected devices:" chrome line (steps 2+): status dot,
/// device name (or "none"), unfold chevron into the detail rows.
struct ConnectedDevicesLine: View {
    @ObservedObject var model: WizardModel
    @Binding var unfolded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.deviceConnected ? Color.green : Color.clear)
                    .overlay(Circle().stroke(.secondary, lineWidth: 1))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Connected devices:")
                    .foregroundStyle(.secondary)
                Text(model.deviceConnected ? WizardModel.deviceName : "none")
                    .foregroundStyle(.secondary)
                if model.deviceConnected {
                    Button {
                        unfolded.toggle()
                    } label: {
                        Image(systemName: unfolded ? "chevron.down" : "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(unfolded ? "Hide device details" : "Show device details")
                }
            }
            .font(.callout)
            if model.deviceConnected, unfolded {
                DeviceDetailsRows()
                    .padding(.leading, 14)
            }
        }
    }
}

/// The unfolded per-device details (simulated whole-library stats, fictional).
struct DeviceDetailsRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(WizardModel.devicePhotos.formatted()) photos")
            Text("\(WizardModel.deviceVideos.formatted()) videos")
            Text("\(WizardModel.deviceSizeGB) GB total size")
            Text("\(WizardModel.deviceYearRange.lowerBound)–\(WizardModel.deviceYearRange.upperBound) date range")
            Text("≈ \(WizardModel.deviceExportMinutes) mins estimated export time")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}