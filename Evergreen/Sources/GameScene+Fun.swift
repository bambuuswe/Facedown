import SpriteKit
import UIKit

/// The playful side of the village: the workbench shop, market stalls, animals,
/// fires, the chapel bell, weather and fireworks.
extension GameScene {
    // MARK: - Status line, music and weather

    func tickStatus(_ dt: TimeInterval) {
        statusClock += dt
        guard statusClock >= 0.4 else { return }
        statusClock = 0
        refreshStatus()
        let dusk = min(1, max(0, (night - 0.3) / 0.6))
        Sound.shared.mix(night: dusk, storm: isStormDay)
    }

    func refreshStatus() {
        var buff = ""
        if boostLeft > 0 {
            buff = "QUICK FEET \(clockText(boostLeft))"
        }
        var label = ""
        if state.screen == .playing {
            switch todayEvent {
            case .storm:
                label = "SNOWSTORM · EXTRA PAY"
            case .market:
                label = "MARKET DAY · HALF PRICE"
            case .rush:
                if rushLeft > 0 {
                    label = "RUSH ORDER \(clockText(rushLeft))"
                } else if save.phase == .morning {
                    label = "RUSH ORDER TODAY"
                } else if save.phase == .seeking || save.phase == .hauling {
                    label = "RUSH ORDER · LATE"
                }
            case .none:
                break
            }
        }
        if state.buff != buff { state.buff = buff }
        if state.eventLabel != label { state.eventLabel = label }
    }

    private func clockText(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        let rest = whole % 60
        return "\(whole / 60):" + (rest < 10 ? "0\(rest)" : "\(rest)")
    }

    /// A storm day brings thick, slanting snow; other days it drifts gently.
    func applyWeather() {
        if isStormDay {
            snowfall.particleBirthRate = 170
            snowfall.particleSpeed = 70
            snowfall.particleSpeedRange = 22
            snowfall.particleLifetime = 4
            snowfall.emissionAngle = -CGFloat.pi / 2 - 0.95
        } else {
            snowfall.particleBirthRate = 46
            snowfall.particleSpeed = 20
            snowfall.particleSpeedRange = 8
            snowfall.particleLifetime = 7
            snowfall.emissionAngle = -CGFloat.pi / 2 - 0.3
        }
    }

    func toggleSound() {
        Sound.shared.setEnabled(!Sound.shared.enabled)
        state.soundOn = Sound.shared.enabled
        Sound.shared.play("tap")
    }

    // MARK: - Market stalls

    func price(of kind: String) -> Int {
        let base = kind == "cocoa" ? 3 : (kind == "gift" ? 6 : 2)
        return todayEvent == .market ? (base + 1) / 2 : base
    }

