import CoreGraphics
import Foundation

// The map, as written by tools/build.js into world.json. All coordinates are in
// game pixels with y growing upward; sprites stand on their bottom centre.

struct WorldPoint: Codable {
    let x: CGFloat
    let y: CGFloat

    var cg: CGPoint { CGPoint(x: x, y: y) }
}

struct WorldProp: Codable {
    let sprite: String
    let x: CGFloat
    let y: CGFloat
}

struct WorldGlow: Codable {
    let x: CGFloat
    let y: CGFloat
    let r: CGFloat
    let c: [CGFloat]
}

struct WorldHouse: Codable {
    let sprite: String
    let lit: String
    let x: CGFloat
    let y: CGFloat
    let doorX: CGFloat
    let doorY: CGFloat
    let treeX: CGFloat
    let treeY: CGFloat
    let name: String
    let villager: String
    let hint: String
    let glows: [WorldGlow]

    var door: CGPoint { CGPoint(x: doorX, y: doorY) }
}

struct WorldLightPart: Codable {
    let sprite: String
    let lit: String
    let x: CGFloat
    let y: CGFloat
}

struct WorldLight: Codable {
    let id: Int
    let kind: String
    let cost: Int
    let label: String
    let parts: [WorldLightPart]
    let glows: [WorldGlow]
    let points: [WorldPoint]
}

struct WorldData: Codable {
    let width: CGFloat
    let height: CGFloat
    let tile: CGFloat
    let cols: Int
    let rows: Int
    let solid: String
    let snow: String
    let props: [WorldProp]
    let houses: [WorldHouse]
    let lights: [WorldLight]
    let lot: [WorldPoint]
    let giant: WorldPoint
    let square: WorldPoint
    let cabinDoor: WorldPoint
    let customer: WorldPoint
    let gate: WorldPoint

    static func load() -> WorldData {
        guard let url = Bundle.main.url(forResource: "world", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let world = try? JSONDecoder().decode(WorldData.self, from: data) else {
            fatalError("world.json is missing or unreadable")
        }
        return world
    }
}
