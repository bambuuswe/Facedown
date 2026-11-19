import SpriteKit

/// A villager out for a stroll along the streets.
final class Walker {
    let node: SKSpriteNode
    let base: String
    let house: Int
    let speed: CGFloat
    var route: [Int] = []
    var pause: TimeInterval
    var clock: TimeInterval = 0
    var facing = "down"

    init(node: SKSpriteNode, base: String, house: Int, speed: CGFloat, pause: TimeInterval) {
        self.node = node
        self.base = base
        self.house = house
        self.speed = speed
        self.pause = pause
    }
}

/// A sheep or a deer wandering inside its patch of the map.
final class Critter {
    let node: SKSpriteNode
    let kind: String
    let zone: CGRect
    let flees: Bool
    var direction = CGVector.zero
    var think: TimeInterval = 0
    var clock: TimeInterval = 0

    init(node: SKSpriteNode, kind: String, zone: CGRect, flees: Bool) {
        self.node = node
        self.kind = kind
        self.zone = zone
        self.flees = flees
    }
}

final class Bird {
    let node: SKSpriteNode
    var flying = false
    var timer: TimeInterval
    var velocity = CGVector.zero

    init(node: SKSpriteNode, timer: TimeInterval) {
        self.node = node
        self.timer = timer
    }
}

final class Skater {
    let node: SKSpriteNode
    let base: String
    let speed: CGFloat
    let reach: CGFloat
    var angle: CGFloat
    var clock: TimeInterval = 0

    init(node: SKSpriteNode, base: String, angle: CGFloat, speed: CGFloat, reach: CGFloat) {
        self.node = node
        self.base = base
        self.angle = angle
        self.speed = speed
        self.reach = reach
    }
}

/// Everything that moves on its own: villagers, skaters, animals, birds, chimney smoke.
extension GameScene {
    // MARK: - Building

    func buildLife() {
        walkers = []
        critters = []
        birds = []
        skaters = []

        for vendor in world.vendors {
            addStanding(vendor.sprite + "_down_0", x: vendor.x, y: vendor.y, to: dynamicNode)
        }

        for (index, base) in ["kid_0", "kid_1"].enumerated() {
            let node = addStanding(base + "_side_0", x: world.skate.x, y: world.skate.y, to: dynamicNode)
            skaters.append(Skater(node: node, base: base, angle: CGFloat(index) * CGFloat.pi, speed: index == 0 ? 0.55 : -0.4, reach: index == 0 ? 1.0 : 0.6))
        }

        // By day the neighbours are out and about; today's customer is busy with you.
        // In a snowstorm everyone stays indoors, birds included.
        let storm = SaveData.event(for: save.day) == .storm && save.phase != .epilogue
        if !storm && (save.phase == .morning || save.phase == .seeking || save.phase == .hauling) {
            var away = -1
            if save.day < SaveData.lastDay && save.day >= 1 && save.day <= save.houseOrder.count {
                away = save.houseOrder[save.day - 1]
            }
            for house in world.houses.indices where house != away {
                spawnWalker(base: world.houses[house].villager, house: house, speed: 20)
            }
            spawnWalker(base: "kid_2", house: -1, speed: 34)
        }

        let pen = CGRect(x: world.sheepZone.x0, y: world.sheepZone.y0, width: world.sheepZone.x1 - world.sheepZone.x0, height: world.sheepZone.y1 - world.sheepZone.y0)
        for _ in 0..<4 {
            spawnCritter(kind: "sheep", zone: pen, flees: false)
        }
        let woods = CGRect(x: world.deerZone.x0, y: world.deerZone.y0, width: world.deerZone.x1 - world.deerZone.x0, height: world.deerZone.y1 - world.deerZone.y0)
        for _ in 0..<3 {
            spawnCritter(kind: "deer", zone: woods, flees: true)
        }

        catNode = addStanding("cat_0", x: world.cat.x, y: world.cat.y, to: dynamicNode)

        for _ in 0..<(storm ? 0 : 6) {
            let home = randomOpenPoint()
            for _ in 0..<3 {
                let node = addStanding("bird_0", x: home.x + CGFloat.random(in: -12...12), y: home.y + CGFloat.random(in: -8...8), to: dynamicNode)
                node.xScale = Bool.random() ? 1 : -1
                birds.append(Bird(node: node, timer: TimeInterval.random(in: 0.2...1.5)))
            }
        }

        addSmoke(world.cabinSmoke.cg)
    }

