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
    private let stickBase = SKSpriteNode()
    private let stickKnob = SKSpriteNode()
    let snowfall = SKEmitterNode()

    // Village life (see GameScene+Life.swift)
    var walkers: [Walker] = []
    var critters: [Critter] = []
    var birds: [Bird] = []
    var skaters: [Skater] = []
    var strollable: [Bool] = []
    var strollTiles: [Int] = []
    var tintColour = SKColor.white
    var marketTiles: [Int] = []
    var catNode: SKSpriteNode?
    var catFollow: TimeInterval = 0
    var catClock: TimeInterval = 0
    var fireworkClock: TimeInterval = 0
    var statusClock: TimeInterval = 0

    // Moving about
    var iceTiles: [Bool] = []
    var slide = CGVector.zero
    var boostLeft: TimeInterval = 0
    var rushLeft: TimeInterval = 0
    var bellCooldown: TimeInterval = 0

    // Garden building and the tutorial (see GameScene+Build.swift)
    var building = false
    var gardenNodes: [Int: [SKNode]] = [:]
    var baseSolid: [Bool] = []
    let buildGrid = SKNode()
    let farmLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var trackDistance: CGFloat = 0
    private var soundDistance: CGFloat = 0

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
    let chopZoneNode = SKSpriteNode(color: SKColor(red: 0.3, green: 0.72, blue: 0.4, alpha: 1), size: CGSize(width: 9, height: 5))
    var chopZone: CGFloat = 0.5

    // Flow
    var currentAction: Action?
    var afterDialog: (() -> Void)?
    var arrowTarget: CGPoint?
    var busy = false
    var night: CGFloat = 1
    private var appliedNight: CGFloat = -1

    var solid: [Bool] = []
    var snowy: [Bool] = []
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
    let walkFrames = [1, 0, 2, 0]

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
        baseSolid = solid
        snowy = Array(world.snow.utf8).map { $0 == 49 }
        strollable = Array(world.stroll.utf8).map { $0 == 49 }
        strollTiles = strollable.indices.filter { strollable[$0] }
        iceTiles = Array(world.ice.utf8).map { $0 == 49 }
        if let stall = world.stalls.first {
            let row = Int((stall.y / world.tile).rounded(.down))
            marketTiles = strollTiles.filter { $0 / world.cols == row || $0 / world.cols == row - 1 }
        }
        Sound.shared.start()
        state.soundOn = Sound.shared.enabled

        addChild(worldNode)
        addChild(cam)
        camera = cam
        buildStatic()

        // Faint squares that show where decorations can go while in build mode.
        buildGrid.zPosition = 2
        buildGrid.isHidden = true
        for row in world.garden.row0...world.garden.row1 {
            for col in world.garden.col0...world.garden.col1 {
                let cell = SKSpriteNode(color: SKColor(red: 1, green: 0.88, blue: 0.45, alpha: 0.2), size: CGSize(width: world.tile - 1, height: world.tile - 1))
                cell.position = CGPoint(x: (CGFloat(col) + 0.5) * world.tile, y: (CGFloat(row) + 0.5) * world.tile)
                buildGrid.addChild(cell)
            }
        }
        worldNode.addChild(buildGrid)

        // Your farm's name on the board by the garden. Drawn large and shrunk so it stays crisp.
        farmLabel.fontSize = 12
        farmLabel.setScale(0.5)
        farmLabel.fontColor = SKColor(red: 0.28, green: 0.17, blue: 0.1, alpha: 1)
        farmLabel.verticalAlignmentMode = .center
        farmLabel.horizontalAlignmentMode = .center
        farmLabel.position = CGPoint(x: world.nameboard.x, y: world.nameboard.y + 18)
        farmLabel.zPosition = depth(world.nameboard.y) + 1
        worldNode.addChild(farmLabel)

        player.texture = texture("\(playerBase)_down_0")
        player.size = CGSize(width: 20, height: 30)
        player.anchorPoint = CGPoint(x: 0.5, y: 0.04)
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
        let zone = chopZoneNode
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

        stickBase.texture = texture("stick_base")
        stickBase.size = CGSize(width: 46, height: 46)
        stickBase.alpha = 0.92
        stickBase.zPosition = 3600
        stickBase.isHidden = true
        cam.addChild(stickBase)
        stickKnob.texture = texture("stick_knob")
        stickKnob.size = CGSize(width: 20, height: 23)
        stickKnob.zPosition = 3601
        stickKnob.isHidden = true
        cam.addChild(stickKnob)

        // Snow falls in the world, not on the glass: flakes stay put as the camera moves.
        snowfall.particleTexture = texture("flake")
        snowfall.particleBirthRate = 46
        snowfall.particleLifetime = 7
        snowfall.particleLifetimeRange = 2
        snowfall.particleSpeed = 20
        snowfall.particleSpeedRange = 8
        snowfall.emissionAngle = -CGFloat.pi / 2 - 0.3
        snowfall.emissionAngleRange = 0.5
        snowfall.particlePositionRange = CGVector(dx: size.width * 1.7, dy: size.height * 1.5)
        snowfall.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.95, 0.95, 0], times: [0, 0.12, 0.8, 1])
        snowfall.particleScale = 0.85
        snowfall.particleScaleRange = 0.5
        snowfall.position = CGPoint(x: 0, y: 40)
        snowfall.zPosition = 3300
        snowfall.particleZPosition = 3300
        snowfall.targetNode = worldNode
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
        // a slow, uneven breathing so lamps and fires feel alive
        let slow = TimeInterval.random(in: 0.7...1.3)
        node.run(SKAction.repeatForever(SKAction.sequence([SKAction.scale(to: 1.06, duration: slow), SKAction.scale(to: 0.96, duration: slow * 0.8)])))
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
        catNode = nil
        catFollow = 0
        slide = .zero
        solid = baseSolid
        gardenNodes = [:]
        farmLabel.text = save.farmName.uppercased()

        if let cabin = world.props.first(where: { $0.sprite == "cabin" }) {
            addEmissive("cabin_lit", x: cabin.x, y: cabin.y, dusk: true)
            for dx in [CGFloat(-16), CGFloat(16)] {
                addGlow(WorldGlow(x: cabin.x + dx, y: cabin.y + 18, r: 22, c: [1, 0.74, 0.4]))
            }
        }
        buildFromSave()
        buildLife()
        buildGarden()
        applyWeather()

        player.position = CGPoint(x: world.cabinDoor.x, y: world.cabinDoor.y - 6)
        player.zPosition = depth(player.position.y)
        facing = "down"
        player.xScale = 1
        player.texture = texture("\(playerBase)_down_0")
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
        let active = state.screen == .playing && state.dialog == nil && state.ending == nil && state.curtain == nil && !state.mapOpen && !state.shopOpen && !building && !busy

        if active {
            movePlayer(dt)
            updateInteraction()
            updateTutorial()
        } else {
            if stickTouch != nil { resetStick() }
            slide = .zero
            player.texture = texture("\(playerBase)_\(facing)_0")
            clearAction()
        }
        if active {
            boostLeft = max(0, boostLeft - dt)
            rushLeft = max(0, rushLeft - dt)
        }
        bellCooldown = max(0, bellCooldown - dt)
        updateSled()
        updateLife(dt)
        updateFireworks(dt)
        tickStatus(dt)
        updateChopBar(dt)
        updateNight(dt)
        updateCamera()
        updateArrow(active)
    }

    /// Which set of player sprites to draw, depending on the outfit worn.
    var playerBase: String {
        "hero_\(min(3, max(0, save.look)))_\(min(2, max(0, save.outfit)))"
    }

    var isStormDay: Bool {
        state.screen == .playing && SaveData.event(for: save.day) == .storm && save.phase != .epilogue
    }

    private var walkSpeed: CGFloat {
        var speed: CGFloat = save.phase == .hauling ? (save.sledWax ? 82 : 66) : 82
        if save.boots { speed *= 1.15 }
        if boostLeft > 0 { speed *= 1.35 }
        return speed
    }

    private func movePlayer(_ dt: TimeInterval) {
        let step = CGFloat(dt)
        let speed = walkSpeed
        var onIce = false
        if let index = tileIndex(player.position), index < iceTiles.count {
            onIce = iceTiles[index]
        }
        // On ice you glide: the stick only nudges your speed, so you carry momentum.
        if onIce {
            let grip = min(1, step * 1.7)
            slide.dx += (stickVector.dx * speed * 1.3 - slide.dx) * grip
            slide.dy += (stickVector.dy * speed * 1.3 - slide.dy) * grip
        } else {
            slide = CGVector(dx: stickVector.dx * speed, dy: stickVector.dy * speed)
        }
        let dx = slide.dx * step
        let dy = slide.dy * step
        if abs(slide.dx) + abs(slide.dy) > 3 {
            let before = player.position
            var position = before
            if dx != 0 {
                if blocked(CGPoint(x: position.x + dx, y: position.y)) { slide.dx = 0 } else { position.x += dx }
            }
            if dy != 0 {
                if blocked(CGPoint(x: position.x, y: position.y + dy)) { slide.dy = 0 } else { position.y += dy }
            }
            player.position = position
            if abs(dx) > abs(dy) {
                facing = "side"
                player.xScale = dx < 0 ? -1 : 1
            } else {
                facing = dy > 0 ? "up" : "down"
                player.xScale = 1
            }
            walkClock += dt
            let pace: TimeInterval = onIce ? 0.34 : 0.12
            player.texture = texture("\(playerBase)_\(facing)_\(walkFrames[Int(walkClock / pace) % walkFrames.count])")
            leaveTracks(from: before, to: position, onIce: onIce)
        } else {
            walkClock = 0
            player.texture = texture("\(playerBase)_\(facing)_0")
        }
        player.zPosition = depth(player.position.y)
        playerGlow.position = CGPoint(x: player.position.x, y: player.position.y + 10)
    }

    func tileIndex(_ point: CGPoint) -> Int? {
        let tx = Int((point.x / world.tile).rounded(.down))
        let ty = Int((point.y / world.tile).rounded(.down))
        guard tx >= 0, ty >= 0, tx < world.cols, ty < world.rows else { return nil }
        return ty * world.cols + tx
    }

    func blocked(_ feet: CGPoint) -> Bool {
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

    /// Footprints in snow, skate lines on ice, and the sound of each.
    private func leaveTracks(from before: CGPoint, to after: CGPoint, onIce: Bool) {
        let dx = after.x - before.x
        let dy = after.y - before.y
        let moved = sqrt(dx * dx + dy * dy)
        guard moved > 0 else { return }
        trackDistance += moved
        soundDistance += moved
        if soundDistance >= (onIce ? 30 : 17) {
            soundDistance = 0
            if onIce {
                Sound.shared.play("skate", volume: 0.35)
            } else {
                stepSide = -stepSide
                Sound.shared.play(stepSide > 0 ? "step_0" : "step_1", volume: 0.3)
            }
        }
        guard trackDistance >= (onIce ? 4 : 8) else { return }
        trackDistance = 0
        guard let index = tileIndex(after) else { return }
        let shade = 0.55 + 0.25 * (1 - night)
        let mark: SKSpriteNode
        if onIce {
            mark = SKSpriteNode(color: SKColor(red: shade * 1.25, green: shade * 1.3, blue: shade * 1.35, alpha: 1), size: CGSize(width: abs(dx) > abs(dy) ? 4 : 1, height: abs(dx) > abs(dy) ? 1 : 4))
            mark.position = CGPoint(x: after.x, y: after.y + 1)
        } else if index < snowy.count, snowy[index] {
            stepDistance = -stepDistance == 0 ? 1 : -stepDistance
            let side: CGFloat = stepDistance > 0 ? 1 : -1
            mark = SKSpriteNode(color: SKColor(red: shade * 0.92, green: shade * 0.98, blue: shade * 1.15, alpha: 1), size: CGSize(width: 2, height: 2))
            mark.position = CGPoint(x: after.x - dy / moved * 2.5 * side, y: after.y + dx / moved * 2.5 * side)
        } else {
            return
        }
        mark.zPosition = 1
        mark.alpha = 0.85
        worldNode.addChild(mark)
        let stay: TimeInterval = isStormDay ? 1.5 : 5
        mark.run(SKAction.sequence([SKAction.wait(forDuration: stay), SKAction.fadeOut(withDuration: 3), SKAction.removeFromParent()]))
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
        chopZoneNode.position = CGPoint(x: -15 + 30 * chopZone, y: 0)
    }

    // MARK: - Night and light

    private var nightTarget: CGFloat {
        if state.screen == .title { return 1 }
        switch save.phase {
        case .morning: return isStormDay ? 0.3 : 0
        case .seeking: return isStormDay ? 0.34 : 0.12
        case .hauling: return 0.5
        case .evening, .epilogue: return 1
        }
    }

    /// Jumps straight to the right light for this moment (used when a game is opened).
    func snapNight() {
        night = nightTarget
        applyNight(force: true)
    }

    private func updateNight(_ dt: TimeInterval) {
        let target = nightTarget
        if night != target {
            // Slow on purpose: dusk takes most of the walk down to the village.
            let step = CGFloat(dt) * 0.014
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
        tintColour = colour
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
        var focus = CGPoint(x: player.position.x, y: player.position.y + 10)
        if state.screen == .title {
            focus = CGPoint(x: world.square.x, y: world.square.y + 20)
        } else if building {
            focus = gardenCentre
        }
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
        if building, state.screen == .playing {
            if let touch = touches.first {
                buildTap(at: touch.location(in: worldNode))
            }
            return
        }
        guard state.screen == .playing, state.dialog == nil, state.ending == nil, state.curtain == nil, !state.mapOpen, !state.shopOpen, !busy else { return }
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
        let reach = min(length, 13)
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
