import Foundation

/// What a fir looks like: three traits the player can read from its shape.
struct TreeTraits: Codable, Equatable {
    var height: Int    // 0 short, 1 medium, 2 tall
    var fullness: Int  // 0 slim, 1 regular, 2 bushy
    var crooked: Int   // 0 straight, 1 crooked

    static let heightNames = ["Short", "Medium", "Tall"]
    static let fullnessNames = ["Slim", "Regular", "Bushy"]
    static let shapeNames = ["Straight", "Crooked"]

    var spriteName: String { "fir_\(height)\(fullness)\(crooked)" }

    var label: String {
        "\(TreeTraits.heightNames[height]) · \(TreeTraits.fullnessNames[fullness]) · \(TreeTraits.shapeNames[crooked])"
    }

    static func random() -> TreeTraits {
        TreeTraits(height: Int.random(in: 0...2), fullness: Int.random(in: 0...2), crooked: Int.random(in: 0...2) == 0 ? 1 : 0)
    }
}

/// What a customer asks for. A nil trait means they do not mind.
struct Wish: Codable, Equatable {
    var height: Int?
    var fullness: Int?
    var crooked: Int?

    var count: Int {
        [height, fullness, crooked].compactMap { $0 }.count
    }

    func matches(_ tree: TreeTraits) -> Int {
        var hits = 0
        if let height = height, height == tree.height { hits += 1 }
        if let fullness = fullness, fullness == tree.fullness { hits += 1 }
        if let crooked = crooked, crooked == tree.crooked { hits += 1 }
        return hits
    }

    var label: String {
        var parts: [String] = []
        if let height = height { parts.append(TreeTraits.heightNames[height]) }
        if let fullness = fullness { parts.append(TreeTraits.fullnessNames[fullness]) }
        if let crooked = crooked { parts.append(TreeTraits.shapeNames[crooked]) }
        return parts.joined(separator: " · ")
    }

    var sentence: String {
        var parts: [String] = []
        if let height = height { parts.append(["short", "medium-sized", "tall"][height]) }
        if let fullness = fullness { parts.append(["slim", "regular", "bushy"][fullness]) }
        if let crooked = crooked { parts.append(crooked == 1 ? "a little crooked" : "perfectly straight") }
        guard let last = parts.last else { return "I'd like a tree." }
        if parts.count == 1 { return "I'd like a tree that is \(last)." }
        return "I'd like a tree that is \(parts.dropLast().joined(separator: ", ")) and \(last)."
    }
}

struct LotTree: Codable {
    var traits: TreeTraits
    var chopped: Bool
}

enum DayPhase: String, Codable {
    case morning   // a customer is waiting at the stand
    case seeking   // the wish is known, no tree felled yet
    case hauling   // a tree is on the sled
    case evening   // delivered; free to light the village and go to bed
    case epilogue  // after the great tree is lit
}

/// Everything that survives between launches.
struct SaveData: Codable {
    static let lastDay = 12
    private static let key = "evergreen.save.v1"

    var day = 1
    var phase: DayPhase = .morning
    var coins = 0
    var hearts = 0
    var lot: [LotTree] = []
    var wishes: [Wish] = []
    var houseOrder: [Int] = []
    var houseTrees: [TreeTraits?] = []
    var lit: [Bool] = []
    var carried: TreeTraits?
    var carryingGiant = false
    var giantChopped = false
    var squarePlanted = false
    var squareLit = false
    var finaleTier = 0

    var litCount: Int { lit.filter { $0 }.count }

    var dateLabel: String { "December \(12 + day)" }

    static func newGame(world: WorldData) -> SaveData {
        var save = SaveData()
        let houseCount = world.houses.count
        for i in 0..<houseCount {
            var traits = ["height", "fullness", "crooked"].shuffled()
            if i < 3 { traits.removeLast() }
            var wish = Wish()
            var tree = TreeTraits.random()
            if traits.contains("height") {
                wish.height = Int.random(in: 0...2)
                tree.height = wish.height ?? tree.height
            }
            if traits.contains("fullness") {
                wish.fullness = Bool.random() ? 0 : 2
                tree.fullness = wish.fullness ?? tree.fullness
            }
            if traits.contains("crooked") {
                wish.crooked = Int.random(in: 0...2) == 0 ? 1 : 0
                tree.crooked = wish.crooked ?? tree.crooked
            }
            save.wishes.append(wish)
            save.lot.append(LotTree(traits: tree, chopped: false))
        }
        while save.lot.count < world.lot.count {
            save.lot.append(LotTree(traits: TreeTraits.random(), chopped: false))
        }
        save.lot = Array(save.lot.shuffled().prefix(world.lot.count))
        save.houseOrder = Array(0..<houseCount).shuffled()
        save.houseTrees = [TreeTraits?](repeating: nil, count: houseCount)
        save.lit = [Bool](repeating: false, count: world.lights.count)
        return save
    }

    /// Returns the stored game if there is one and it still fits this map.
    static func load(world: WorldData) -> SaveData? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let save = try? JSONDecoder().decode(SaveData.self, from: data),
              save.lot.count == world.lot.count,
              save.lit.count == world.lights.count,
              save.houseTrees.count == world.houses.count,
              save.houseOrder.count == world.houses.count,
              save.wishes.count == world.houses.count,
              save.day >= 1, save.day <= SaveData.lastDay else {
            return nil
        }
        return save
    }

    func store() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SaveData.key)
        }
    }
}
