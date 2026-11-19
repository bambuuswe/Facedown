import CoreGraphics

enum Ground {
    case grass
    case path
    case water
}

/// A house or the post office. Covers 3x2 tiles; the door faces down the screen.
struct Building {
    let x: Int
    let y: Int
    let style: Int

    /// Bottom centre of the footprint, where the sprite stands.
    var base: CGPoint {
        CGPoint(x: (CGFloat(x) + 1.5) * World.tile, y: CGFloat(y) * World.tile)
    }

    /// Centre of the walkable tile in front of the door.
    var door: CGPoint {
        CGPoint(x: (CGFloat(x) + 1.5) * World.tile, y: (CGFloat(y) - 0.5) * World.tile)
    }
}

struct Tree {
    let x: Int
    let y: Int
    let kind: Int
}

/// A freshly generated village. Tile (0, 0) is the bottom-left corner; y grows upward.
final class World {
    static let tile: CGFloat = 16
    static let size = 36
    static let houseStyles = 5

    let ground: [Ground]
    let grassVariant: [Int]
    let solid: [Bool]
    let houses: [Building]
    let post: Building
    let trees: [Tree]
    let pathTiles: [(x: Int, y: Int)]

    var pixelSize: CGFloat { CGFloat(World.size) * World.tile }

    init() {
        let n = World.size
        var ground = [Ground](repeating: .grass, count: n * n)
        var solid = [Bool](repeating: false, count: n * n)
        var reserved = [Bool](repeating: false, count: n * n)
        func index(_ x: Int, _ y: Int) -> Int { y * n + x }

        // Roads: three streets across, two lanes up.
        let roadRows = [7, 8, 17, 18, 27, 28]
        let roadColumns = [7, 8, 27, 28]
        for i in 1..<(n - 1) {
            for row in roadRows { ground[index(i, row)] = .path }
            for column in roadColumns { ground[index(column, i)] = .path }
        }

        // The post office sits on the middle street; houses fill random lots.
        let post = Building(x: 17, y: 19, style: 0)
        var lots: [(x: Int, y: Int)] = []
        for streetTop in [8, 18, 28] {
            for lotX in [2, 10, 14, 20, 24, 30] {
                if streetTop == 18 && (lotX == 14 || lotX == 20) { continue }
                lots.append((lotX, streetTop + 1))
            }
        }
        lots.shuffle()
        var houses: [Building] = []
        for (i, lot) in lots.prefix(9).enumerated() {
            houses.append(Building(x: lot.x, y: lot.y, style: i % World.houseStyles))
        }
        for building in houses + [post] {
            for dx in 0..<3 {
                for dy in 0..<2 {
                    solid[index(building.x + dx, building.y + dy)] = true
                }
                reserved[index(building.x + dx, building.y + 2)] = true
            }
        }

        // One pond, in the block above or below the post office.
        let pondY: CGFloat = Bool.random() ? 12.5 : 23.5
        for y in 0..<n {
            for x in 0..<n {
                let dx = (CGFloat(x) + 0.5 - 18) / 3.2
                let dy = (CGFloat(y) + 0.5 - pondY) / 1.9
                if dx * dx + dy * dy <= 1 && ground[index(x, y)] == .grass && !solid[index(x, y)] {
                    ground[index(x, y)] = .water
                    solid[index(x, y)] = true
                }
            }
        }

        // Trees: a forest wall around the edge, plus a scattering inside.
        var trees: [Tree] = []
        for y in 0..<n {
            for x in 0..<n {
                let i = index(x, y)
                let border = x == 0 || y == 0 || x == n - 1 || y == n - 1
                if border {
                    solid[i] = true
                    trees.append(Tree(x: x, y: y, kind: Int.random(in: 0...1)))
                } else if ground[i] == .grass && !solid[i] && !reserved[i] && Double.random(in: 0..<1) < 0.09 {
                    solid[i] = true
                    trees.append(Tree(x: x, y: y, kind: Int.random(in: 0...1)))
                }
            }
        }

        var variants = [Int](repeating: 0, count: n * n)
        var pathTiles: [(x: Int, y: Int)] = []
        for y in 0..<n {
            for x in 0..<n {
                let roll = Int.random(in: 0..<12)
                variants[index(x, y)] = roll == 0 ? 2 : roll % 2
                if ground[index(x, y)] == .path { pathTiles.append((x, y)) }
            }
        }

        self.ground = ground
        self.grassVariant = variants
        self.solid = solid
        self.houses = houses
        self.post = post
        self.trees = trees
        self.pathTiles = pathTiles
    }

    func groundAt(_ x: Int, _ y: Int) -> Ground? {
        let n = World.size
        guard x >= 0, y >= 0, x < n, y < n else { return nil }
        return ground[y * n + x]
    }

    func isSolid(tileX x: Int, tileY y: Int) -> Bool {
        let n = World.size
        guard x >= 0, y >= 0, x < n, y < n else { return true }
        return solid[y * n + x]
    }

    func isSolid(at point: CGPoint) -> Bool {
        isSolid(tileX: Int((point.x / World.tile).rounded(.down)), tileY: Int((point.y / World.tile).rounded(.down)))
    }

    /// Bit mask of neighbours sharing this tile's ground: 1 north, 2 east, 4 south, 8 west.
    func neighbourMask(_ x: Int, _ y: Int) -> Int {
        guard let here = groundAt(x, y) else { return 15 }
        func same(_ nx: Int, _ ny: Int) -> Bool {
            guard let other = groundAt(nx, ny) else { return true }
            return other == here
        }
        var mask = 0
        if same(x, y + 1) { mask |= 1 }
        if same(x + 1, y) { mask |= 2 }
        if same(x, y - 1) { mask |= 4 }
        if same(x - 1, y) { mask |= 8 }
        return mask
    }
}
