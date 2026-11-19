import SpriteKit
import SwiftUI

@main
struct EvergreenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Owns the scene so SwiftUI redraws never recreate it.
final class GameHolder: ObservableObject {
    let state = GameState()
    let scene: GameScene

    init() {
        let screen = UIScreen.main.bounds.size
        let width: CGFloat = 192
        let height = (width * screen.height / max(screen.width, 1)).rounded()
        scene = GameScene(size: CGSize(width: width, height: height), state: state)
        scene.scaleMode = .aspectFill
    }
}

struct ContentView: View {
    @StateObject private var holder = GameHolder()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: holder.scene)
                .ignoresSafeArea()
            HUD(state: holder.state, scene: holder.scene)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Sound.shared.resume()
            }
        }
    }
}
