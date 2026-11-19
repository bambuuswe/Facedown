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
    let smoke: WorldPoint

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

struct WorldSkate: Codable {
    let x: CGFloat
    let y: CGFloat
    let rx: CGFloat
    let ry: CGFloat
}

struct WorldZone: Codable {
    let x0: CGFloat
    let y0: CGFloat
    let x1: CGFloat
    let y1: CGFloat
}

struct WorldLabel: Codable {
    let text: String
    let x: CGFloat
    let y: CGFloat
}

struct WorldStall: Codable {
    let kind: String
    let x: CGFloat
    let y: CGFloat

    var cg: CGPoint { CGPoint(x: x, y: y) }
}

struct WorldData: Codable {
    let width: CGFloat
    let height: CGFloat
    let tile: CGFloat
    let cols: Int
    let rows: Int
    let solid: String
    let snow: String
    let ice: String
    let stroll: String
    let props: [WorldProp]
    let houses: [WorldHouse]
    let lights: [WorldLight]
    let lot: [WorldPoint]
    let giant: WorldPoint
    let square: WorldPoint
    let cabinDoor: WorldPoint
    let customer: WorldPoint
    let gate: WorldPoint
    let vendors: [WorldProp]
    let cabinSmoke: WorldPoint
    let skate: WorldSkate
    let sheepZone: WorldZone
    let deerZone: WorldZone
    let cat: WorldPoint
    let labels: [WorldLabel]
    let workshop: WorldPoint
    let chapelDoor: WorldPoint
    let stalls: [WorldStall]

    static func load() -> WorldData {
        guard let url = Bundle.main.url(forResource: "world", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let world = try? JSONDecoder().decode(WorldData.self, from: data) else {
            fatalError("world.json is missing or unreadable")
        }
        return world
    }
}