    func buy(_ kind: String) {
        guard chopCooldown <= 0 else { return }
        chopCooldown = 0.5
        let cost = price(of: kind)
        guard save.coins >= cost else {
            state.showToast("You need \(cost) coins for that.")
            Sound.shared.play("nope")
            return
        }
        if kind == "gift" && save.gifts >= 3 {
            state.showToast("Your arms are full of gifts already.")
            return
        }
        if kind == "treat" && save.treats >= 3 {
            state.showToast("Your pockets are full of gingerbread.")
            return
        }
        save.coins -= cost
        if kind == "cocoa" {
            boostLeft = save.thermos ? 240 : 120
            state.showToast("Hot cocoa! Quick feet for \(save.thermos ? 4 : 2) minutes.")
            Sound.shared.play("sip")
        } else if kind == "gift" {
            save.gifts += 1
            state.showToast("A wrapped gift. Give it to someone in the village.")
            Sound.shared.play("coin")
        } else {
            save.treats += 1
            state.showToast("Gingerbread. The deer in the forest love it.")
            Sound.shared.play("coin")
        }
        save.store()
        refreshHUD()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Workbench shop

    private func shopItems() -> [ShopItem] {
        func tool(_ id: String, _ title: String, _ detail: String, _ price: Int, _ owned: Bool) -> ShopItem {
            ShopItem(id: id, title: title, detail: detail, price: price, status: owned ? 1 : 0)
        }
        func outfit(_ index: Int, _ title: String, _ detail: String, _ price: Int) -> ShopItem {
            let owned = index < save.outfits.count && save.outfits[index]
            return ShopItem(id: "outfit\(index)", title: title, detail: detail, price: price, status: owned ? (save.outfit == index ? 3 : 2) : 0)
        }
        return [
            tool("guide", "Tree guide", "Shows each fir's traits when you stand beside it.", 10, save.guide),
            tool("axe", "Sharp axe", "Every swing bites deeper, so trees fall sooner.", 14, save.axe),
            tool("sled", "Waxed runners", "A loaded sled glides as fast as you walk.", 14, save.sledWax),
            tool("boots", "Snow boots", "You walk faster, always.", 18, save.boots),
            tool("thermos", "Big thermos", "Cocoa keeps you quick for twice as long.", 10, save.thermos),
            outfit(0, "Green coat", "Your trusty farm coat.", 0),
            outfit(1, "Santa suit", "Red, white and very festive.", 12),
            outfit(2, "Blue parka", "With warm ear flaps.", 8)
        ]
    }

    func openShop() {
        resetStick()
        state.shop = shopItems()
        state.shopOpen = true
        Sound.shared.play("tap")
    }

    func closeShop() {
        state.shopOpen = false
        Sound.shared.play("tap")
    }

    func buyItem(_ id: String) {
        guard let item = shopItems().first(where: { $0.id == id }) else { return }
        if item.status == 1 || item.status == 3 { return }
        if item.status == 0 {
            guard save.coins >= item.price else {
                Sound.shared.play("nope")
                return
            }
            save.coins -= item.price
            Sound.shared.play("coin")
        } else {
            Sound.shared.play("tap")
        }
        switch id {
        case "guide": save.guide = true
        case "axe": save.axe = true
        case "sled": save.sledWax = true
        case "boots": save.boots = true
        case "thermos": save.thermos = true
        case "outfit0": save.outfit = 0
        case "outfit1":
            save.outfits[1] = true
            save.outfit = 1
        case "outfit2":
            save.outfits[2] = true
            save.outfit = 2
        default: break
        }
        save.store()
        refreshHUD()
        state.shop = shopItems()
    }

    // MARK: - Animals and neighbours

    private func hearts(at point: CGPoint) {
        burst("icon_heart", at: CGPoint(x: point.x, y: point.y + 12), count: 3, spread: 7, rise: 16, additive: false)
    }

    func pet(_ kind: String) {
        guard chopCooldown <= 0 else { return }
        chopCooldown = 0.6
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if kind == "cat" {
            guard let cat = catNode else { return }
            hearts(at: cat.position)
            Sound.shared.play("meow", volume: 0.6)
            catFollow = 45
            if !save.catFriend {
                save.catFriend = true
                save.hearts += 1
                save.store()
                refreshHUD()
                Sound.shared.play("heart")
                state.showToast("The cat has decided it likes you.  +1 heart")
            } else {
                state.showToast("Purr. It trots after you.")
            }
            return
        }
        var nearest: Critter?
        var nearestGap: CGFloat = 24
        for critter in critters where critter.kind == "sheep" {
            let gap = distance(critter.node.position, player.position)
            if gap < nearestGap {
                nearestGap = gap
                nearest = critter
            }
        }
        guard let sheep = nearest else { return }
        hearts(at: sheep.node.position)
        Sound.shared.play("baa", volume: 0.6)
        sheep.direction = .zero
        sheep.think = 2
        sheep.node.run(SKAction.sequence([SKAction.moveBy(x: 0, y: 3, duration: 0.1), SKAction.moveBy(x: 0, y: -3, duration: 0.12)]))
        if !save.sheepFriend {
            save.sheepFriend = true
            save.hearts += 1
            save.store()
            refreshHUD()
            Sound.shared.play("heart")
            state.showToast("The sheep lean in for more.  +1 heart")
        }
    }

    func feedDeer() {
        guard chopCooldown <= 0, save.treats > 0 else { return }
        chopCooldown = 0.6
        var nearest: Critter?
        var nearestGap: CGFloat = 30
        for critter in critters where critter.kind == "deer" {
            let gap = distance(critter.node.position, player.position)
            if gap < nearestGap {
                nearestGap = gap
                nearest = critter
            }
        }
        guard let deer = nearest else { return }
        save.treats -= 1
        hearts(at: deer.node.position)
        Sound.shared.play("munch", volume: 0.7)
        deer.direction = .zero
        deer.think = 4
        if !save.deerFriend {
            save.deerFriend = true
            save.hearts += 1
            Sound.shared.play("heart")
            state.showToast("The deer eats from your hand.  +1 heart")
        } else {
            state.showToast("Crunch. The deer is delighted.")
        }
        save.store()
        refreshHUD()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func giveGift(to index: Int) {
        guard save.gifts > 0, index >= 0, index < save.gifted.count, !save.gifted[index] else { return }
        let house = world.houses[index]
        save.gifts -= 1
        save.gifted[index] = true
        save.hearts += 1
        save.store()
        refreshHUD()
        hearts(at: player.position)
        Sound.shared.play("heart")
        let lines = [
            "For me? Oh, you shouldn't have! I'll put it under the tree.",
            "A present! Nobody has given me one in years. Thank you.",
            "Well, now I have to get you something too. How kind."
        ]
        showDialog(Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: "\(lines.randomElement() ?? "Thank you!")\n\n+1 heart", button: "You're welcome"))
    }

    // MARK: - Fires and the bell

    func warmUp() {
        guard chopCooldown <= 0 else { return }
        chopCooldown = 1
        boostLeft = max(boostLeft, 60)
        Sound.shared.play("fire", volume: 0.8)
        refreshStatus()
        state.showToast("You warm your hands by the fire. Quick feet for a minute.")
    }

    func ringBell() {
        bellCooldown = 8
        Sound.shared.play("bell", volume: 0.8)
        scatterBirds()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        state.showToast("The bell rings out over the village.")
    }

    // MARK: - Fireworks after the great tree is lit

    func updateFireworks(_ dt: TimeInterval) {
        guard state.screen == .playing, save.phase == .epilogue, night > 0.8 else { return }
        fireworkClock -= dt
        guard fireworkClock <= 0 else { return }
        fireworkClock = TimeInterval.random(in: 1.2...3.2)
        let centre = CGPoint(x: world.square.x + CGFloat.random(in: -90...90), y: world.square.y + CGFloat.random(in: 90...170))
        let colours: [SKColor] = [
            SKColor(red: 1, green: 0.42, blue: 0.36, alpha: 1),
            SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1),
            SKColor(red: 0.4, green: 0.75, blue: 1, alpha: 1),
            SKColor(red: 0.55, green: 1, blue: 0.6, alpha: 1),
            SKColor(red: 1, green: 0.6, blue: 0.9, alpha: 1)
        ]
        let colour = colours.randomElement() ?? SKColor.white
        let sparks = 16
        for index in 0..<sparks {
            let angle = CGFloat(index) / CGFloat(sparks) * 2 * CGFloat.pi
            let reach = CGFloat.random(in: 18...36)
            let node = SKSpriteNode(texture: texture("dot"), size: CGSize(width: 2, height: 2))
            node.color = colour
            node.colorBlendFactor = 1
            node.blendMode = .add
            node.position = centre
            node.zPosition = 3350
            worldNode.addChild(node)
            let fly = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach - 8, duration: 0.9)
            fly.timingMode = .easeOut
            let fade = SKAction.sequence([SKAction.wait(forDuration: 0.45), SKAction.fadeOut(withDuration: 0.45)])
            node.run(SKAction.sequence([SKAction.group([fly, fade]), SKAction.removeFromParent()]))
        }
        if distance(cam.position, world.square.cg) < 260 {
            Sound.shared.play("firework", volume: 0.5)
        }
    }
}
