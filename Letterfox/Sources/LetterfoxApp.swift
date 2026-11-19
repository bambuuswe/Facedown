import SpriteKit
import SwiftUI

@main
struct LetterfoxApp: App {
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

    var body: some View {
        ZStack {
            SpriteView(scene: holder.scene)
                .ignoresSafeArea()
            HUD(state: holder.state, scene: holder.scene)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

private let ink = Color(red: 0.23, green: 0.16, blue: 0.13)
private let cream = Color(red: 0.99, green: 0.94, blue: 0.86)
private let foxOrange = Color(red: 0.92, green: 0.49, blue: 0.17)

private func pixelFont(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .monospaced)
}

private struct PixelIcon: View {
    let name: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(uiImage: UIImage(named: name) ?? UIImage())
            .interpolation(.none)
            .resizable()
            .frame(width: width, height: height)
    }
}

private struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .background(ink.opacity(0.92))
            .overlay(Rectangle().strokeBorder(cream, lineWidth: 2))
    }
}

private struct HUD: View {
    @ObservedObject var state: GameState
    let scene: GameScene

    var body: some View {
        ZStack {
            if state.phase == .playing {
                playing
                    .allowsHitTesting(false)
            } else {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                menu
                    .padding(28)
            }
        }
    }

    // MARK: - In-game bar

    private var playing: some View {
        VStack(spacing: 8) {
            Panel {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text("DAY \(state.day)")
                        timeBar
                        Text("\(state.seconds)s")
                            .foregroundStyle(state.seconds <= 10 ? Color.red : cream)
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack(spacing: 6) {
                        ForEach(0..<GameState.bagSize, id: \.self) { slot in
                            PixelIcon(name: "icon_letter", width: 20, height: 16)
                                .opacity(slot < state.bag ? 1 : 0.25)
                        }
                        Spacer()
                        Text("\(state.delivered)/\(state.quota)")
                        Spacer()
                        PixelIcon(name: "icon_coin", width: 16, height: 16)
                        Text("\(state.coins)")
                    }
                }
                .font(pixelFont(15))
                .foregroundStyle(cream)
            }
            if !state.toast.isEmpty {
                Text(state.toast)
                    .font(pixelFont(15))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(cream)
                    .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var timeBar: some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, CGFloat(state.seconds) / CGFloat(GameState.dayLength)))
            ZStack(alignment: .leading) {
                Rectangle().fill(cream.opacity(0.2))
                Rectangle()
                    .fill(state.seconds <= 10 ? Color.red : foxOrange)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 12)
    }

    // MARK: - Menus

    @ViewBuilder
    private var menu: some View {
        switch state.phase {
        case .title:
            Panel {
                VStack(spacing: 14) {
                    PixelIcon(name: "fox_down_0", width: 96, height: 96)
                    Text("LETTERFOX")
                        .font(pixelFont(30))
                        .foregroundStyle(foxOrange)
                    Text("Deliver the mail before sunset.\nMind the geese.")
                        .multilineTextAlignment(.center)
                    Text("Drag anywhere to walk. Fetch letters at the post office and carry them to the houses with a letter bubble.")
                        .font(pixelFont(12))
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                    if state.bestDay > 0 {
                        Text("BEST: DAY \(state.bestDay) / \(state.bestCoins) COINS")
                            .font(pixelFont(12))
                    }
                    menuButton("START") { scene.startGame() }
                }
                .font(pixelFont(14))
                .foregroundStyle(cream)
            }
        case .dayDone:
            Panel {
                VStack(spacing: 14) {
                    Text("DAY \(state.day) DONE")
                        .font(pixelFont(26))
                        .foregroundStyle(foxOrange)
                    Text("All \(state.quota) letters delivered.")
                    Text("Time bonus: +\(state.bonus) coins")
                    HStack(spacing: 6) {
                        PixelIcon(name: "icon_coin", width: 16, height: 16)
                        Text("\(state.coins)")
                    }
                    menuButton("NEXT DAY") { scene.nextDay() }
                }
                .font(pixelFont(14))
                .foregroundStyle(cream)
            }
        case .gameOver:
            Panel {
                VStack(spacing: 14) {
                    Text("SUNSET")
                        .font(pixelFont(30))
                        .foregroundStyle(foxOrange)
                    Text("The mail was late on day \(state.day).")
                        .multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        PixelIcon(name: "icon_coin", width: 16, height: 16)
                        Text("\(state.coins)")
                    }
                    Text("BEST: DAY \(state.bestDay) / \(state.bestCoins) COINS")
                        .font(pixelFont(12))
                    menuButton("PLAY AGAIN") { scene.startGame() }
                }
                .font(pixelFont(14))
                .foregroundStyle(cream)
            }
        case .playing:
            EmptyView()
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(pixelFont(18))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(foxOrange)
                .overlay(Rectangle().strokeBorder(cream, lineWidth: 2))
        }
        .padding(.top, 4)
    }
}
