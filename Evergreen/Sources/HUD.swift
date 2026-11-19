import SwiftUI

private let ink = Color(red: 0.11, green: 0.14, blue: 0.27)
private let snow = Color(red: 0.96, green: 0.97, blue: 1.0)
private let gold = Color(red: 0.96, green: 0.79, blue: 0.24)
private let berry = Color(red: 0.85, green: 0.28, blue: 0.24)
private let pine = Color(red: 0.25, green: 0.54, blue: 0.36)

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
            .background(ink.opacity(0.93))
            .overlay(Rectangle().strokeBorder(snow, lineWidth: 2))
    }
}

private struct PixelButton: View {
    let title: String
    var color: Color = gold
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(pixelFont(17))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(color)
                .overlay(Rectangle().strokeBorder(snow, lineWidth: 2))
        }
    }
}

struct HUD: View {
    @ObservedObject var state: GameState
    let scene: GameScene
    @State private var confirmNewGame = false

    var body: some View {
        ZStack {
            if state.screen == .title {
                title
            } else {
                playing
                if let dialog = state.dialog {
                    dialogView(dialog)
                }
                if let ending = state.ending {
                    endingView(ending)
                }
            }
            if let curtain = state.curtain {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 10) {
                        PixelIcon(name: "icon_fir", width: 36, height: 40)
                        Text(curtain.uppercased())
                            .font(pixelFont(22))
                            .foregroundStyle(snow)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: state.curtain)
    }

    // MARK: - While playing

    private var playing: some View {
        VStack(spacing: 8) {
            Panel {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Text(state.dateLabel)
                        Spacer(minLength: 4)
                        PixelIcon(name: "icon_coin", width: 16, height: 16)
                        Text("\(state.coins)")
                        Spacer(minLength: 4)
                        PixelIcon(name: "icon_heart", width: 18, height: 16)
                        Text("\(state.hearts)")
                        Spacer(minLength: 4)
                        PixelIcon(name: "icon_bulb", width: 14, height: 18)
                        Text("\(state.litCount)/\(state.lightTotal)")
                        Spacer(minLength: 4)
                        Button {
                            scene.showTitle()
                        } label: {
                            Text("II")
                                .font(pixelFont(14))
                                .foregroundStyle(ink)
                                .frame(width: 30, height: 26)
                                .background(snow)
                        }
                    }
                    .font(pixelFont(14))
                    Text(state.objective)
                        .font(pixelFont(12))
                        .opacity(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    if !state.wishLabel.isEmpty {
                        HStack(spacing: 6) {
                            PixelIcon(name: "icon_fir", width: 14, height: 16)
                            Text(state.wishLabel)
                                .font(pixelFont(13))
                                .foregroundStyle(gold)
                        }
                    }
                }
                .foregroundStyle(snow)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !state.toast.isEmpty {
                Text(state.toast)
                    .font(pixelFont(14))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(snow)
                    .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
                    .allowsHitTesting(false)
            }
            Spacer()
            if !state.treeTag.isEmpty && state.dialog == nil {
                Text(state.treeTag)
                    .font(pixelFont(14))
                    .foregroundStyle(snow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(pine)
                    .overlay(Rectangle().strokeBorder(snow, lineWidth: 2))
                    .allowsHitTesting(false)
            }
            HStack {
                Spacer()
                if !state.actionTitle.isEmpty && state.dialog == nil && state.ending == nil {
                    Button {
                        scene.performAction()
                    } label: {
                        HStack(spacing: 6) {
                            Text(state.actionTitle.uppercased())
                            if state.actionCost > 0 {
                                PixelIcon(name: "icon_coin", width: 16, height: 16)
                                Text("\(state.actionCost)")
                            }
                        }
                        .font(pixelFont(18))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 18)
                        .frame(minWidth: 120)
                        .frame(height: 60)
                        .background(state.actionEnabled ? gold : Color.gray)
                        .overlay(Rectangle().strokeBorder(snow, lineWidth: 3))
                    }
                }
            }
            .frame(height: 60)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private func dialogView(_ dialog: Dialog) -> some View {
        VStack {
            Spacer()
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        PixelIcon(name: dialog.portrait, width: 48, height: 66)
                            .padding(6)
                            .background(snow.opacity(0.12))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dialog.speaker.uppercased())
                                .font(pixelFont(14))
                                .foregroundStyle(gold)
                            Text(dialog.text)
                                .font(pixelFont(14))
                                .foregroundStyle(snow)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    PixelButton(title: dialog.button.uppercased()) {
                        scene.dismissDialog()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 18)
    }

    private func endingView(_ ending: Ending) -> some View {
        let line: String
        switch ending.tier {
        case 3: line = "The whole village glows. Nobody can remember a brighter Christmas."
        case 2: line = "The square shines warm and merry under the great tree."
        default: line = "A few brave lights twinkle on the great tree. It is enough."
        }
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Panel {
                VStack(spacing: 14) {
                    PixelIcon(name: "icon_fir", width: 45, height: 50)
                    Text("MERRY CHRISTMAS")
                        .font(pixelFont(24))
                        .foregroundStyle(gold)
                    Text(line)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        PixelIcon(name: "icon_bulb", width: 14, height: 18)
                        Text("\(ending.lit)/\(ending.total) lights")
                        PixelIcon(name: "icon_heart", width: 18, height: 16)
                        Text("\(ending.hearts) perfect trees")
                    }
                    .font(pixelFont(12))
                    PixelButton(title: "STROLL THE VILLAGE") {
                        state.ending = nil
                    }
                }
                .font(pixelFont(14))
                .foregroundStyle(snow)
            }
            .padding(24)
        }
    }

    // MARK: - Title

    private var title: some View {
        ZStack {
            LinearGradient(colors: [ink.opacity(0.75), ink.opacity(0.1), ink.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer().frame(height: 60)
                Text("EVERGREEN")
                    .font(pixelFont(40))
                    .foregroundStyle(snow)
                    .shadow(color: ink, radius: 0, x: 3, y: 3)
                Text("A COZY CHRISTMAS TREE FARM")
                    .font(pixelFont(13))
                    .foregroundStyle(gold)
                Spacer()
                VStack(spacing: 12) {
                    if state.hasSave {
                        PixelButton(title: "CONTINUE") {
                            scene.continueGame()
                        }
                        PixelButton(title: confirmNewGame ? "ERASE AND START OVER?" : "NEW WINTER", color: confirmNewGame ? berry : snow) {
                            if confirmNewGame {
                                confirmNewGame = false
                                scene.startNewGame()
                            } else {
                                confirmNewGame = true
                            }
                        }
                    } else {
                        PixelButton(title: "START") {
                            scene.startNewGame()
                        }
                    }
                    Text("Drag anywhere to walk. Your game saves by itself.")
                        .font(pixelFont(11))
                        .foregroundStyle(snow.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 40)
            }
        }
    }
}
