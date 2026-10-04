import SwiftUI

@main
struct OffloadApp: App {
    var body: some Scene {
        WindowGroup {
            WizardShell()
                .frame(width: 640, height: 480)
        }
        .windowResizability(.contentSize)
    }
}