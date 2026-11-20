import SwiftUI

@main
struct NeiroxApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
        }
    }
}