    private func tileCentre(_ index: Int) -> CGPoint {
        let col = index % world.cols
        let row = index / world.cols
        return CGPoint(x: (CGFloat(col) + 0.5) * world.tile, y: CGFloat(row) * world.tile + 6)
    }

    private func spawnWalker(base: String, house: Int, speed: CGFloat) {
        guard let start = strollTiles.randomElement() else { return }
        let point = tileCentre(start)
        let node = addStanding(base + "_down_0", x: point.x, y: point.y, to: dynamicNode)
        walkers.append(Walker(node: node, base: base, house: house, speed: speed, pause: TimeInterval.random(in: 0...3)))
    }

    private func spawnCritter(kind: String, zone: CGRect, flees: Bool) {
        var point = CGPoint(x: zone.midX, y: zone.midY)
        for _ in 0..<30 {
            let candidate = CGPoint(x: CGFloat.random(in: zone.minX...zone.maxX), y: CGFloat.random(in: zone.minY...zone.maxY))
            if !blocked(candidate) {
                point = candidate
                break
            }
        }
        let node = addStanding(kind + "_0", x: point.x, y: point.y, to: dynamicNode)
        critters.append(Critter(node: node, kind: kind, zone: zone, flees: flees))
    }

    /// A random spot on open snow, for birds to land on.
    private func randomOpenPoint() -> CGPoint {
        for _ in 0..<60 {
            let index = Int.random(in: 0..<max(1, snowy.count))
            if index < snowy.count, index < solid.count, snowy[index], !solid[index] {
                let point = tileCentre(index)
                return CGPoint(x: point.x, y: point.y + 2)
            }
        }
        return world.square.cg
    }

    /// When evening comes the strollers head indoors.
    func sendWalkersHome() {
        for walker in walkers {
            walker.node.run(SKAction.sequence([SKAction.fadeOut(withDuration: 1.5), SKAction.removeFromParent()]))
        }
        walkers = []
    }

    /// Sends every bird into the air at once (the chapel bell does this).
    func scatterBirds() {
        for bird in birds where !bird.flying {
            let side: CGFloat = Bool.random() ? 1 : -1
            bird.flying = true
            bird.timer = TimeInterval.random(in: 2.0...2.8)
            bird.velocity = CGVector(dx: side * CGFloat.random(in: 40...64), dy: CGFloat.random(in: 36...56))
            bird.node.xScale = side
            bird.node.zPosition = 3250
            bird.node.removeAllActions()
        }
        if !birds.isEmpty { Sound.shared.play("flutter", volume: 0.6) }
    }

    func addSmoke(_ point: CGPoint) {
        let source = SKNode()
        source.position = point
        dynamicNode.addChild(source)
        let puff = SKAction.run { [weak self, weak source] in
            guard let self = self, let source = source, let parent = source.parent else { return }
            let tex = self.texture("puff")
            let node = SKSpriteNode(texture: tex, size: tex.size())
            node.position = CGPoint(x: source.position.x + CGFloat.random(in: -1...1), y: source.position.y)
            node.zPosition = 2500
            node.alpha = 0.7
            node.color = self.tintColour
            node.colorBlendFactor = 1
            parent.addChild(node)
            let time: TimeInterval = 3.4
            let rise = SKAction.moveBy(x: CGFloat.random(in: 4...13), y: 28, duration: time)
            node.run(SKAction.sequence([
                SKAction.group([rise, SKAction.fadeOut(withDuration: time), SKAction.scale(to: 2.1, duration: time)]),
                SKAction.removeFromParent()
            ]))
        }
        source.run(SKAction.repeatForever(SKAction.sequence([puff, SKAction.wait(forDuration: 1.1, withRange: 0.6)])))
    }

    // MARK: - Routes along the streets

