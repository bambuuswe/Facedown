import SpriteKit
import UIKit

private final class Goose {
    let node: SKSpriteNode
    var direction = CGVector.zero
    var think: TimeInterval = 0
    var cooldown: TimeInterval = 0
    var anim: TimeInterval = 0

    init(node: SKSpriteNode) {
        self.node = node
    }
}

final class GameScene: SKScene {
    private let state: GameState
    private var world = World()
    private let worldNode = SKNode()
    private let cam = SKCameraNode()
    private let tint = SKSpriteNode(color: .clear, size: CGSize(width: 1, height: 1))
    private let arrow = SKSpriteNode()
    private let stickBase = SKShapeNode(circleOfRadius: 18)
    private let stickKnob = SKShapeNode(circleOfRadius: 8)
    private var textures: [String: SKTexture] = [:]
    private var didSetUp = false

    private var fox = SKSpriteNode()
    private var foxFacing = "down"
    private var foxAnim: TimeInterval = 0
    private var stun: TimeInterval = 0
    private var geese: [Goose] = []
    private var houseMarkers: [SKSpriteNode] = []
    private var postMarker = SKSpriteNode()

    private var bag: [Int] = []
    private var toPickUp = 0
    private var delivered = 0
    private var quota = 0
    private var timeLeft: TimeInterval = 60
    private var lastTime: TimeInterval = 0

    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private var stickVector = CGVector.zero

    private let walkFrames = [1, 0, 2, 0]

    init(size: CGSize, state: GameState) {
        self.state = state
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard !didSetUp else { return }
        didSetUp = true
        backgroundColor = SKColor(red: 0.42, green: 0.71, blue: 0.28, alpha: 1)
        addChild(worldNode)
        addChild(cam)
        camera = cam

        tint.size = CGSize(width: size.width + 8, height: size.height + 8)
        tint.zPosition = 9000
        tint.alpha = 0
        cam.addChild(tint)

        arrow.texture = texture("arrow")
        arrow.size = CGSize(width: 9, height: 9)
        arrow.zPosition = 9100
        arrow.isHidden = true
        cam.addChild(arrow)

        stickBase.fillColor = SKColor(white: 1, alpha: 0.15)
        stickBase.strokeColor = SKColor(white: 1, alpha: 0.45)
        stickBase.lineWidth = 1
        stickBase.zPosition = 9200
        stickBase.isHidden = true
        cam.addChild(stickBase)
        stickKnob.fillColor = SKColor(white: 1, alpha: 0.6)
        stickKnob.strokeColor = .clear
        stickKnob.zPosition = 9201
        stickKnob.isHidden = true
        cam.addChild(stickKnob)

        buildDay()
    }

    private func texture(_ name: String) -> SKTexture {
        if let cached = textures[name] { return cached }
        let made = SKTexture(imageNamed: name)
        made.filteringMode = .nearest
        textures[name] = made
        return made
    }

    private func sprite(_ name: String) -> SKSpriteNode {
        let tex = texture(name)
        let node = SKSpriteNode(texture: tex, size: tex.size())
        return node
    }

    private func depth(_ y: CGFloat) -> CGFloat {
        2000 - y
    }

