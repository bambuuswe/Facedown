import SpriteKit
import UIKit

/// What the action button would do right now.
enum Action: Equatable {
    case talk
    case chop(Int)      // lot index, or -1 for the great fir
    case deliver
    case light(Int)
    case sleep
    case lightTree
    case chat(Int)      // house index
}

/// The rules: customers, wishes, chopping, deliveries, lights and the finale.
extension GameScene {
    private var isLastDay: Bool { save.day == SaveData.lastDay }

    private var todayHouse: Int {
        save.houseOrder[min(max(save.day, 1), world.houses.count) - 1]
    }

    private var todayWish: Wish {
        save.wishes[min(max(save.day, 1), world.houses.count) - 1]
    }

    // MARK: - Menu commands

    func startNewGame() {
        save = SaveData.newGame(world: world)
        save.store()
        state.hasSave = true
        state.ending = nil
        rebuildDynamic()
        state.mapOpen = false
        state.screen = .playing
        snapNight()
        refreshHUD()
        showDialog(Dialog(
            speaker: "Evergreen Farm",
            portrait: "player_down_0",
            text: "Twelve days until Christmas Eve, and the village below is dark and snowed in.\n\nSell your firs by day. Spend what you earn on lights by night.",
            button: "Let's begin"))
    }

    func continueGame() {
        state.screen = .playing
        snapNight()
        refreshHUD()
    }

    func showTitle() {
        resetStick()
        state.mapOpen = false
        state.screen = .title
        snapNight()
    }

    // MARK: - Map screen

