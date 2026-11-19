import SwiftUI

@main
struct FacedownApp: App {
    @StateObject private var engine = FocusEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                engine.appDidBackground()
            }
        }
    }
}
