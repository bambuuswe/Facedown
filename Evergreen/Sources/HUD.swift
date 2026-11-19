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
                if state.mapOpen {
                    mapView
                }
                if state.shopOpen {
                    shopView
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
                            scene.openMap()
                        } label: {
                            Text("MAP")
                                .font(pixelFont(12))
                                .foregroundStyle(ink)
                                .frame(width: 40, height: 26)
                                .background(gold)
                        }
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
                    if !state.eventLabel.isEmpty || !state.buff.isEmpty || state.gifts > 0 || state.treats > 0 {
                        HStack(spacing: 6) {
                            if !state.eventLabel.isEmpty {
                                Text(state.eventLabel)
                                    .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.55))
                            }
                            if !state.buff.isEmpty {
                                PixelIcon(name: "icon_mug", width: 14, height: 12)
                                Text(state.buff)
                            }
                            if state.gifts > 0 {
                                PixelIcon(name: "icon_gift", width: 14, height: 12)
                                Text("\(state.gifts)")
                            }
                            if state.treats > 0 {
                                PixelIcon(name: "icon_treat", width: 14, height: 12)
                                Text("\(state.treats)")
                            }
                        }
                        .font(pixelFont(11))
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
                if state.canGoHome && state.dialog == nil && state.ending == nil && !state.mapOpen && !state.shopOpen {
                    Button {
                        scene.headHome()
                    } label: {
                        Text("GO HOME\nTO BED")
                            .font(pixelFont(11))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(snow)
                            .frame(width: 84, height: 44)
                            .background(ink.opacity(0.93))
                            .overlay(Rectangle().strokeBorder(snow, lineWidth: 2))
                    }
                }
                Spacer()
                if !state.actionTitle.isEmpty && state.dialog == nil && state.ending == nil && !state.mapOpen && !state.shopOpen {
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
                        PixelIcon(name: dialog.portrait, width: 60, height: 90)
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

    // MARK: - Workbench shop

    private func shopLabel(_ item: ShopItem) -> String {
        switch item.status {
        case 1: return "OWNED"
        case 2: return "WEAR"
        case 3: return "WORN"
        default: return item.price == 0 ? "FREE" : "\(item.price) COINS"
        }
    }

    private func shopColor(_ item: ShopItem) -> Color {
        switch item.status {
        case 0: return state.coins >= item.price ? gold : Color.gray
        case 2: return snow
        default: return pine
        }
    }

    private var shopView: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            Panel {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("WORKBENCH")
                            .font(pixelFont(18))
                            .foregroundStyle(gold)
                        Spacer()
                        PixelIcon(name: "icon_coin", width: 16, height: 16)
                        Text("\(state.coins)")
                            .font(pixelFont(15))
                            .foregroundStyle(snow)
                    }
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(state.shop) { item in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title.uppercased())
                                            .font(pixelFont(13))
                                            .foregroundStyle(snow)
                                        Text(item.detail)
                                            .font(pixelFont(10))
                                            .foregroundStyle(snow.opacity(0.75))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Button {
                                        scene.buyItem(item.id)
                                    } label: {
                                        Text(shopLabel(item))
                                            .font(pixelFont(11))
                                            .foregroundStyle(ink)
                                            .frame(width: 78, height: 34)
                                            .background(shopColor(item))
                                    }
                                }
                                .padding(8)
                                .background(snow.opacity(0.08))
                            }
                        }
                    }
                    .frame(maxHeight: 430)
                    PixelButton(title: "CLOSE") {
                        scene.closeShop()
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Map

    private var mapView: some View {
        let info = state.mapInfo
        let world = scene.world
        let imageWidth = CGFloat(world.cols * 6 + 8)
        let imageHeight = CGFloat(world.rows * 6 + 8)
        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            Panel {
                VStack(spacing: 10) {
                    Text("VILLAGE MAP")
                        .font(pixelFont(18))
                        .foregroundStyle(gold)
                    Image(uiImage: UIImage(named: "minimap") ?? UIImage())
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(imageWidth / imageHeight, contentMode: .fit)
                        .overlay(
                            GeometryReader { proxy in
                                let insetX = proxy.size.width * 4 / imageWidth
                                let insetY = proxy.size.height * 4 / imageHeight
                                let spanX = proxy.size.width - insetX * 2
                                let spanY = proxy.size.height - insetY * 2
                                ZStack {
                                    ForEach(world.labels.indices, id: \.self) { index in
                                        Text(world.labels[index].text.uppercased())
                                            .font(pixelFont(8))
                                            .foregroundStyle(ink)
                                            .padding(.horizontal, 2)
                                            .background(snow.opacity(0.8))
                                            .position(x: insetX + world.labels[index].x * spanX, y: insetY + world.labels[index].y * spanY)
                                    }
                                    ForEach(info.dots) { dot in
                                        Rectangle()
                                            .fill(dot.lit ? gold : ink.opacity(0.55))
                                            .frame(width: 5, height: 5)
                                            .overlay(Rectangle().strokeBorder(ink, lineWidth: 1))
                                            .position(x: insetX + dot.x * spanX, y: insetY + dot.y * spanY)
                                    }
                                    if let target = info.target {
                                        Rectangle()
                                            .fill(gold)
                                            .frame(width: 10, height: 10)
                                            .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
                                            .rotationEffect(.degrees(45))
                                            .position(x: insetX + target.x * spanX, y: insetY + target.y * spanY)
                                    }
                                    Circle()
                                        .fill(berry)
                                        .frame(width: 11, height: 11)
                                        .overlay(Circle().strokeBorder(snow, lineWidth: 2))
                                        .position(x: insetX + info.player.x * spanX, y: insetY + info.player.y * spanY)
                                }
                            }
                        )
                    HStack(spacing: 10) {
                        Circle().fill(berry).frame(width: 9, height: 9)
                        Text("YOU")
                        Rectangle().fill(gold).frame(width: 8, height: 8).rotationEffect(.degrees(45))
                        Text("GO HERE")
                        Rectangle().fill(gold).frame(width: 6, height: 6)
                        Text("LIT")
                        Rectangle().fill(ink.opacity(0.55)).frame(width: 6, height: 6).overlay(Rectangle().strokeBorder(snow, lineWidth: 1))
                        Text("UNLIT")
                    }
                    .font(pixelFont(10))
                    .foregroundStyle(snow)
                    PixelButton(title: "CLOSE") {
                        scene.closeMap()
                    }
                }
            }
            .padding(.horizontal, 14)
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
                    Button {
                        scene.toggleSound()
                    } label: {
                        Text(state.soundOn ? "SOUND: ON" : "SOUND: OFF")
                            .font(pixelFont(12))
                            .foregroundStyle(snow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Rectangle().strokeBorder(snow.opacity(0.7), lineWidth: 2))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 40)
            }
        }
    }
}