    func openMap() {
        guard state.screen == .playing, state.dialog == nil, !busy else { return }
        resetStick()
        func spot(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / world.width, y: 1 - point.y / world.height)
        }
        var info = MapInfo()
        info.player = spot(player.position)
        switch save.phase {
        case .morning:
            info.target = spot(world.customer.cg)
        case .seeking:
            info.target = spot(isLastDay ? world.giant.cg : world.gate.cg)
        case .hauling:
            info.target = spot(isLastDay ? world.square.cg : world.houses[todayHouse].door)
        case .evening:
            info.target = spot(isLastDay && !save.squareLit ? world.square.cg : world.cabinDoor.cg)
        case .epilogue:
            info.target = nil
        }
        for (index, light) in world.lights.enumerated() {
            guard let point = light.points.first else { continue }
            let place = spot(point.cg)
            info.dots.append(MapDot(id: index, x: place.x, y: place.y, lit: save.lit[index]))
        }
        state.mapInfo = info
        state.mapOpen = true
    }

    func closeMap() {
        state.mapOpen = false
    }

    // MARK: - Building from the save

    func buildFromSave() {
        for index in world.lot.indices {
            lotNodes.append(makeLotNode(index))
        }
        if save.giantChopped {
            addStanding("stump", x: world.giant.x, y: world.giant.y - 2, to: dynamicNode)
        } else {
            giantNode = addStanding("giant", x: world.giant.x, y: world.giant.y - 2, to: dynamicNode)
        }
        if save.squarePlanted {
            placeSquareTree(animated: false)
        }
        for house in world.houses.indices where save.houseTrees[house] != nil {
            addHouseDecor(house, animated: false)
        }
        for index in world.lights.indices where save.lit[index] {
            addLightNodes(index, animated: false)
        }
        if save.phase == .hauling {
            spawnSled()
        }
        updatePhaseNodes()
    }

    private func makeLotNode(_ index: Int) -> SKSpriteNode {
        let slot = world.lot[index]
        let tree = save.lot[index]
        return addStanding(tree.chopped ? "stump" : tree.traits.spriteName, x: slot.x, y: slot.y - 2, to: dynamicNode)
    }

    private func addMarker(_ name: String, at point: CGPoint) -> SKSpriteNode {
        let tex = texture(name)
        let node = SKSpriteNode(texture: tex, size: tex.size())
        node.position = point
        node.zPosition = 3000
        node.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.45),
            SKAction.moveBy(x: 0, y: -2, duration: 0.45)
        ])))
        dynamicNode.addChild(node)
        return node
    }

    /// Customer, pointers and villagers all depend on the time of day.
    func updatePhaseNodes() {
        customerNode?.removeFromParent()
        customerNode = nil
        markerNode?.removeFromParent()
        markerNode = nil
        arrowTarget = nil

        switch save.phase {
        case .morning:
            let name = isLastDay ? "mayor_down_0" : world.houses[todayHouse].villager + "_down_0"
            customerNode = addStanding(name, x: world.customer.x, y: world.customer.y, to: dynamicNode)
            markerNode = addMarker("marker_tree", at: CGPoint(x: world.customer.x, y: world.customer.y + 32))
            arrowTarget = world.customer.cg
        case .seeking:
            arrowTarget = isLastDay ? world.giant.cg : world.gate.cg
        case .hauling:
            if isLastDay {
                markerNode = addMarker("marker_star", at: CGPoint(x: world.square.x, y: world.square.y + 26))
                arrowTarget = world.square.cg
            } else {
                let house = world.houses[todayHouse]
                markerNode = addMarker("marker_home", at: CGPoint(x: house.x, y: house.y + 88))
                arrowTarget = house.door
            }
        case .evening:
            if isLastDay && save.squarePlanted && !save.squareLit {
                markerNode = addMarker("marker_star", at: CGPoint(x: world.square.x, y: world.square.y + 98))
                arrowTarget = world.square.cg
            }
        case .epilogue:
            break
        }

        let outdoors = save.phase == .evening || save.phase == .epilogue
        for entry in villagerNodes {
            entry.node.isHidden = !outdoors
        }
        if outdoors {
            sendWalkersHome()
        }
    }

    /// A delivered house: decorated tree in the yard, lit windows, and its owner outside.
    private func addHouseDecor(_ index: Int, animated: Bool) {
        guard let traits = save.houseTrees[index] else { return }
        let house = world.houses[index]
        let tree = addStanding(traits.spriteName, x: house.treeX, y: house.treeY, to: dynamicNode)
        let lights = addEmissive(traits.spriteName + "_lit", x: house.treeX, y: house.treeY, dusk: false)
        addGlow(WorldGlow(x: house.treeX, y: house.treeY + 18, r: 30, c: [1, 0.86, 0.6]), strength: 0.6)
        addEmissive(house.lit, x: house.x, y: house.y, dusk: true)
        for glow in house.glows {
            addGlow(glow)
        }
        let villager = addStanding(house.villager + "_down_0", x: house.doorX + 13, y: house.doorY + 1, to: dynamicNode)
        addSmoke(house.smoke.cg)
        villager.isHidden = !(save.phase == .evening || save.phase == .epilogue)
        villagerNodes.append((index, villager))

        if animated {
            tree.alpha = 0
            lights.alpha = 0
            tree.run(SKAction.fadeIn(withDuration: 0.5))
            lights.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.fadeIn(withDuration: 0.6)]))
            burst("sparkle", at: CGPoint(x: house.treeX, y: house.treeY + 20), count: 8, spread: 12, rise: 14, additive: true)
        }
        applyNight(force: true)
    }

    private func addLightNodes(_ index: Int, animated: Bool) {
        let light = world.lights[index]
        let lamp = light.kind == "lantern" || light.kind == "snowman" || light.kind == "pond"
        for part in light.parts where !part.lit.isEmpty {
            let node = addEmissive(part.lit, x: part.x, y: part.y, dusk: lamp)
            if part.lit.hasSuffix("_lit_0") {
                // fires flicker between two flame shapes
                let other = String(part.lit.dropLast(1)) + "1"
                node.run(SKAction.repeatForever(SKAction.animate(with: [texture(part.lit), texture(other)], timePerFrame: 0.17)))
            }
        }
        for glow in light.glows {
            addGlow(glow)
            if animated {
                burst("sparkle", at: CGPoint(x: glow.x, y: glow.y), count: 3, spread: 8, rise: 10, additive: true)
            }
        }
        applyNight(force: true)
    }

    private func placeSquareTree(animated: Bool) {
        let tree = addStanding("giant", x: world.square.x, y: world.square.y, to: dynamicNode)
        if animated {
            tree.alpha = 0
            tree.run(SKAction.fadeIn(withDuration: 0.8))
        }
        if save.squareLit {
            placeSquareLights(animated: false)
        }
    }

    private func placeSquareLights(animated: Bool) {
        let layers = ["giant_lit1", "giant_lit2", "giant_lit3"].prefix(max(1, min(3, save.finaleTier)))
        for (step, name) in layers.enumerated() {
            let node = addEmissive(name, x: world.square.x, y: world.square.y, dusk: false)
            if animated {
                node.alpha = 0
                node.run(SKAction.sequence([SKAction.wait(forDuration: 0.3 + Double(step) * 0.9), SKAction.fadeIn(withDuration: 0.7)]))
            }
        }
        addGlow(WorldGlow(x: world.square.x, y: world.square.y + 40, r: 70, c: [1, 0.85, 0.55]), strength: 0.8)
        if save.finaleTier >= 2 {
            addGlow(WorldGlow(x: world.square.x, y: world.square.y + 44, r: 115, c: [1, 0.8, 0.5]), strength: 0.35)
        }
        applyNight(force: true)
    }

    private func spawnSled() {
        sledNode?.removeFromParent()
        sledNode = nil
        let treeName: String
        if save.carryingGiant {
            treeName = "giant"
        } else if let carried = save.carried {
            treeName = carried.spriteName
        } else {
            return
        }
        let node = SKNode()
        let sledTexture = texture("sled")
        let sled = SKSpriteNode(texture: sledTexture, size: sledTexture.size())
        sled.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        registerTint(sled)
        let treeTexture = texture(treeName)
        let tree = SKSpriteNode(texture: treeTexture, size: treeTexture.size())
        tree.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        tree.zRotation = CGFloat.pi / 2
        tree.position = CGPoint(x: 7, y: 5)
        tree.zPosition = 0.1
        registerTint(tree)
        node.addChild(sled)
        node.addChild(tree)
        node.position = CGPoint(x: player.position.x - 17, y: player.position.y)
        dynamicNode.addChild(node)
        sledNode = node
        applyNight(force: true)
    }

    // MARK: - Heads-up display

    func refreshHUD() {
        state.dateLabel = "DEC \(12 + save.day)"
        state.coins = save.coins
        state.hearts = save.hearts
        state.litCount = save.litCount
        state.lightTotal = world.lights.count

        let house = world.houses[todayHouse]
        var wish = ""
        let objective: String
        switch save.phase {
        case .morning:
            objective = isLastDay ? "The mayor is waiting at your stand." : "A customer is waiting at your stand."
        case .seeking:
            objective = isLastDay ? "Fell the great fir beside the lane." : "Pick a tree in the lot and chop it."
            wish = isLastDay ? "The great fir, for the square" : "\(house.name) wants: \(todayWish.label)"
        case .hauling:
            objective = isLastDay ? "Haul the great fir to the village square." : "Haul it to \(house.name): \(house.hint)."
            wish = isLastDay ? "" : "\(house.name) wants: \(todayWish.label)"
        case .evening:
            if isLastDay && !save.squareLit {
                objective = "Light the great tree when you are ready."
            } else {
                objective = "Light up the village, then sleep at your cabin."
            }
        case .epilogue:
            objective = "Merry Christmas! Wander as long as you like."
        }
        state.objective = objective
        state.wishLabel = wish
    }

    // MARK: - Finding what the player can do here

    func updateInteraction() {
        let here = player.position
        var best: Action?
        var bestScore: CGFloat = 1
        func offer(_ action: Action, _ point: CGPoint, _ reach: CGFloat) {
            let score = distance(here, point) / reach
            if score < bestScore {
                bestScore = score
                best = action
            }
        }

        // Tree tag: read the traits of the fir you are standing next to.
        var tag = ""
        var tagDistance: CGFloat = 27
        for (index, slot) in world.lot.enumerated() where !save.lot[index].chopped {
            let d = distance(here, slot.cg)
            if d < tagDistance {
                tagDistance = d
                tag = save.lot[index].traits.label
            }
        }
        if !save.giantChopped && distance(here, world.giant.cg) < 32 {
            tag = isLastDay ? "The great fir" : "The great fir · promised to the square"
        }

        switch save.phase {
        case .morning:
            offer(.talk, world.customer.cg, 26)
        case .seeking:
            if isLastDay {
                offer(.chop(-1), world.giant.cg, 32)
            } else {
                for (index, slot) in world.lot.enumerated() where !save.lot[index].chopped {
                    offer(.chop(index), slot.cg, 27)
                }
                arrowTarget = here.x > world.gate.x ? nil : world.gate.cg
            }
        case .hauling:
            if isLastDay {
                offer(.deliver, world.square.cg, 42)
            } else {
                offer(.deliver, world.houses[todayHouse].door, 18)
            }
        case .evening:
            if isLastDay {
                if save.squarePlanted && !save.squareLit { offer(.lightTree, world.square.cg, 42) }
            } else {
                offer(.sleep, world.cabinDoor.cg, 14)
            }
        case .epilogue:
            break
        }
        for (index, light) in world.lights.enumerated() where !save.lit[index] {
            for point in light.points {
                offer(.light(index), point.cg, 22)
            }
        }
        if save.phase == .evening || save.phase == .epilogue {
            for entry in villagerNodes {
                offer(.chat(entry.house), entry.node.position, 15)
            }
        }
        for walker in walkers where walker.house >= 0 {
            offer(.chat(walker.house), walker.node.position, 17)
        }

        if best != currentAction {
            currentAction = best
        }
        publishAction()
        if state.treeTag != tag { state.treeTag = tag }
    }

    func clearAction() {
        if currentAction != nil { currentAction = nil }
        publishAction()
        if !state.treeTag.isEmpty { state.treeTag = "" }
    }

    private func publishAction() {
        var title = ""
        var cost = 0
        var enabled = true
        if let action = currentAction {
            switch action {
            case .talk: title = "Talk"
            case .chop: title = "Chop"
            case .deliver: title = "Deliver"
            case .sleep: title = "Sleep"
            case .lightTree: title = "Light it"
            case .chat: title = "Chat"
            case .light(let index):
                title = "Light"
                cost = world.lights[index].cost
                enabled = save.coins >= cost
            }
        }
        if state.actionTitle != title { state.actionTitle = title }
        if state.actionCost != cost { state.actionCost = cost }
        if state.actionEnabled != enabled { state.actionEnabled = enabled }
    }

    // MARK: - Doing it

    func performAction() {
        guard state.screen == .playing, state.dialog == nil, state.curtain == nil, !state.mapOpen, !busy, let action = currentAction else { return }
        switch action {
        case .talk: talk()
        case .chop(let index): chop(index)
        case .deliver: deliver()
        case .light(let index): lightUp(index)
        case .sleep: goToSleep()
        case .lightTree: lightGreatTree()
        case .chat(let house): chat(house)
        }
    }

    func showDialog(_ dialog: Dialog, then: (() -> Void)? = nil) {
        resetStick()
        afterDialog = then
        state.dialog = dialog
    }

    func dismissDialog() {
        state.dialog = nil
        let next = afterDialog
        afterDialog = nil
        next?()
    }

    private func talk() {
        let dialog: Dialog
        if isLastDay {
            dialog = Dialog(
                speaker: "Mayor Birgit",
                portrait: "mayor_down_0",
                text: "It's Christmas Eve! The village needs its great tree.\n\nBring the big fir from beside your lane down to the square, would you?",
                button: "With pleasure")
        } else {
            let house = world.houses[todayHouse]
            dialog = Dialog(
                speaker: house.name,
                portrait: house.villager + "_down_0",
                text: "Good morning! \(todayWish.sentence)\n\nI live in \(house.hint).",
                button: "I'll find one")
        }
        showDialog(dialog) { [weak self] in
            guard let self = self else { return }
            self.save.phase = .seeking
            self.save.store()
            if let customer = self.customerNode {
                self.customerNode = nil
                customer.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))
            }
            self.updatePhaseNodes()
            self.refreshHUD()
        }
    }

    private func chop(_ index: Int) {
        guard chopCooldown <= 0 else { return }
        chopCooldown = 0.3
        let giant = index < 0
        let found: SKSpriteNode? = giant ? giantNode : (index < lotNodes.count ? lotNodes[index] : nil)
        guard let tree = found else { return }

        let good = abs(chopSwing - 0.5) < 0.14
        let needed = giant ? 9 : 3 + save.lot[index].traits.height
        chopDamage[index, default: 0] += good ? 2 : 1
        if !good { chopSloppy.insert(index) }

        // The tree shudders, snow falls off it, and you lean into the swing.
        tree.removeAction(forKey: "shake")
        tree.run(SKAction.sequence([
            SKAction.moveBy(x: 1.5, y: 0, duration: 0.04),
            SKAction.moveBy(x: -3, y: 0, duration: 0.07),
            SKAction.moveBy(x: 1.5, y: 0, duration: 0.04)
        ]), withKey: "shake")
        burst("dot", at: CGPoint(x: tree.position.x, y: tree.position.y + tree.size.height * 0.6), count: good ? 7 : 4, spread: tree.size.width * 0.3, rise: -16, additive: false)
        if good {
            burst("sparkle", at: CGPoint(x: tree.position.x, y: tree.position.y + 6), count: 2, spread: 5, rise: 8, additive: true)
        }
        let lean: CGFloat = player.position.x < tree.position.x ? 2 : -2
        player.run(SKAction.sequence([SKAction.moveBy(x: lean, y: 0, duration: 0.05), SKAction.moveBy(x: -lean, y: 0, duration: 0.09)]))
        UIImpactFeedbackGenerator(style: good ? .heavy : .light).impactOccurred()

        if chopDamage[index, default: 0] >= needed {
            fell(index, tree: tree)
        }
    }

    private func fell(_ index: Int, tree: SKSpriteNode) {
        busy = true
        let giant = index < 0
        let clean = !chopSloppy.contains(index)
        if giant {
            save.giantChopped = true
            save.carryingGiant = true
            giantNode = nil
        } else {
            save.lot[index].chopped = true
            save.carried = save.lot[index].traits
        }
        save.phase = .hauling
        if clean { save.coins += 2 }
        save.store()

        let angle: CGFloat = player.position.x < tree.position.x ? -CGFloat.pi / 2 : CGFloat.pi / 2
        let topple = SKAction.rotate(byAngle: angle, duration: 0.55)
        topple.timingMode = .easeIn
        tree.run(SKAction.sequence([topple, SKAction.fadeOut(withDuration: 0.25), SKAction.removeFromParent()]))
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let base = tree.position
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.85),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let stump = self.addStanding("stump", x: base.x, y: base.y, to: self.dynamicNode)
                if !giant && index < self.lotNodes.count { self.lotNodes[index] = stump }
                self.burst("dot", at: CGPoint(x: base.x, y: base.y + 4), count: 8, spread: 10, rise: 8, additive: false)
                self.spawnSled()
                self.updatePhaseNodes()
                self.refreshHUD()
                self.busy = false
                self.state.showToast(clean ? "Clean cut!  +2 coins" : "Timber!")
            }
        ]))
    }

    private func deliver() {
        if isLastDay {
            plantGreatTree()
            return
        }
        guard let tree = save.carried else { return }
        let index = todayHouse
        let house = world.houses[index]
        let wish = todayWish
        let hits = wish.matches(tree)
        let perfect = hits == wish.count
        let pay = 8 + 5 * hits + (perfect ? 5 : 0)

        save.coins += pay
        if perfect { save.hearts += 1 }
        save.houseTrees[index] = tree
        save.carried = nil
        save.phase = .evening
        save.store()

        sledNode?.removeFromParent()
        sledNode = nil
        addHouseDecor(index, animated: true)
        updatePhaseNodes()
        refreshHUD()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let line: String
        if perfect {
            line = "Oh, it's perfect! Exactly the tree I was dreaming of."
        } else if hits + 1 >= wish.count {
            line = "It's lovely. Not quite what I pictured, but it has charm."
        } else {
            line = "Hm. Well, a tree is a tree. Thank you for bringing it."
        }
        let reward = perfect ? "+\(pay) coins  ·  +1 heart" : "+\(pay) coins"
        showDialog(Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: "\(line)\n\n\(reward)", button: "Merry Christmas"))
    }

    private func plantGreatTree() {
        save.carryingGiant = false
        save.squarePlanted = true
        save.coins += 20
        save.phase = .evening
        save.store()
        sledNode?.removeFromParent()
        sledNode = nil
        placeSquareTree(animated: true)
        updatePhaseNodes()
        refreshHUD()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showDialog(Dialog(
            speaker: "Mayor Birgit",
            portrait: "mayor_down_0",
            text: "Magnificent! Here, for your trouble: 20 coins.\n\nBuy any last lights you like, then do us the honour and light the tree.",
            button: "I will"))
    }

    private func lightUp(_ index: Int) {
        let light = world.lights[index]
        guard save.coins >= light.cost else {
            state.showToast("You need \(light.cost) coins for that.")
            return
        }
        save.coins -= light.cost
        save.lit[index] = true
        save.store()
        addLightNodes(index, animated: true)
        refreshHUD()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        state.showToast("Lit: \(light.label)")
    }

    private func goToSleep() {
        busy = true
        let next = save.day + 1
        state.curtain = "December \(12 + next)"
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.3),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.save.day = next
                self.save.phase = .morning
                self.save.store()
                self.night = 0
                self.rebuildDynamic()
                self.refreshHUD()
            },
            SKAction.wait(forDuration: 1.1),
            SKAction.run { [weak self] in
                self?.state.curtain = nil
                self?.busy = false
            }
        ]))
    }

    private func lightGreatTree() {
        busy = true
        let total = world.lights.count
        let lit = save.litCount
        let fraction = CGFloat(lit) / CGFloat(max(total, 1))
        let tier = fraction >= 0.9 ? 3 : (fraction >= 0.55 ? 2 : 1)
        save.squareLit = true
        save.finaleTier = tier
        save.phase = .epilogue
        save.store()

        markerNode?.removeFromParent()
        markerNode = nil
        arrowTarget = nil
        placeSquareLights(animated: true)
        for entry in villagerNodes { entry.node.isHidden = false }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let centre = CGPoint(x: world.square.x, y: world.square.y + 44)
        var steps: [SKAction] = []
        for _ in 0..<(2 + tier * 2) {
            steps.append(SKAction.run { [weak self] in
                self?.burst("sparkle", at: centre, count: 6, spread: 26, rise: 22, additive: true)
            })
            steps.append(SKAction.wait(forDuration: 0.45))
        }
        steps.append(SKAction.wait(forDuration: 0.8))
        steps.append(SKAction.run { [weak self] in
            guard let self = self else { return }
            self.refreshHUD()
            self.busy = false
            self.state.ending = Ending(tier: tier, lit: lit, total: total, hearts: self.save.hearts)
        })
        run(SKAction.sequence(steps))
    }

    private func chat(_ index: Int) {
        let house = world.houses[index]
        let lines: [String]
        if save.phase == .evening || save.phase == .epilogue {
            lines = [
                "The tree looks wonderful. Thank you again!",
                "Have you seen the lanterns? The village feels warmer already.",
                "My little ones can't stop staring at the star on top.",
                "It finally feels like Christmas around here.",
                "Mind the ice by the pond. And merry Christmas!"
            ]
        } else if save.houseTrees[index] != nil {
            lines = [
                "Our tree is the talk of the street. Thank you!",
                "The children are skating on the lake again. Have you been?",
                "Try the cocoa at the market. It's worth the walk.",
                "I saw deer up in the old forest this morning."
            ]
        } else {
            lines = [
                "Lovely morning for it. I'll be by for a tree one of these days.",
                "The village is so dark this year. A few lanterns would do wonders.",
                "Have you seen the sheep at the barn? Fat and woolly as ever.",
                "They say there's a campfire spot up the forest trail.",
                "Mind the geese. Oh wait, wrong village."
            ]
        }
        showDialog(Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: lines.randomElement() ?? "Merry Christmas!", button: "See you"))
    }
}
