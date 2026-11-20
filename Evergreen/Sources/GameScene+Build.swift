import SpriteKit
import UIKit

/// Your own garden: build mode for placing decorations, plus the first-day tutorial.
extension GameScene {
    // MARK: - The garden

    func insideGarden(_ point: CGPoint) -> Bool {
        let col = Int((point.x / world.tile).rounded(.down))
        let row = Int((point.y / world.tile).rounded(.down))
        return col >= world.garden.col0 && col <= world.garden.col1 && row >= world.garden.row0 && row <= world.garden.row1
    }

    var gardenCentre: CGPoint {
        CGPoint(
            x: CGFloat(world.garden.col0 + world.garden.col1 + 1) * 0.5 * world.tile,
            y: CGFloat(world.garden.row0 + world.garden.row1 + 1) * 0.5 * world.tile - 40)
    }

    private func gardenPoint(_ tile: Int) -> CGPoint {
        CGPoint(x: (CGFloat(tile % world.cols) + 0.5) * world.tile, y: CGFloat(tile / world.cols) * world.tile + 2)
    }

    /// Puts every saved decoration back in the garden.
    func buildGarden() {
        for item in save.garden {
            placeGardenNodes(item, animated: false)
        }
    }

    private func placeGardenNodes(_ item: GardenItem, animated: Bool) {
        guard let kind = BuildKind.find(item.kind), item.tile >= 0, item.tile < solid.count else { return }
        let point = gardenPoint(item.tile)
        var nodes: [SKNode] = []
        nodes.append(addStanding(kind.sprite, x: point.x, y: point.y, to: dynamicNode))
        if !kind.lit.isEmpty {
            let shine = addEmissive(kind.lit, x: point.x, y: point.y, dusk: kind.dusk)
            if kind.lit.hasSuffix("_lit_0") {
                let other = String(kind.lit.dropLast(1)) + "1"
                shine.run(SKAction.repeatForever(SKAction.animate(with: [texture(kind.lit), texture(other)], timePerFrame: 0.17)))
            }
            nodes.append(shine)
        }
        if kind.glow > 0 {
            nodes.append(addGlow(WorldGlow(x: point.x, y: point.y + kind.glowHeight, r: kind.glow, c: [1, 0.72, 0.38])))
        }
        if kind.solid { solid[item.tile] = true }
        gardenNodes[item.tile] = nodes
        if animated {
            burst("sparkle", at: CGPoint(x: point.x, y: point.y + 8), count: 4, spread: 7, rise: 10, additive: true)
        }
        applyNight(force: true)
    }

    // MARK: - Build mode

    func enterBuild() {
        guard state.screen == .playing, state.dialog == nil, !busy else { return }
        resetStick()
        building = true
        buildGrid.isHidden = false
        state.buildOpen = true
        Sound.shared.play("tap")
    }

    func exitBuild() {
        building = false
        buildGrid.isHidden = true
        state.buildOpen = false
        Sound.shared.play("tap")
    }

    func selectBuild(_ id: String) {
        state.buildSelected = id
        Sound.shared.play("tap")
    }

    /// True if the player's feet reach into this tile, so nothing solid may go there.
    private func playerStands(on tile: Int) -> Bool {
        let xs: [CGFloat] = [-5, 5]
        let ys: [CGFloat] = [-1, 5]
        for ox in xs {
            for oy in ys {
                if tileIndex(CGPoint(x: player.position.x + ox, y: player.position.y + oy)) == tile { return true }
            }
        }
        return false
    }

    /// A tap in build mode: take back what is on that square, or place the chosen decoration.
    func buildTap(at point: CGPoint) {
        guard insideGarden(point), let tile = tileIndex(point) else {
            state.showToast("Decorations go inside your garden fence.")
            Sound.shared.play("nope")
            return
        }
        if let index = save.garden.firstIndex(where: { $0.tile == tile }) {
            let refund = BuildKind.find(save.garden[index].kind)?.price ?? 0
            save.garden.remove(at: index)
            save.coins += refund
            for node in gardenNodes[tile] ?? [] {
                node.removeFromParent()
            }
            gardenNodes[tile] = nil
            solid[tile] = tile < baseSolid.count ? baseSolid[tile] : false
            save.store()
            refreshHUD()
            Sound.shared.play("tap")
            return
        }
        guard let kind = BuildKind.find(state.buildSelected) else { return }
        guard save.coins >= kind.price else {
            state.showToast("You need \(kind.price) coins for that.")
            Sound.shared.play("nope")
            return
        }
        if kind.solid && playerStands(on: tile) {
            state.showToast("You are standing there.")
            return
        }
        save.coins -= kind.price
        let item = GardenItem(kind: kind.id, tile: tile)
        save.garden.append(item)
        placeGardenNodes(item, animated: true)
        save.store()
        refreshHUD()
        Sound.shared.play("coin")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Tutorial

    private var tutorialLines: [String] {
        [
            "Drag anywhere on the screen to walk.",
            "Walk up to the customer at your stand and press TALK.",
            "Head east along the lane and through the gate into the tree lot.",
            "Find a fir that fits the wish. Stand beside it and press CHOP. Tap when the marker is on green.",
            "Haul the tree to your customer's home. Follow the arrow, or open the MAP.",
            "You earned coins! Walk to a dark street lantern and press LIGHT.",
            "The fenced garden below your cabin is yours. Step inside and press DECORATE.",
            "That's everything, \(save.playerName)! Sleep at your cabin door or press GO HOME TO BED. The workbench by your cabin sells tools."
        ]
    }

    /// Moves the first-day tutorial along as the player does each thing.
    func updateTutorial() {
        guard save.tutorial < 100 else {
            if !state.tutorialText.isEmpty { state.tutorialText = "" }
            return
        }
        if save.day > 1 {
            skipTutorial()
            return
        }
        var step = save.tutorial
        let later = save.phase == .hauling || save.phase == .evening
        switch step {
        case 0:
            if distance(player.position, world.cabinDoor.cg) > 44 { step = 1 }
        case 1:
            if save.phase != .morning { step = 2 }
        case 2:
            if player.position.x > world.gate.x + 12 || later { step = 3 }
        case 3:
            if later { step = 4 }
        case 4:
            if save.phase == .evening { step = 5 }
        case 5:
            if save.litCount > 0 { step = 6 }
        case 6:
            if building || !save.garden.isEmpty { step = 7 }
        default:
            break
        }
        if step != save.tutorial {
            save.tutorial = step
            save.store()
            Sound.shared.play("heart", volume: 0.5)
        }
        let lines = tutorialLines
        let text = lines[min(max(step, 0), lines.count - 1)]
        let count = "\(min(step, lines.count - 1) + 1)/\(lines.count)"
        if state.tutorialText != text { state.tutorialText = text }
        if state.tutorialCount != count { state.tutorialCount = count }
    }

    func skipTutorial() {
        save.tutorial = 100
        save.store()
        state.tutorialText = ""
    }
}
