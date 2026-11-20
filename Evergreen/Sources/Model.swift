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

    /// The same wish, said the roundabout way some customers prefer.
    var riddle: String {
        var parts: [String] = []
        if let height = height {
            parts.append(["It has to fit under my low ceiling.", "Not a giant, not a shrub: somewhere in between.", "My parlour ceiling is very high, so think big."][height])
        }
        if let fullness = fullness {
            parts.append(fullness == 0 ? "It must squeeze into a narrow corner." : fullness == 2 ? "I want it to fill the whole window." : "Nothing too skinny, nothing too wide.")
        }
        if let crooked = crooked {
            parts.append(crooked == 1 ? "And give me one with a lean. Perfect trees bore me." : "And my family can't stand a leaning tree.")
        }
        return parts.joined(separator: " ")
    }

    /// One line per wished trait, saying whether the tree got it right.
    func report(_ tree: TreeTraits) -> String {
        var parts: [String] = []
        if let height = height { parts.append("Height " + (height == tree.height ? "✓" : "✗")) }
        if let fullness = fullness { parts.append("Fullness " + (fullness == tree.fullness ? "✓" : "✗")) }
        if let crooked = crooked { parts.append("Shape " + (crooked == tree.crooked ? "✓" : "✗")) }
        return parts.joined(separator: "   ")
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

/// One decoration placed in your garden.
struct GardenItem: Codable, Equatable {
    var kind: String
    var tile: Int
}

/// Something you can place in build mode.
struct BuildKind: Identifiable {
    let id: String
    let title: String
    let sprite: String
    let lit: String        // overlay that keeps its colours at night, or ""
    let dusk: Bool         // true if that overlay only shows after dark
    let price: Int
    let solid: Bool
    let glow: CGFloat      // radius of its glow at night, 0 for none
    let glowHeight: CGFloat

    static let catalog: [BuildKind] = [
        BuildKind(id: "snowman", title: "Snowman", sprite: "snowman", lit: "", dusk: false, price: 4, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "lantern", title: "Lantern", sprite: "lantern", lit: "lantern_lit", dusk: true, price: 5, solid: true, glow: 40, glowHeight: 25),
        BuildKind(id: "arch", title: "Light arch", sprite: "arch", lit: "arch_lit", dusk: false, price: 8, solid: false, glow: 32, glowHeight: 22),
        BuildKind(id: "pine", title: "Little fir", sprite: "pine_2", lit: "", dusk: false, price: 3, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "bush", title: "Holly bush", sprite: "bush", lit: "", dusk: false, price: 2, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "gifts", title: "Gift pile", sprite: "giftpile", lit: "", dusk: false, price: 4, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "candycane", title: "Candy cane", sprite: "candycane", lit: "", dusk: false, price: 2, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "gnome", title: "Gnome", sprite: "gnome", lit: "", dusk: false, price: 3, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "paper", title: "Paper lamp", sprite: "paperlantern", lit: "paperlantern_lit", dusk: true, price: 4, solid: true, glow: 22, glowHeight: 11),
        BuildKind(id: "fire", title: "Campfire", sprite: "campfire", lit: "campfire_lit_0", dusk: false, price: 6, solid: true, glow: 46, glowHeight: 8),
        BuildKind(id: "bench", title: "Bench", sprite: "bench", lit: "", dusk: false, price: 3, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "picket", title: "Picket", sprite: "picket", lit: "", dusk: false, price: 1, solid: true, glow: 0, glowHeight: 0),
        BuildKind(id: "hay", title: "Hay bale", sprite: "haybale", lit: "", dusk: false, price: 2, solid: true, glow: 0, glowHeight: 0)
    ]

    static func find(_ id: String) -> BuildKind? {
        catalog.first { $0.id == id }
    }
}

/// Some days are different.
enum DayEvent {
    case none
    case storm    // heavy snow, gloomy light, extra pay
    case market   // half price at the stalls, a crowd at the market
    case rush     // deliver before the clock runs out for a bonus
}

/// Everything that survives between launches.
struct SaveData: Codable {
    static let lastDay = 12
    private static let key = "evergreen.save.v3"

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

    // Who you are
    var playerName = "Robin"
    var farmName = "Evergreen Farm"
    var look = 0
    /// Which tutorial step you are on; 100 means finished or skipped.
    var tutorial = 0
    var garden: [GardenItem] = []

    // Things bought at the workbench
    var axe = false
    var sledWax = false
    var boots = false
    var guide = false
    var thermos = false
    var outfit = 0
    var outfits = [true, false, false]

    // Pockets and friendships
    var gifts = 0
    var treats = 0
    var gifted: [Bool] = []
    var catFriend = false
    var sheepFriend = false
    var deerFriend = false

    static func event(for day: Int) -> DayEvent {
        switch day {
        case 3, 9: return .storm
        case 5, 10: return .market
        case 7, 11: return .rush
        default: return .none
        }
    }

    static func speaksInRiddles(on day: Int) -> Bool {
        day == 4 || day == 6 || day == 8
    }

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
        save.gifted = [Bool](repeating: false, count: houseCount)
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
              save.gifted.count == world.houses.count,
              save.outfits.count == 3,
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
