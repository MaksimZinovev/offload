import SwiftUI
import AppKit

@main
struct OffloadApp: App {
    init() {
        // `swift run` launches a bare executable — no bundle, so macOS
        // defaults it to background-only and the window stays invisible.
        // Register as a regular app so the window shows and gets focus.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            WizardShell()
                .frame(width: 760, height: 560)
        }
        .windowResizability(.contentSize)
    }
}