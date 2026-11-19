import Foundation

struct Dialog: Equatable {
    let speaker: String
    let portrait: String
    let text: String
    let button: String
}

struct MapDot: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let lit: Bool
}

/// Positions for the map screen, each from 0 to 1 across the map, y downward.
struct MapInfo {
    var player = CGPoint.zero
    var target: CGPoint?
    var dots: [MapDot] = []
}

struct ShopItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let price: Int
    /// 0 for sale, 1 owned, 2 owned outfit you can wear, 3 the outfit you are wearing
    let status: Int
}

struct Ending: Equatable {
    let tier: Int
    let lit: Int
    let total: Int
    let hearts: Int
}

/// What the SwiftUI layer shows. The scene writes it; the views read it.
final class GameState: ObservableObject {
    enum Screen {
        case title
        case playing
    }

    @Published var screen: Screen = .title
    @Published var hasSave = false
    @Published var dateLabel = ""
    @Published var coins = 0
    @Published var hearts = 0
    @Published var litCount = 0
    @Published var lightTotal = 0
    @Published var objective = ""
    @Published var wishLabel = ""
    @Published var treeTag = ""
    @Published var actionTitle = ""
    @Published var actionCost = 0
    @Published var actionEnabled = true
    @Published var dialog: Dialog?
    @Published var ending: Ending?
    @Published var curtain: String?
    @Published var mapOpen = false
    @Published var shopOpen = false
    @Published var shop: [ShopItem] = []
    @Published var buff = ""
    @Published var eventLabel = ""
    @Published var gifts = 0
    @Published var treats = 0
    @Published var canGoHome = false
    @Published var soundOn = true
    @Published var mapInfo = MapInfo()
    @Published var toast = ""

    private var toastID = 0

    func showToast(_ text: String) {
        toast = text
        toastID += 1
        let id = toastID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, self.toastID == id else { return }
            self.toast = ""
        }
    }
}
