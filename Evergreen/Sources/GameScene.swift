import SpriteKit
import UIKit

/// The world on screen: drawing, walking, the camera and the day-to-night light.
/// The rules of the game live in GameScene+Flow.swift.
final class GameScene: SKScene {
    let state: GameState
    let world: WorldData
    var save: SaveData

    // Layers
    let worldNode = SKNode()
    var dynamicNode = SKNode()
    let cam = SKCameraNode()
    let player = SKSpriteNode()
    private let playerGlow = SKSpriteNode()
    private let arrow = SKSpriteNode()
    private let stickBase = SKShapeNode(circleOfRadius: 18)
    private let stickKnob = SKShapeNode(circleOfRadius: 8)

    // Things rebuilt from the save
    var lotNodes: [SKSpriteNode] = []
    var giantNode: SKSpriteNode?
    var sledNode: SKNode?
    var customerNode: SKSpriteNode?
    var markerNode: SKSpriteNode?
    var villagerNodes: [(house: Int, node: SKSpriteNode)] = []
    var duskNodes: [(node: SKNode, alpha: CGFloat)] = []
    private var staticTint: [SKSpriteNode] = []
    private var dynamicTint: [SKSpriteNode] = []

    // Chopping
    var chopDamage: [Int: Int] = [:]
    var chopSloppy: Set<Int> = []
    var chopCooldown: TimeInterval = 0
    var chopClock: TimeInterval = 0
    let chopBar = SKNode()
    let chopMarker = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 7))

    // Flow
    var currentAction: Action?
    var afterDialog: (() -> Void)?
    var arrowTarget: CGPoint?
    var busy = false
    var night: CGFloat = 1
    private var appliedNight: CGFloat = -1

    private var solid: [Bool] = []
    private var snowy: [Bool] = []
    private var textures: [String: SKTexture] = [:]
    private var didSetUp = false
    private var lastTime: TimeInterval = 0
    private var facing = "down"
    private var walkClock: TimeInterval = 0
    private var stepDistance: CGFloat = 0
    private var stepSide: CGFloat = 1
    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private var stickVector = CGVector.zero
    private let walkFrames = [1, 0, 2, 0]

    init(size: CGSize, state: GameState) {
        self.state = state
        let world = WorldData.load()
        self.world = world
        if let stored = SaveData.load(world: world) {
            save = stored
            state.hasSave = true
        } else {
            save = SaveData.newGame(world: world)
            state.hasSave = false
        }
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard !didSetUp else { return }
        didSetUp = true
        backgroundColor = SKColor(red: 0.12, green: 0.16, blue: 0.3, alpha: 1)
        solid = Array(world.solid.utf8).map { $0 == 49 }
        snowy = Array(world.snow.utf8).map { $0 == 49 }

        addChild(worldNode)
        addChild(cam)
        camera = cam
        buildStatic()

        player.texture = texture("player_down_0")
        player.size = CGSize(width: 16, height: 22)
        player.anchorPoint = CGPoint(x: 0.5, y: 0.05)
        player.colorBlendFactor = 1
        worldNode.addChild(player)
        staticTint.append(player)

        playerGlow.texture = texture("glow")
        playerGlow.size = CGSize(width: 84, height: 84)
        playerGlow.color = SKColor(red: 1, green: 0.78, blue: 0.5, alpha: 1)
        playerGlow.colorBlendFactor = 1
        playerGlow.blendMode = .add
        playerGlow.zPosition = 3200
        playerGlow.alpha = 0
        worldNode.addChild(playerGlow)

        chopBar.zPosition = 3400
        chopBar.isHidden = true
        let back = SKSpriteNode(color: SKColor(red: 0.17, green: 0.2, blue: 0.33, alpha: 1), size: CGSize(width: 34, height: 7))
        let track = SKSpriteNode(color: SKColor(red: 0.93, green: 0.95, blue: 1, alpha: 1), size: CGSize(width: 32, height: 5))
        let zone = SKSpriteNode(color: SKColor(red: 0.3, green: 0.72, blue: 0.4, alpha: 1), size: CGSize(width: 9, height: 5))
        chopMarker.color = SKColor(red: 0.85, green: 0.28, blue: 0.24, alpha: 1)
        back.zPosition = 0
        track.zPosition = 1
        zone.zPosition = 2
        chopMarker.zPosition = 3
        chopBar.addChild(back)
        chopBar.addChild(track)
        chopBar.addChild(zone)
        chopBar.addChild(chopMarker)
        worldNode.addChild(chopBar)

        arrow.texture = texture("arrow")
        arrow.size = CGSize(width: 9, height: 9)
        arrow.zPosition = 3500
        arrow.isHidden = true
        cam.addChild(arrow)

        stickBase.fillColor = SKColor(white: 1, alpha: 0.15)
        stickBase.strokeColor = SKColor(white: 1, alpha: 0.45)
        stickBase.lineWidth = 1
        stickBase.zPosition = 3600
        stickBase.isHidden = true
        cam.addChild(stickBase)
        stickKnob.fillColor = SKColor(white: 1, alpha: 0.6)
        stickKnob.strokeColor = .clear
        stickKnob.zPosition = 3601
        stickKnob.isHidden = true
        cam.addChild(stickKnob)

        let snowfall = SKEmitterNode()
        snowfall.particleTexture = texture("flake")
        snowfall.particleBirthRate = 16
        snowfall.particleLifetime = 10
        snowfall.particleSpeed = 24
        snowfall.particleSpeedRange = 10
        snowfall.emissionAngle = -CGFloat.pi / 2 - 0.25
        snowfall.emissionAngleRange = 0.5
        snowfall.particlePositionRange = CGVector(dx: size.width * 1.6, dy: 0)
        snowfall.particleAlpha = 0.9
        snowfall.particleAlphaRange = 0.2
        snowfall.position = CGPoint(x: 20, y: size.height / 2 + 6)
        snowfall.zPosition = 3300
        snowfall.advanceSimulationTime(10)
        cam.addChild(snowfall)

        rebuildDynamic()
        refreshHUD()
    }

    func texture(_ name: String) -> SKTexture {
        if let cached = textures[name] { return cached }
        let made = SKTexture(imageNamed: name)
        made.filteringMode = .nearest
        textures[name] = made
        return made
    }

    func depth(_ y: CGFloat) -> CGFloat {
        100 + (world.height - y)
    }

    /// A sprite standing on its bottom centre, sorted by depth and dimmed at night.
    @discardableResult
    func addStanding(_ name: String, x: CGFloat, y: CGFloat, to parent: SKNode, isStatic: Bool = false) -> SKSpriteNode {
        let tex = texture(name)
        let node = SKSpriteNode(texture: tex, size: tex.size())
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: x, y: y)
        node.zPosition = depth(y)
        node.colorBlendFactor = 1
        parent.addChild(node)
        if isStatic {
            staticTint.append(node)
        } else {
            dynamicTint.append(node)
        }
        return node
    }

    /// A sprite that shines: it keeps its colours at night. `dusk` ones only show after dark.
    @discardableResult
    func addEmissive(_ name: String, x: CGFloat, y: CGFloat, dusk: Bool) -> SKSpriteNode {
        let tex = texture(name)
        let node = SKSpriteNode(texture: tex, size: tex.size())
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: x, y: y)
        node.zPosition = depth(y) + 0.5
        dynamicNode.addChild(node)
        if dusk { duskNodes.append((node, 1)) }
        return node
    }

    @discardableResult
    func addGlow(_ glow: WorldGlow, strength: CGFloat = 0.75) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture("glow"), size: CGSize(width: glow.r * 2, height: glow.r * 2))
        let c = glow.c.count == 3 ? glow.c : [1, 0.72, 0.38]
        node.color = SKColor(red: c[0], green: c[1], blue: c[2], alpha: 1)
        node.colorBlendFactor = 1
        node.blendMode = .add
        node.position = CGPoint(x: glow.x, y: glow.y)
        node.zPosition = 3200
        dynamicNode.addChild(node)
        duskNodes.append((node, strength))
        return node
    }

    private func buildStatic() {
        let ground = SKSpriteNode(texture: texture("ground"), size: CGSize(width: world.width, height: world.height))
        ground.anchorPoint = .zero
        ground.position = .zero
        ground.zPosition = 0
        ground.colorBlendFactor = 1
        worldNode.addChild(ground)
        staticTint.append(ground)
        for prop in world.props {
            addStanding(prop.sprite, x: prop.x, y: prop.y, to: worldNode, isStatic: true)
        }
        for light in world.lights {
            for part in light.parts where !part.sprite.isEmpty {
                addStanding(part.sprite, x: part.x, y: part.y, to: worldNode, isStatic: true)
            }
        }
    }

    /// Throws away everything that depends on the save and builds it again.
    func rebuildDynamic() {
        dynamicNode.removeFromParent()
        dynamicNode = SKNode()
        worldNode.addChild(dynamicNode)
        duskNodes = []
        dynamicTint = []
        villagerNodes = []
        lotNodes = []
        giantNode = nil
        sledNode = nil
        customerNode = nil
        markerNode = nil
        chopDamage = [:]
        chopSloppy = []
        currentAction = nil
        appliedNight = -1

        if let cabin = world.props.first(where: { $0.sprite == "cabin" }) {
            addEmissive("cabin_lit", x: cabin.x, y: cabin.y, dusk: true)
            for dx in [CGFloat(-16), CGFloat(16)] {
                addGlow(WorldGlow(x: cabin.x + dx, y: cabin.y + 18, r: 22, c: [1, 0.74, 0.4]))
            }
        }
        buildFromSave()

        player.position = CGPoint(x: world.cabinDoor.x, y: world.cabinDoor.y - 6)
        player.zPosition = depth(player.position.y)
        facing = "down"
        player.xScale = 1
        player.texture = texture("player_down_0")
        applyNight(force: true)
    }

    func registerTint(_ node: SKSpriteNode) {
        node.colorBlendFactor = 1
        dynamicTint.append(node)
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.05)
        lastTime = currentTime
        let active = state.screen == .playing && state.dialog == nil && state.ending == nil && state.curtain == nil && !busy

        if active {
            movePlayer(dt)
            updateInteraction()
        } else {
            if stickTouch != nil { resetStick() }
            player.texture = texture("player_\(facing)_0")
            clearAction()
        }
        updateSled()
        updateChopBar(dt)
        updateNight(dt)
        updateCamera()
        updateArrow(active)
    }

    private func movePlayer(_ dt: TimeInterval) {
        let speed: CGFloat = save.phase == .hauling ? 58 : 66
        let dx = stickVector.dx * speed * CGFloat(dt)
        let dy = stickVector.dy * speed * CGFloat(dt)
        if dx != 0 || dy != 0 {
            let before = player.position
            var position = before
            if dx != 0 && !blocked(CGPoint(x: position.x + dx, y: position.y)) { position.x += dx }
            if dy != 0 && !blocked(CGPoint(x: position.x, y: position.y + dy)) { position.y += dy }
            player.position = position
            if abs(dx) > abs(dy) {
                facing = "side"
                player.xScale = dx < 0 ? -1 : 1
            } else {
                facing = dy > 0 ? "up" : "down"
                player.xScale = 1
            }
            walkClock += dt
            player.texture = texture("player_\(facing)_\(walkFrames[Int(walkClock / 0.13) % walkFrames.count])")
            leaveFootprints(from: before, to: position)
        } else {
            walkClock = 0
            player.texture = texture("player_\(facing)_0")
        }
        player.zPosition = depth(player.position.y)
        playerGlow.position = CGPoint(x: player.position.x, y: player.position.y + 10)
    }

    private func tileIndex(_ point: CGPoint) -> Int? {
        let tx = Int((point.x / world.tile).rounded(.down))
        let ty = Int((point.y / world.tile).rounded(.down))
        guard tx >= 0, ty >= 0, tx < world.cols, ty < world.rows else { return nil }
        return ty * world.cols + tx
    }

    private func blocked(_ feet: CGPoint) -> Bool {
        let xs: [CGFloat] = [-4, 4]
        let ys: [CGFloat] = [0, 4]
        for ox in xs {
            for oy in ys {
                guard let index = tileIndex(CGPoint(x: feet.x + ox, y: feet.y + oy)), index < solid.count else { return true }
                if solid[index] { return true }
            }
        }
        return false
    }

    private func leaveFootprints(from before: CGPoint, to after: CGPoint) {
        let dx = after.x - before.x
        let dy = after.y - before.y
        let moved = sqrt(dx * dx + dy * dy)
        guard moved > 0 else { return }
        stepDistance += moved
        guard stepDistance >= 8 else { return }
        stepDistance = 0
        stepSide = -stepSide
        guard let index = tileIndex(after), index < snowy.count, snowy[index] else { return }
        let shade = 0.55 + 0.25 * (1 - night)
        let mark = SKSpriteNode(color: SKColor(red: shade * 0.92, green: shade * 0.98, blue: shade * 1.15, alpha: 1), size: CGSize(width: 2, height: 2))
        mark.position = CGPoint(x: after.x - dy / moved * 2.5 * stepSide, y: after.y + dx / moved * 2.5 * stepSide)
        mark.zPosition = 1
        mark.alpha = 0.85
        worldNode.addChild(mark)
        mark.run(SKAction.sequence([SKAction.wait(forDuration: 5), SKAction.fadeOut(withDuration: 3), SKAction.removeFromParent()]))
    }

    private func updateSled() {
        guard let sled = sledNode else { return }
        let dx = player.position.x - sled.position.x
        let dy = player.position.y - sled.position.y
        let length = sqrt(dx * dx + dy * dy)
        let rope: CGFloat = 17
        if length > rope {
            sled.position = CGPoint(x: player.position.x - dx / length * rope, y: player.position.y - dy / length * rope)
        }
        if dx > 2 { sled.xScale = 1 }
        if dx < -2 { sled.xScale = -1 }
        sled.zPosition = depth(sled.position.y) - 0.2
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Chop timing bar

    /// Where the marker is on the bar, from 0 to 1.
    var chopSwing: CGFloat {
        let phase = CGFloat((chopClock / 0.95).truncatingRemainder(dividingBy: 1))
        return phase < 0.5 ? phase * 2 : 2 - phase * 2
    }

    private func updateChopBar(_ dt: TimeInterval) {
        chopCooldown = max(0, chopCooldown - dt)
        guard let action = currentAction, case .chop(let index) = action else {
            chopBar.isHidden = true
            return
        }
        chopClock += dt
        let node = index < 0 ? giantNode : (index < lotNodes.count ? lotNodes[index] : nil)
        guard let tree = node else {
            chopBar.isHidden = true
            return
        }
        chopBar.isHidden = false
        chopBar.position = CGPoint(x: tree.position.x, y: tree.position.y + tree.size.height + 6)
        chopMarker.position = CGPoint(x: -15 + 30 * chopSwing, y: 0)
    }

    // MARK: - Night and light

    private var nightTarget: CGFloat {
        if state.screen == .title { return 1 }
        switch save.phase {
        case .morning, .seeking: return 0
        case .hauling: return 0.5
        case .evening, .epilogue: return 1
        }
    }

    private func updateNight(_ dt: TimeInterval) {
        let target = nightTarget
        if night != target {
            let step = CGFloat(dt) * 0.2
            night = night < target ? min(target, night + step) : max(target, night - step)
        }
        applyNight(force: false)
    }

    func applyNight(force: Bool) {
        guard force || abs(night - appliedNight) > 0.003 else { return }
        appliedNight = night
        // White by day, peach at dusk, deep blue at night.
        let dusk: [CGFloat] = [1.0, 0.82, 0.7]
        let dark: [CGFloat] = [0.38, 0.44, 0.76]
        var rgb: [CGFloat] = [1, 1, 1]
        for k in 0..<3 {
            if night < 0.5 {
                rgb[k] = 1 + (dusk[k] - 1) * (night / 0.5)
            } else {
                rgb[k] = dusk[k] + (dark[k] - dusk[k]) * ((night - 0.5) / 0.5)
            }
        }
        let colour = SKColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
        for node in staticTint { node.color = colour }
        for node in dynamicTint { node.color = colour }

        let t = min(1, max(0, (night - 0.3) / 0.6))
        let glow = t * t * (3 - 2 * t)
        for entry in duskNodes { entry.node.alpha = entry.alpha * glow }
        playerGlow.alpha = 0.45 * glow
    }

    // MARK: - Camera and pointer

    private func updateCamera() {
        let halfW = size.width / 2
        let halfH = size.height / 2
        let focus = state.screen == .title ? CGPoint(x: world.square.x, y: world.square.y + 20) : CGPoint(x: player.position.x, y: player.position.y + 10)
        let x = min(max(focus.x, halfW), world.width - halfW)
        let y = min(max(focus.y, halfH), world.height - halfH)
        cam.position = CGPoint(x: x, y: y)
    }

    private func updateArrow(_ active: Bool) {
        guard active, let target = arrowTarget else {
            arrow.isHidden = true
            return
        }
        let dx = target.x - cam.position.x
        let dy = target.y - cam.position.y
        let halfW = size.width / 2 - 10
        let halfH = size.height / 2 - 70
        if abs(dx) < halfW && abs(dy) < halfH {
            arrow.isHidden = true
            return
        }
        let scale = min(halfW / max(abs(dx), 0.001), halfH / max(abs(dy), 0.001))
        arrow.position = CGPoint(x: dx * scale, y: dy * scale)
        arrow.zRotation = atan2(dy, dx)
        arrow.isHidden = false
    }

    // MARK: - Effects

    func burst(_ name: String, at point: CGPoint, count: Int, spread: CGFloat, rise: CGFloat, additive: Bool) {
        for _ in 0..<count {
            let tex = texture(name)
            let node = SKSpriteNode(texture: tex, size: tex.size())
            node.position = CGPoint(x: point.x + CGFloat.random(in: -spread...spread), y: point.y + CGFloat.random(in: -spread...spread) * 0.6)
            node.zPosition = 3300
            if additive { node.blendMode = .add }
            worldNode.addChild(node)
            let time = TimeInterval.random(in: 0.5...1.0)
            let drift = SKAction.moveBy(x: CGFloat.random(in: -spread...spread) * 0.5, y: rise * CGFloat.random(in: 0.5...1.2), duration: time)
            node.run(SKAction.sequence([SKAction.group([drift, SKAction.fadeOut(withDuration: time)]), SKAction.removeFromParent()]))
        }
    }

    // MARK: - Touch joystick

    func resetStick() {
        stickTouch = nil
        stickVector = .zero
        stickBase.isHidden = true
        stickKnob.isHidden = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state.screen == .playing, state.dialog == nil, state.ending == nil, state.curtain == nil, !busy else { return }
        guard stickTouch == nil, let touch = touches.first else { return }
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
