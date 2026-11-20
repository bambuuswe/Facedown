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
    case give(Int)      // house index
    case pet(String)    // "cat" or "sheep"
    case feed
    case buy(String)    // "cocoa", "gift" or "treat"
    case workshop
    case warm(Int)      // light index of a burning fire
    case bell
    case build
}

/// The working day: customers, wishes, chopping, deliveries, lights and the finale.
/// The playful extras live in GameScene+Fun.swift.
extension GameScene {
    var isLastDay: Bool { save.day == SaveData.lastDay }

    var todayHouse: Int {
        save.houseOrder[min(max(save.day, 1), world.houses.count) - 1]
    }

    var todayWish: Wish {
        save.wishes[min(max(save.day, 1), world.houses.count) - 1]
    }

    var todayEvent: DayEvent {
        save.phase == .epilogue ? .none : SaveData.event(for: save.day)
    }

    // MARK: - Menu commands

    func startNewGame(name: String, farm: String, look: Int) {
        save = SaveData.newGame(world: world)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFarm = farm.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty { save.playerName = String(cleanName.prefix(12)) }
        if !cleanFarm.isEmpty { save.farmName = String(cleanFarm.prefix(18)) }
        save.look = min(3, max(0, look))
        save.store()
        building = false
        state.buildOpen = false
        state.hasSave = true
        state.ending = nil
        boostLeft = 0
        rushLeft = 0
        rebuildDynamic()
        state.mapOpen = false
        state.shopOpen = false
        state.screen = .playing
        snapNight()
        refreshHUD()
        showDialog(Dialog(
            speaker: "Evergreen Farm",
            portrait: "\(playerBase)_down_0",
            text: "Welcome to \(save.farmName), \(save.playerName).\n\nTwelve days until Christmas Eve, and the village below is dark and snowed in. Sell your firs by day. Spend what you earn on lights by night.",
            button: "Let's begin"))
    }

    func continueGame() {
        state.screen = .playing
        snapNight()
        applyWeather()
        refreshHUD()
        Sound.shared.play("tap")
    }

    func showTitle() {
        resetStick()
        building = false
        buildGrid.isHidden = true
        state.buildOpen = false
        state.mapOpen = false
        state.shopOpen = false
        state.screen = .title
        snapNight()
        applyWeather()
    }

    // MARK: - Map screen

    func openMap() {
        guard state.screen == .playing, state.dialog == nil, !busy else { return }
        resetStick()
        Sound.shared.play("tap")
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
        Sound.shared.play("tap")
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
            markerNode = addMarker("marker_tree", at: CGPoint(x: world.customer.x, y: world.customer.y + 40))
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

    /// A delivered house: decorated tree in the yard, lit windows, smoke, and its owner outside.
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
        state.saveSummary = "\(save.farmName) · Dec \(12 + save.day)"
        state.coins = save.coins
        state.hearts = save.hearts
        state.litCount = save.litCount
        state.lightTotal = world.lights.count
        state.gifts = save.gifts
        state.treats = save.treats
        state.canGoHome = save.phase == .evening && !isLastDay

        let house = world.houses[todayHouse]
        let riddle = SaveData.speaksInRiddles(on: save.day)
        var wish = ""
        let objective: String
        switch save.phase {
        case .morning:
            objective = isLastDay ? "The mayor is waiting at your stand." : "A customer is waiting at your stand."
        case .seeking:
            if isLastDay {
                objective = "Fell the great fir beside the lane."
                wish = "The great fir, for the square"
            } else if riddle {
                objective = "\"\(todayWish.riddle)\""
                wish = "\(house.name) spoke in riddles"
            } else {
                objective = save.guide ? "Pick a tree in the lot and chop it." : "Pick a tree by eye and chop it. (A tree guide would help.)"
                wish = "\(house.name) wants: \(todayWish.label)"
            }
        case .hauling:
            objective = isLastDay ? "Haul the great fir to the village square." : "Haul it to \(house.name): \(house.hint)."
        case .evening:
            if isLastDay && !save.squareLit {
                objective = "Light the great tree when you are ready."
            } else {
                objective = "Light up the village and enjoy the evening. Sleep when you like."
            }
        case .epilogue:
            objective = "Merry Christmas! Wander as long as you like."
        }
        state.objective = objective
        state.wishLabel = wish
        refreshStatus()
    }

