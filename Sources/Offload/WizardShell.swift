import SwiftUI

/// The 7-screen wizard chrome: step header, center screen, footer controls.
struct WizardShell: View {
    @StateObject private var model = WizardModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            Text("Step \(model.step.rawValue) of 7")
                .monospacedDigit()
            Spacer()
            ProgressView(value: Double(model.step.rawValue) / 7.0)
                .progressViewStyle(.linear)
                .frame(width: 320)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var screen: some View {
        switch model.step {
        case .intro: IntroView(model: model)
        case .consent: ConsentView()
        case .usb: UsbView(model: model)
        case .destination: DestinationView(model: model)
        case .scope: ScopeView(model: model)
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
            if showsPrimary {
                Button(primaryTitle) { primaryAction() }
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

    private var primaryTitle: String {
        model.step == .scope ? "Start copying" : "Continue"
    }

    private var nextEnabled: Bool {
        switch model.step {
        case .usb: model.driveConnected
        case .destination: model.destination != nil
        case .scope: model.scopeTotal > 0
        default: true
        }
    }

    private func primaryAction() {
        if model.step == .scope {
            model.startExport()
        } else {
            model.next()
        }
    }
}