import Foundation

/// What the heads-up display shows. The scene writes it; SwiftUI reads it.
final class GameState: ObservableObject {
    enum Phase {
        case title
        case playing
        case dayDone
        case gameOver
    }

    static let dayLength = 60
    static let bagSize = 3

    @Published var phase: Phase = .title
    @Published var day = 1
    @Published var coins = 0
    @Published var seconds = GameState.dayLength
    @Published var bag = 0
    @Published var atPost = 0
    @Published var delivered = 0
    @Published var quota = 0
    @Published var bonus = 0
    @Published var toast = ""
    @Published private(set) var bestDay: Int
    @Published private(set) var bestCoins: Int

    private var toastID = 0

    init() {
        bestDay = UserDefaults.standard.integer(forKey: "bestDay")
        bestCoins = UserDefaults.standard.integer(forKey: "bestCoins")
    }

    func showToast(_ text: String) {
        toast = text
        toastID += 1
        let id = toastID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self = self, self.toastID == id else { return }
            self.toast = ""
        }
    }

    func recordBest() {
        if day > bestDay {
            bestDay = day
            UserDefaults.standard.set(day, forKey: "bestDay")
        }
        if coins > bestCoins {
            bestCoins = coins
            UserDefaults.standard.set(coins, forKey: "bestCoins")
        }
    }
}