    private func strollRoute(from start: Int, to goal: Int) -> [Int] {
        guard start != goal, start >= 0, goal >= 0, start < strollable.count, goal < strollable.count, strollable[start], strollable[goal] else { return [] }
        var previous = [Int](repeating: -1, count: strollable.count)
        var queue = [start]
        var head = 0
        previous[start] = start
        let cols = world.cols
        while head < queue.count {
            let current = queue[head]
            head += 1
            if current == goal { break }
            let col = current % cols
            var next: [Int] = []
            if col > 0 { next.append(current - 1) }
            if col < cols - 1 { next.append(current + 1) }
            if current >= cols { next.append(current - cols) }
            if current + cols < strollable.count { next.append(current + cols) }
            for step in next where strollable[step] && previous[step] == -1 {
                previous[step] = current
                queue.append(step)
            }
        }
        guard previous[goal] != -1 else { return [] }
        var path: [Int] = []
        var step = goal
        while step != start {
            path.append(step)
            step = previous[step]
        }
        return path.reversed()
    }

    // MARK: - Every frame

    func updateLife(_ dt: TimeInterval) {
        let playing = state.screen == .playing
        let step = CGFloat(dt)

        for walker in walkers {
            let near = playing && distance(walker.node.position, player.position) < 16
            if walker.pause > 0 || near {
                if !near { walker.pause -= dt }
                walker.node.texture = texture("\(walker.base)_\(walker.facing)_0")
                if walker.pause <= 0 && walker.route.isEmpty {
                    let from = tileIndex(walker.node.position) ?? -1
                    // On market day half of all errands lead to the stalls.
                    let toMarket = SaveData.event(for: save.day) == .market && Bool.random()
                    let goal = (toMarket ? marketTiles.randomElement() : strollTiles.randomElement()) ?? -1
                    walker.route = strollRoute(from: from, to: goal)
                    if walker.route.isEmpty { walker.pause = 1.5 }
                }
                continue
            }
            guard let next = walker.route.first else {
                walker.pause = TimeInterval.random(in: 1.5...5)
                continue
            }
            let target = tileCentre(next)
            let dx = target.x - walker.node.position.x
            let dy = target.y - walker.node.position.y
            let length = sqrt(dx * dx + dy * dy)
            let stride = walker.speed * step
            if length <= stride || length < 0.01 {
                walker.node.position = target
                walker.route.removeFirst()
            } else {
                walker.node.position = CGPoint(x: walker.node.position.x + dx / length * stride, y: walker.node.position.y + dy / length * stride)
                if abs(dx) > abs(dy) {
                    walker.facing = "side"
                    walker.node.xScale = dx < 0 ? -1 : 1
                } else {
                    walker.facing = dy > 0 ? "up" : "down"
                    walker.node.xScale = 1
                }
            }
            walker.clock += dt
            walker.node.texture = texture("\(walker.base)_\(walker.facing)_\(walkFrames[Int(walker.clock / 0.2) % walkFrames.count])")
            walker.node.zPosition = depth(walker.node.position.y)
        }

        for skater in skaters {
            skater.angle += skater.speed * step
            let x = world.skate.x + cos(skater.angle) * world.skate.rx * skater.reach
            let y = world.skate.y + sin(skater.angle) * world.skate.ry * skater.reach - 6
            let dx = x - skater.node.position.x
            skater.node.position = CGPoint(x: x, y: y)
            if dx > 0.001 { skater.node.xScale = 1 }
            if dx < -0.001 { skater.node.xScale = -1 }
            skater.clock += dt
            skater.node.texture = texture("\(skater.base)_side_\(Int(skater.clock / 0.6) % 2)")
            skater.node.zPosition = depth(y)
        }

        for critter in critters {
            let awayX = critter.node.position.x - player.position.x
            let awayY = critter.node.position.y - player.position.y
            let gap = max(0.001, sqrt(awayX * awayX + awayY * awayY))
            var speed: CGFloat = critter.kind == "deer" ? 12 : 8
            if critter.flees && playing && gap < 50 && save.treats == 0 {
                critter.direction = CGVector(dx: awayX / gap, dy: awayY / gap)
                critter.think = 0.6
                speed = 54
            } else {
                critter.think -= dt
                if critter.think <= 0 {
                    critter.think = TimeInterval.random(in: 1.5...4.5)
                    if Int.random(in: 0..<5) < 2 {
                        critter.direction = .zero
                    } else {
                        let angle = CGFloat.random(in: 0..<(2 * CGFloat.pi))
                        critter.direction = CGVector(dx: cos(angle), dy: sin(angle) * 0.6)
                    }
                }
            }
            if critter.direction != .zero {
                var position = critter.node.position
                let nextX = CGPoint(x: position.x + critter.direction.dx * speed * step, y: position.y)
                if critter.zone.contains(nextX) && !blocked(nextX) {
                    position = nextX
                } else {
                    critter.direction.dx = -critter.direction.dx
                }
                let nextY = CGPoint(x: position.x, y: position.y + critter.direction.dy * speed * step)
                if critter.zone.contains(nextY) && !blocked(nextY) {
                    position = nextY
                } else {
                    critter.direction.dy = -critter.direction.dy
                }
                critter.node.position = position
                if critter.direction.dx > 0.05 { critter.node.xScale = 1 }
                if critter.direction.dx < -0.05 { critter.node.xScale = -1 }
                critter.clock += dt * (speed > 20 ? 2.2 : 1)
                critter.node.texture = texture("\(critter.kind)_\(Int(critter.clock / 0.28) % 2)")
            } else {
                critter.node.texture = texture("\(critter.kind)_0")
            }
            critter.node.zPosition = depth(critter.node.position.y)
        }

        // The cat sits and flicks its tail, or trots after you for a while once petted.
        if let cat = catNode {
            catClock += dt
            if catFollow > 0 { catFollow -= dt }
            let gap = distance(cat.position, player.position)
            let name: String
            if catFollow > 0 && playing && gap > 24 {
                let pace = min(92, 40 + gap) * step
                let dx = player.position.x - cat.position.x
                let dy = player.position.y - cat.position.y
                cat.position = CGPoint(x: cat.position.x + dx / gap * pace, y: cat.position.y + dy / gap * pace)
                cat.xScale = dx < 0 ? -1 : 1
                name = "cat_walk_\(Int(catClock / 0.15) % 2)"
            } else {
                name = "cat_\(Int(catClock / 0.9) % 2)"
            }
            let tex = texture(name)
            cat.texture = tex
            cat.size = tex.size()
            cat.zPosition = depth(cat.position.y)
        }

        var fluttered = false
        for bird in birds {
            bird.timer -= dt
            if bird.flying {
                bird.node.position = CGPoint(x: bird.node.position.x + bird.velocity.dx * step, y: bird.node.position.y + bird.velocity.dy * step)
                bird.node.texture = texture("bird_fly_\(Int(bird.timer / 0.1) % 2 == 0 ? 0 : 1)")
                bird.node.alpha = CGFloat(min(1, max(0, bird.timer / 1.0)))
                if bird.timer <= 0 {
                    let home = randomOpenPoint()
                    bird.flying = false
                    bird.timer = TimeInterval.random(in: 0.5...2)
                    bird.node.position = home
                    bird.node.zPosition = depth(home.y)
                    bird.node.texture = texture("bird_0")
                    bird.node.run(SKAction.fadeIn(withDuration: 1.0))
                }
            } else if playing && distance(bird.node.position, player.position) < 30 {
                bird.flying = true
                bird.timer = 2.2
                let side: CGFloat = bird.node.position.x < player.position.x ? -1 : 1
                bird.velocity = CGVector(dx: side * CGFloat.random(in: 40...64), dy: CGFloat.random(in: 36...56))
                bird.node.xScale = side
                bird.node.zPosition = 3250
                bird.node.removeAllActions()
                if !fluttered {
                    fluttered = true
                    Sound.shared.play("flutter", volume: 0.4)
                }
            } else if bird.timer <= 0 {
                bird.timer = TimeInterval.random(in: 0.3...1.7)
                let roll = Int.random(in: 0..<4)
                if roll == 0 {
                    bird.node.xScale = -bird.node.xScale
                } else if roll == 1 {
                    bird.node.position.x += CGFloat.random(in: -3...3)
                }
                bird.node.texture = texture(roll >= 2 ? "bird_1" : "bird_0")
            }
        }
    }
}