    private func buildDay() {
        worldNode.removeAllChildren()
        geese = []
        houseMarkers = []
        world = World()
        let n = World.size
        let tile = World.tile

        // Ground.
        var groups: [String: SKTileGroup] = [:]
        let tileSize = CGSize(width: tile, height: tile)
        for v in 0..<3 {
            groups["grass_\(v)"] = SKTileGroup(tileDefinition: SKTileDefinition(texture: texture("grass_\(v)"), size: tileSize))
        }
        for mask in 0..<16 {
            groups["path_\(mask)"] = SKTileGroup(tileDefinition: SKTileDefinition(texture: texture("path_\(mask)"), size: tileSize))
            let frames = [texture("water_\(mask)_0"), texture("water_\(mask)_1")]
            groups["water_\(mask)"] = SKTileGroup(tileDefinition: SKTileDefinition(textures: frames, size: tileSize, timePerFrame: 0.7))
        }
        let tileSet = SKTileSet(tileGroups: Array(groups.values))
        let map = SKTileMapNode(tileSet: tileSet, columns: n, rows: n, tileSize: tileSize)
        map.enableAutomapping = false
        map.anchorPoint = .zero
        map.zPosition = 0
        for y in 0..<n {
            for x in 0..<n {
                let name: String
                switch world.ground[y * n + x] {
                case .grass: name = "grass_\(world.grassVariant[y * n + x])"
                case .path: name = "path_\(world.neighbourMask(x, y))"
                case .water: name = "water_\(world.neighbourMask(x, y))"
                }
                if let group = groups[name] {
                    map.setTileGroup(group, forColumn: x, row: y)
                }
            }
        }
        worldNode.addChild(map)

        // Trees and buildings.
        for tree in world.trees {
            let node = sprite("tree_\(tree.kind)")
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = CGPoint(x: (CGFloat(tree.x) + 0.5) * tile, y: CGFloat(tree.y) * tile + 2)
            node.zPosition = depth(node.position.y)
            worldNode.addChild(node)
        }
        let bob = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.4),
            SKAction.moveBy(x: 0, y: -2, duration: 0.4)
        ]))
        func addBuilding(_ building: Building, spriteName: String, markerName: String) -> SKSpriteNode {
            let node = sprite(spriteName)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = building.base
            node.zPosition = depth(building.base.y)
            worldNode.addChild(node)
            let marker = sprite(markerName)
            marker.position = CGPoint(x: building.base.x, y: building.base.y + 66)
            marker.zPosition = 5000
            marker.isHidden = true
            marker.run(bob)
            worldNode.addChild(marker)
            return marker
        }
        for house in world.houses {
            houseMarkers.append(addBuilding(house, spriteName: "house_\(house.style)", markerName: "marker_letter"))
        }
        postMarker = addBuilding(world.post, spriteName: "post", markerName: "marker_post")

        // The fox starts at the post office door.
        fox = sprite("fox_down_0")
        fox.anchorPoint = CGPoint(x: 0.5, y: 0.06)
        fox.position = CGPoint(x: world.post.door.x, y: world.post.door.y - 12)
        fox.zPosition = depth(fox.position.y)
        foxFacing = "down"
        stun = 0
        worldNode.addChild(fox)

        // Geese start on the roads, away from the fox.
        let far = world.pathTiles.filter { abs($0.x - 18) + abs($0.y - 18) > 12 }
        let gooseCount = min(state.day + 1, 8)
        for _ in 0..<gooseCount {
            guard let spot = far.randomElement() else { break }
            let node = sprite("goose_0")
            node.anchorPoint = CGPoint(x: 0.5, y: 0.06)
            node.position = CGPoint(x: (CGFloat(spot.x) + 0.5) * tile, y: (CGFloat(spot.y) + 0.3) * tile)
            worldNode.addChild(node)
            geese.append(Goose(node: node))
        }

        bag = []
        quota = 4 + state.day
        toPickUp = quota
        delivered = 0
        timeLeft = TimeInterval(GameState.dayLength)
        resetStick()
        syncState()
        updateCamera()
        updateMarkers()
    }

    // MARK: - Commands from the menus

    func startGame() {
        state.day = 1
        state.coins = 0
        buildDay()
        state.phase = .playing
    }

    func nextDay() {
        state.day += 1
        buildDay()
        state.phase = .playing
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.05)
        lastTime = currentTime
        let playing = state.phase == .playing

        if playing {
            updateFox(dt)
        }
        updateGeese(dt, playing: playing)
        if playing {
            checkPostOffice()
            checkDeliveries()
        }
        if state.phase == .playing {
            timeLeft -= dt
            if timeLeft <= 0 {
                timeLeft = 0
                endGame()
            }
            let shown = Int(timeLeft.rounded(.up))
            if shown != state.seconds { state.seconds = shown }
        }
        updateCamera()
        updateMarkers()
        updateTint()
    }

    private func updateFox(_ dt: TimeInterval) {
        if stun > 0 {
            stun -= dt
            fox.alpha = Int(stun * 16) % 2 == 0 ? 1 : 0.35
            if stun <= 0 { fox.alpha = 1 }
            return
        }
        let speed: CGFloat = 66
        let dx = stickVector.dx * speed * CGFloat(dt)
        let dy = stickVector.dy * speed * CGFloat(dt)
        let moving = dx != 0 || dy != 0
        if moving {
            move(fox, dx: dx, dy: dy)
            if abs(dx) > abs(dy) {
                foxFacing = "side"
                fox.xScale = dx < 0 ? -1 : 1
            } else {
                foxFacing = dy > 0 ? "up" : "down"
                fox.xScale = 1
            }
            foxAnim += dt
            let frame = walkFrames[Int(foxAnim / 0.12) % walkFrames.count]
            fox.texture = texture("fox_\(foxFacing)_\(frame)")
        } else {
            foxAnim = 0
            fox.texture = texture("fox_\(foxFacing)_0")
        }
        fox.zPosition = depth(fox.position.y)
    }

    private func updateGeese(_ dt: TimeInterval, playing: Bool) {
        let chaseSpeed = min(46 + CGFloat(state.day) * 1.5, 58)
        for goose in geese {
            goose.cooldown -= dt
            let toFox = CGVector(dx: fox.position.x - goose.node.position.x, dy: fox.position.y - goose.node.position.y)
            let distance = max(0.001, sqrt(toFox.dx * toFox.dx + toFox.dy * toFox.dy))
            let chasing = playing && goose.cooldown <= 0 && stun <= 0 && distance < 72
            var speed: CGFloat = 22

            if chasing {
                goose.direction = CGVector(dx: toFox.dx / distance, dy: toFox.dy / distance)
                speed = chaseSpeed
            } else if goose.cooldown > 0 && distance < 64 {
                goose.direction = CGVector(dx: -toFox.dx / distance, dy: -toFox.dy / distance)
                speed = 40
            } else {
                goose.think -= dt
                if goose.think <= 0 {
                    goose.think = TimeInterval.random(in: 0.8...2.5)
                    if Int.random(in: 0..<3) == 0 {
                        goose.direction = .zero
                    } else {
                        let angle = CGFloat.random(in: 0..<(2 * .pi))
                        goose.direction = CGVector(dx: cos(angle), dy: sin(angle))
                    }
                }
            }

            let moving = goose.direction != .zero
            if moving {
                let moved = move(goose.node, dx: goose.direction.dx * speed * CGFloat(dt), dy: goose.direction.dy * speed * CGFloat(dt))
                if !moved { goose.think = 0 }
                if goose.direction.dx < -0.05 { goose.node.xScale = -1 }
                if goose.direction.dx > 0.05 { goose.node.xScale = 1 }
                goose.anim += dt * (chasing ? 1.6 : 1)
                goose.node.texture = texture("goose_\(walkFrames[Int(goose.anim / 0.14) % walkFrames.count])")
            } else {
                goose.node.texture = texture("goose_0")
            }
            goose.node.zPosition = depth(goose.node.position.y)

            if chasing && distance < 10 {
                goose.cooldown = 4
                stun = 0.6
                timeLeft = max(0, timeLeft - 6)
                state.showToast("HONK!  -6s")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    /// Slides a character by the given step, one axis at a time, stopping at solid tiles.
    @discardableResult
    private func move(_ node: SKNode, dx: CGFloat, dy: CGFloat) -> Bool {
        var position = node.position
        var moved = false
        if dx != 0 && !blocked(CGPoint(x: position.x + dx, y: position.y)) {
            position.x += dx
            moved = true
        }
        if dy != 0 && !blocked(CGPoint(x: position.x, y: position.y + dy)) {
            position.y += dy
            moved = true
        }
        node.position = position
        return moved
    }

    private func blocked(_ feet: CGPoint) -> Bool {
        let xs: [CGFloat] = [-4, 4]
        let ys: [CGFloat] = [0, 4]
        for ox in xs {
            for oy in ys {
                if world.isSolid(at: CGPoint(x: feet.x + ox, y: feet.y + oy)) { return true }
            }
        }
        return false
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Mail

    private func checkPostOffice() {
        guard toPickUp > 0, bag.count < GameState.bagSize, distance(fox.position, world.post.door) < 14 else { return }
        var taken = 0
        while toPickUp > 0 && bag.count < GameState.bagSize {
            let free = world.houses.indices.filter { !bag.contains($0) }
            guard let house = free.randomElement() else { break }
            bag.append(house)
            toPickUp -= 1
            taken += 1
        }
        if taken > 0 {
            state.showToast(taken == 1 ? "1 letter picked up" : "\(taken) letters picked up")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            syncState()
        }
    }

    private func checkDeliveries() {
        guard let slot = bag.firstIndex(where: { distance(fox.position, world.houses[$0].door) < 14 }) else { return }
        bag.remove(at: slot)
        delivered += 1
        state.coins += 10
        timeLeft += 6
        state.showToast("Delivered!  +6s")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        syncState()
        if delivered >= quota {
            endDay()
        }
    }

    private func endDay() {
        let bonus = Int(timeLeft)
        state.bonus = bonus
        state.coins += bonus
        state.recordBest()
        resetStick()
        state.phase = .dayDone
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func endGame() {
        state.seconds = 0
        state.recordBest()
        resetStick()
        state.phase = .gameOver
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func syncState() {
        state.bag = bag.count
        state.atPost = toPickUp
        state.delivered = delivered
        state.quota = quota
        state.seconds = Int(timeLeft.rounded(.up))
    }

    // MARK: - Camera, markers, light

    private func updateCamera() {
        let halfW = size.width / 2
        let halfH = size.height / 2
        let limit = world.pixelSize
        let x = min(max(fox.position.x, halfW), limit - halfW)
        let y = min(max(fox.position.y + 8, halfH), limit - halfH)
        cam.position = CGPoint(x: x, y: y)
    }

    private func updateMarkers() {
        for (i, marker) in houseMarkers.enumerated() {
            marker.isHidden = !bag.contains(i)
        }
        let postWanted = toPickUp > 0 && bag.count < GameState.bagSize
        postMarker.isHidden = !postWanted

        // Point at the nearest place worth going when it is off screen.
        var targets = bag.map { world.houses[$0].door }
        if bag.isEmpty && toPickUp > 0 { targets.append(world.post.door) }
        guard state.phase == .playing,
              let target = targets.min(by: { distance($0, fox.position) < distance($1, fox.position) }) else {
            arrow.isHidden = true
            return
        }
        let dx = target.x - cam.position.x
        let dy = target.y + 20 - cam.position.y
        let halfW = size.width / 2 - 10
        let halfH = size.height / 2 - 52
        if abs(dx) < halfW && abs(dy) < halfH {
            arrow.isHidden = true
            return
        }
        let scale = min(halfW / max(abs(dx), 0.001), halfH / max(abs(dy), 0.001))
        arrow.position = CGPoint(x: dx * scale, y: dy * scale)
        arrow.zRotation = atan2(dy, dx)
        arrow.isHidden = false
    }

    /// Late afternoon turns the village orange, then dusk blue.
    private func updateTint() {
        let f = CGFloat(min(1, max(0, 1 - timeLeft / TimeInterval(GameState.dayLength))))
        if f < 0.5 {
            tint.alpha = 0
        } else if f < 0.8 {
            let t = (f - 0.5) / 0.3
            tint.color = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1)
            tint.alpha = 0.22 * t
        } else {
            let t = (f - 0.8) / 0.2
            tint.color = SKColor(red: 1.0 - 0.85 * t, green: 0.55 - 0.4 * t, blue: 0.2 + 0.25 * t, alpha: 1)
            tint.alpha = 0.22 + 0.26 * t
        }
    }

    // MARK: - Touch joystick

    private func resetStick() {
        stickTouch = nil
        stickVector = .zero
        stickBase.isHidden = true
        stickKnob.isHidden = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state.phase == .playing, stickTouch == nil, let touch = touches.first else { return }
        stickTouch = touch
        stickOrigin = touch.location(in: cam)
        stickBase.position = stickOrigin
        stickKnob.position = stickOrigin
        stickBase.isHidden = false
        stickKnob.isHidden = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        let point = touch.location(in: cam)
        let dx = point.x - stickOrigin.x
        let dy = point.y - stickOrigin.y
        let length = sqrt(dx * dx + dy * dy)
        if length < 2 {
            stickVector = .zero
            stickKnob.position = stickOrigin
            return
        }
        let strength = min(1, length / 9)
        stickVector = CGVector(dx: dx / length * strength, dy: dy / length * strength)
        let reach = min(length, 16)
        stickKnob.position = CGPoint(x: stickOrigin.x + dx / length * reach, y: stickOrigin.y + dy / length * reach)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        resetStick()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        resetStick()
    }
}