    /// Says what today's special is, if anything.
    func announceDay() {
        switch todayEvent {
        case .storm: state.showToast("A snowstorm! Deliveries pay extra today.")
        case .market: state.showToast("Market day! The stalls are half price.")
        case .rush: state.showToast("A rush order is waiting at your stand.")
        case .none: break
        }
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

        // The tree guide lets you read a fir's traits; without it you judge by eye.
        var tag = ""
        if save.guide {
            var tagDistance: CGFloat = 27
            for (index, slot) in world.lot.enumerated() where !save.lot[index].chopped {
                let d = distance(here, slot.cg)
                if d < tagDistance {
                    tagDistance = d
                    tag = save.lot[index].traits.label
                }
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

        for (index, light) in world.lights.enumerated() {
            if !save.lit[index] {
                for point in light.points {
                    offer(.light(index), point.cg, 22)
                }
            } else if light.kind == "campfire" || light.kind == "brazier", let point = light.points.first {
                offer(.warm(index), point.cg, 22)
            }
        }

        // People: a gift comes before small talk.
        let outdoors = save.phase == .evening || save.phase == .epilogue
        if save.gifts > 0 {
            if outdoors {
                for entry in villagerNodes where !save.gifted[entry.house] {
                    offer(.give(entry.house), entry.node.position, 15)
                }
            }
            for walker in walkers where walker.house >= 0 && !save.gifted[walker.house] {
                offer(.give(walker.house), walker.node.position, 17)
            }
        }
        if outdoors {
            for entry in villagerNodes {
                offer(.chat(entry.house), entry.node.position, 15)
            }
        }
        for walker in walkers where walker.house >= 0 {
            offer(.chat(walker.house), walker.node.position, 17)
        }

        // Places and animals.
        offer(.workshop, world.workshop.cg, 16)
        offer(.build, world.gardenGate.cg, 16)
        if insideGarden(here) {
            offer(.build, here, 4)
        }
        for stall in world.stalls {
            offer(.buy(stall.kind), stall.cg, 15)
        }
        if bellCooldown <= 0 {
            offer(.bell, world.chapelDoor.cg, 14)
        }
        if let cat = catNode {
            offer(.pet("cat"), cat.position, 16)
        }
        for critter in critters {
            if critter.kind == "sheep" {
                offer(.pet("sheep"), critter.node.position, 15)
            } else if save.treats > 0 {
                offer(.feed, critter.node.position, 22)
            }
        }

        if best != currentAction {
            currentAction = best
            if let chosen = best, case .chop = chosen { chopZone = 0.5 }
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
            case .give: title = "Give gift"
            case .pet: title = "Pet"
            case .feed: title = "Feed"
            case .workshop: title = "Workbench"
            case .warm: title = "Warm up"
            case .bell: title = "Ring bell"
            case .build: title = "Decorate"
            case .buy(let kind):
                title = kind == "cocoa" ? "Cocoa" : (kind == "gift" ? "Gift" : "Treat")
                cost = price(of: kind)
                enabled = save.coins >= cost
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
        guard state.screen == .playing, state.dialog == nil, state.curtain == nil, !state.mapOpen, !state.shopOpen, !busy, let action = currentAction else { return }
        switch action {
        case .talk: talk()
        case .chop(let index): chop(index)
        case .deliver: deliver()
        case .light(let index): lightUp(index)
        case .sleep: goToSleep()
        case .lightTree: lightGreatTree()
        case .chat(let house): chat(house)
        case .give(let house): giveGift(to: house)
        case .pet(let kind): pet(kind)
        case .feed: feedDeer()
        case .buy(let kind): buy(kind)
        case .workshop: openShop()
        case .warm: warmUp()
        case .bell: ringBell()
        case .build: enterBuild()
        }
    }

    func showDialog(_ dialog: Dialog, then: (() -> Void)? = nil) {
        resetStick()
        afterDialog = then
        state.dialog = dialog
        Sound.shared.play("talk", volume: 0.7)
    }

    func dismissDialog() {
        state.dialog = nil
        Sound.shared.play("tap")
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
                text: "It's Christmas Eve, \(save.playerName)! The village needs its great tree.\n\nBring the big fir from beside your lane down to the square, would you?",
                button: "With pleasure")
        } else {
            let house = world.houses[todayHouse]
            let ask = SaveData.speaksInRiddles(on: save.day) ? todayWish.riddle : todayWish.sentence
            var text = "Good morning, \(save.playerName)! \(ask)\n\nI live in \(house.hint)."
            switch todayEvent {
            case .rush: text += "\n\nAnd I'm in a hurry. Bring it within two minutes and there's a bonus in it."
            case .storm: text += "\n\nDreadful weather. I'll pay extra for your trouble."
            case .market: text += "\n\nIt's market day, by the way. Half price at the stalls."
            case .none: break
            }
            dialog = Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: text, button: "I'll find one")
        }
        let walkerBase = isLastDay ? "mayor" : world.houses[todayHouse].villager
        showDialog(dialog) { [weak self] in
            guard let self = self else { return }
            self.save.phase = .seeking
            self.save.store()
            if self.todayEvent == .rush { self.rushLeft = 120 }
            // The customer strolls off down the lane instead of vanishing.
            if let customer = self.customerNode {
                self.customerNode = nil
                let frames = self.walkFrames.map { self.texture("\(walkerBase)_side_\($0)") }
                customer.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.18)))
                customer.run(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: -14, duration: 0.5),
                    SKAction.moveBy(x: 150, y: 0, duration: 5.5),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.removeFromParent()
                ]))
            }
            self.updatePhaseNodes()
            self.refreshHUD()
        }
    }

    private func chop(_ index: Int) {
        guard chopCooldown <= 0 else { return }
        chopCooldown = 0.28
        let giant = index < 0
        let found: SKSpriteNode? = giant ? giantNode : (index < lotNodes.count ? lotNodes[index] : nil)
        guard let tree = found else { return }

        // Hit the green zone for a strong swing. The zone jumps after every swing.
        let good = abs(chopSwing - chopZone) < 0.15
        let needed = giant ? 10 : 3 + save.lot[index].traits.height
        var power = good ? 2 : 1
        if save.axe { power += 1 }
        chopDamage[index, default: 0] += power
        if !good { chopSloppy.insert(index) }
        chopZone = CGFloat.random(in: 0.2...0.8)

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
        Sound.shared.play(good ? "chop_good" : "chop")

        if chopDamage[index, default: 0] >= needed {
            fell(index, tree: tree)
        }
    }

    private func fell(_ index: Int, tree: SKSpriteNode) {
        busy = true
        let giant = index < 0
        let clean = !chopSloppy.contains(index)
        var bonus = 0
        if giant {
            save.giantChopped = true
            save.carryingGiant = true
            giantNode = nil
            if clean { bonus = 5 }
        } else {
            save.lot[index].chopped = true
            save.carried = save.lot[index].traits
            if clean { bonus = 2 + save.lot[index].traits.height }
        }
        save.phase = .hauling
        save.coins += bonus
        save.store()

        let angle: CGFloat = player.position.x < tree.position.x ? -CGFloat.pi / 2 : CGFloat.pi / 2
        let topple = SKAction.rotate(byAngle: angle, duration: 0.55)
        topple.timingMode = .easeIn
        tree.run(SKAction.sequence([topple, SKAction.fadeOut(withDuration: 0.25), SKAction.removeFromParent()]))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Sound.shared.play("timber")

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
                if bonus > 0 { Sound.shared.play("coin") }
                self.state.showToast(bonus > 0 ? "Clean cut!  +\(bonus) coins" : "Timber!")
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
        var pay = 6 + 7 * hits + (perfect ? 6 : 0)
        var extras: [String] = []
        let tip = min(save.hearts, 10)
        if tip > 0 {
            pay += tip
            extras.append("+\(tip) tip from a fond village")
        }
        if todayEvent == .storm {
            pay += 5
            extras.append("+5 for braving the storm")
        }
        if todayEvent == .rush {
            if rushLeft > 0 {
                pay += 8
                extras.append("+8 for being quick")
            } else {
                extras.append("Too late for the rush bonus")
            }
        }
        rushLeft = 0

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
        Sound.shared.play("deliver")

        let line: String
        if perfect {
            line = "Oh, it's perfect! Exactly the tree I was dreaming of."
        } else if hits + 1 >= wish.count {
            line = "It's lovely. Not quite what I pictured, but it has charm."
        } else {
            line = "Hm. That's not what I asked for at all. Still, a tree is a tree."
        }
        var text = "\(line)\n\n\(wish.report(tree))\n\n+\(pay) coins" + (perfect ? "  ·  +1 heart" : "")
        if !extras.isEmpty { text += "\n" + extras.joined(separator: "\n") }
        showDialog(Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: text, button: "Merry Christmas"))
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
        Sound.shared.play("deliver")
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
            Sound.shared.play("nope")
            return
        }
        save.coins -= light.cost
        save.lit[index] = true
        save.store()
        addLightNodes(index, animated: true)
        refreshHUD()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Sound.shared.play("light")
        state.showToast("Lit: \(light.label)")
    }

    /// The "Go home" button: skip the walk back and go straight to bed.
    func headHome() {
        guard state.screen == .playing, state.dialog == nil, state.curtain == nil, !busy, save.phase == .evening, !isLastDay else { return }
        goToSleep()
    }

    private func goToSleep() {
        busy = true
        let next = save.day + 1
        state.curtain = "December \(12 + next)"
        Sound.shared.play("sleep")
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.3),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.save.day = next
                self.save.phase = .morning
                if self.save.tutorial < 100 { self.save.tutorial = 100 }
                self.save.store()
                self.rushLeft = 0
                self.state.tutorialText = ""
                self.rebuildDynamic()
                // Wake at dawn, so last night's lights are still glowing as you step out.
                self.night = 0.55
                self.applyNight(force: true)
                self.refreshHUD()
            },
            SKAction.wait(forDuration: 1.1),
            SKAction.run { [weak self] in
                self?.state.curtain = nil
                self?.busy = false
                self?.announceDay()
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
        Sound.shared.play("fanfare")
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
        if save.phase == .epilogue {
            lines = [
                "Merry Christmas! Look at that tree. Just look at it.",
                "I've never seen the square so bright. You did this.",
                "The children think the fireworks are for them. Let them.",
                "Come by tomorrow. There's pie, and you've earned a slice.",
                "Next winter, save me the crooked one again."
            ]
        } else if save.phase == .evening {
            lines = [
                "The tree looks wonderful. Thank you again, \(save.playerName)!",
                "Have you seen the lanterns? The village feels warmer already.",
                "My little ones can't stop staring at the star on top.",
                "It finally feels like Christmas around here.",
                "You can skate on the lake, you know. And the pond.",
                "Sit by a fire a while. It puts a spring in your step.",
                "Ring the chapel bell some time. The birds hate it."
            ]
        } else if save.houseTrees[index] != nil {
            lines = [
                "Our tree is the talk of the street. Thank you!",
                "The children are skating on the lake again. Go on, try it.",
                "Try the cocoa at the market. You'll walk faster for hours. Well, minutes.",
                "The deer up the forest trail love gingerbread. They'll eat from your hand.",
                "That cat by the well follows anyone who's kind to it.",
                "A small gift from the toy stall goes a long way with folk here."
            ]
        } else {
            lines = [
                "Lovely morning for it, \(save.playerName). I'll be by for a tree one of these days.",
                "I walked past \(save.farmName) this morning. That garden of yours could use a snowman.",
                "The village is so dark this year. A few lanterns would do wonders.",
                "Have you seen the sheep at the barn? They like a scratch behind the ears.",
                "They say there's a campfire spot up the forest trail.",
                "Short, medium or tall. Slim or bushy. Straight or crooked. That's all there is to a fir.",
                "Your workbench sells a tree guide, doesn't it? Might save you some squinting.",
                "The happier we are with our trees, the better we tip. Just saying."
            ]
        }
        showDialog(Dialog(speaker: house.name, portrait: house.villager + "_down_0", text: lines.randomElement() ?? "Merry Christmas!", button: "See you"))
    }
}
