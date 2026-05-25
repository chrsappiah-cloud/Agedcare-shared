import SwiftUI

@main
struct AgedcareWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(sessionManager)
                .task {
                    await sessionManager.activate()
                }
        }
    }
}
