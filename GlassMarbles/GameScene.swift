import SpriteKit

/// 游戏主场景。坐标原点在左下角，y 轴向上。
final class GameScene: SKScene, SKPhysicsContactDelegate {
    /// 容器左右、底部离屏幕边缘的距离
    private let sideInset: CGFloat = 16
    private let bottomInset: CGFloat = 16
    /// 玻璃缸壁的厚度（画在容器外侧，不占容器内部空间）
    private let glassThickness: CGFloat = 10
    /// 容器墙壁顶部占屏幕高度的比例；墙壁以上是放弹珠的区域
    private let wallTopRatio: CGFloat = 0.80
    /// 警戒线占屏幕高度的比例；弹珠堆过这条线就算失败
    private let warningLineRatio: CGFloat = 0.76
    /// 松手后多久出现下一颗弹珠
    private let dropCooldown: TimeInterval = 0.5
    /// 弹珠超过警戒线持续多久判负
    private let overLineLimit: TimeInterval = 2.0
    /// 超线多久后警戒线开始闪烁（避免每次刚松手、弹珠路过警戒线时都闪一下）
    private let warningFlashDelay: TimeInterval = 0.3

    let state = GameState()
    private let sound = SoundPlayer()
    private let haptics = Haptics()
    let tilt = TiltController()
    private let announcer = Announcer()
    /// 上一次播报的内容和时间，用来避免厉害的播报被紧接着的弱播报打断
    private var lastAnnouncement: (value: Announcement, time: TimeInterval)?

    /// 从上次落下到现在合成了几次（连锁）
    private var chainCount = 0
    /// 连续几次落下都至少合成了一次（连击）
    private var streak = 0
    /// 连击加分：每多连击一次加 10%，最多 ×2
    private func streakMultiplier() -> Double {
        min(2.0, 1.0 + 0.1 * Double(max(0, streak - 1)))
    }

    /// 撞击速度低于这个值不发声、不震动（实测：静止贴地的弹珠抖动约 50，从顶部落到底约 2000）
    private let impactMinSpeed: CGFloat = 150
    /// 撞击速度达到这个值就是最大音量、最强震动
    private let impactMaxSpeed: CGFloat = 1800
    /// 同一种撞击反馈的最短间隔
    private let minImpactInterval: TimeInterval = 0.04
    private var lastImpactTime: [ImpactKind: TimeInterval] = [:]

    private let containerLayer = SKNode()
    /// 所有弹珠（包括手上悬着的那颗）都放在这一层，重新开始时整层清空
    private let marbleLayer = SKNode()
    private var warningLine: SKShapeNode?

    /// 容器内部区域，后面放弹珠、算物理边界都会用到
    private(set) var containerRect: CGRect = .zero
    private(set) var warningLineY: CGFloat = 0
    /// 手上悬着的弹珠的高度
    private var holdY: CGFloat = 0

    /// 当前玩的是无尽模式还是第几关
    private(set) var mode: GameMode = .endless
    /// 调用 start(_:) 之后，等场景拿到真实尺寸再开局
    private var needsStart = false
    /// 开局正在倒入预置弹珠：这段时间不能放弹珠
    private var isSettingUp = false
    /// 从开始倒入预置弹珠，到玩家放下第一颗弹珠为止：同级弹珠碰到不合成，而是换掉其中一颗的等级。
    /// 预置弹珠落稳后还会微微下沉，如果这时就允许合成，玩家还没动手就会白拿宝物。
    private var isGuardingPreset = false

    /// 预置弹珠铺满容器高度的比例
    private let presetFillRatio: CGFloat = 1.0 / 3
    /// 估算铺满需要多少颗时用的系数（实测 0.9 会铺到容器的 0.45 左右，0.7 约为 1/3）
    private let presetPackingDensity: CGFloat = 0.7
    /// 预置弹珠里带宝物的比例
    private let presetTreasureRatio = 0.5
    /// 预置弹珠一颗接一颗掉下来的间隔
    private let presetDropInterval: TimeInterval = 0.04
    /// 手上悬着、还没松手的弹珠
    private var heldMarble: Marble?
    private var aimX: CGFloat = 0
    private var nextLevel = 0
    private var nextTreasure: Treasure?

    private let guideLine = SKShapeNode()

    /// 这一帧里检测到的待合成弹珠对，在物理模拟结束后统一处理
    private var pendingMerges: [(Marble, Marble)] = []

    private enum ActionKey {
        static let spawn = "spawn"
        static let setup = "setup"
        static let flash = "flash"
    }

    override init() {
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill   // 场景尺寸跟随屏幕变化
        anchorPoint = .zero
        backgroundColor = .clear   // 透明，露出 SwiftUI 那边铺的木桌面
        physicsWorld.contactDelegate = self
        addChild(containerLayer)
        addChild(marbleLayer)

        guideLine.strokeColor = UIColor(white: 1, alpha: 0.18)
        guideLine.lineWidth = 2
        guideLine.zPosition = 0
        addChild(guideLine)

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutContainer()
    }

    override func update(_ currentTime: TimeInterval) {
        // 等场景拿到真实屏幕尺寸后再开局，弹珠大小是按容器宽度算的
        if needsStart, containerRect.width > 0 {
            needsStart = false
            restart()
        }
        if !state.isFinished {
            applyTilt()
            if !isSettingUp {
                checkWarningLine(at: currentTime)
            }
        }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        tilt.start()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        tilt.stop()
    }

    // MARK: - 倾斜

    private let standardGravity: CGFloat = 9.8

    /// 根据手机倾斜调整重力方向：往下的分量不变，再加上一个侧向分量
    private func applyTilt() {
        let lateral = CGFloat(tilt.lateralGravityRatio()) * standardGravity
        physicsWorld.gravity = CGVector(dx: lateral, dy: -standardGravity)

        // 静止的弹珠会被物理引擎「休眠」，不再响应重力变化，需要手动叫醒
        guard abs(lateral) > 0.01 else { return }
        for case let marble as Marble in marbleLayer.children {
            marble.physicsBody?.isResting = false
        }
    }

    // MARK: - 开局和结束

    /// 开始一局新游戏（从主界面或关卡列表进入时调用）
    func start(_ mode: GameMode) {
        self.mode = mode
        state.reset(mode: mode)   // 立刻重置，避免上一局的结算窗口闪一下
        needsStart = true
    }

    /// 离开游戏画面时调用，清空容器
    func stop() {
        removeAction(forKey: ActionKey.spawn)
        removeAction(forKey: ActionKey.setup)
        isSettingUp = false
        isGuardingPreset = false
        chainCount = 0
        streak = 0
        lastAnnouncement = nil
        announcer.stop()
        marbleLayer.removeAllChildren()
        heldMarble = nil
        pendingMerges.removeAll()
        guideLine.isHidden = true
    }

    /// 用当前模式重新开始（「再来一局」「重试」）
    func restart() {
        stop()
        setWarningLineFlashing(false)
        physicsWorld.speed = 1
        state.reset(mode: mode)
        if aimX == 0 { aimX = containerRect.midX }
        rollNextMarble()
        if case .level(let level) = mode, level.hasPresetMarbles {
            pourPresetMarbles(for: level)
        } else {
            spawnHeldMarble()
        }
    }

    // MARK: - 开局预置弹珠

    /// 金币关开局：一颗接一颗从上方倒入弹珠，铺满底部，等它们落稳后才开始玩
    private func pourPresetMarbles(for level: Level) {
        isSettingUp = true
        isGuardingPreset = true
        var steps: [SKAction] = []
        for (marbleLevel, treasure) in makePresetPlan(for: level) {
            steps.append(.run { [weak self] in self?.dropPresetMarble(level: marbleLevel, treasure: treasure) })
            steps.append(.wait(forDuration: presetDropInterval))
        }
        steps.append(.wait(forDuration: 0.8))   // 等弹珠落稳
        steps.append(.run { [weak self] in self?.removePresetConflicts(passesLeft: 5) })
        run(.sequence(steps), withKey: ActionKey.setup)
    }

    /// 决定要倒入哪些弹珠：总面积约铺满容器的 1/3，其中约一半带宝物
    private func makePresetPlan(for level: Level) -> [(level: Int, treasure: Treasure?)] {
        let targetArea = containerRect.width * containerRect.height * presetFillRatio * presetPackingDensity
        var area: CGFloat = 0
        var plan: [(level: Int, treasure: Treasure?)] = []
        while area < targetArea {
            var marbleLevel = Marble.spawnableLevels.randomElement()!
            var treasure: Treasure?
            if Double.random(in: 0..<1) < presetTreasureRatio, let kind = level.randomPresetTreasure() {
                treasure = kind
                marbleLevel = kind.marbleLevels.randomElement()!
            }
            let radius = Marble.radius(forLevel: marbleLevel, containerWidth: containerRect.width)
            area += .pi * radius * radius
            plan.append((marbleLevel, treasure))
        }
        return plan
    }

    private func dropPresetMarble(level: Int, treasure: Treasure?) {
        let marble = makeMarble(level: level, treasure: treasure)
        let y = containerRect.maxY - marble.radius - 2
        // 找一个不和刚掉下来、还在顶部的弹珠重叠的位置
        var x = clampedX(.random(in: containerRect.minX...containerRect.maxX), radius: marble.radius)
        for _ in 0..<12 {
            let overlaps = marbleLayer.children.contains { node in
                guard let other = node as? Marble else { return false }
                return hypot(other.position.x - x, other.position.y - y) < other.radius + marble.radius
            }
            if !overlaps { break }
            x = clampedX(.random(in: containerRect.minX...containerRect.maxX), radius: marble.radius)
        }
        marble.position = CGPoint(x: x, y: y)
        marble.zPosition = 1
        marble.enablePhysics()
        marbleLayer.addChild(marble)
    }

    /// 开局保护期间（见 isGuardingPreset），两颗同级弹珠一碰到，就把其中一颗换成别的等级，
    /// 避免开局后它们自动合成、白送宝物。
    /// 新等级要和它周围的弹珠都不同，优先换成更小的（变小不会挤到旁边的弹珠）；
    /// 带宝物的只在能藏这种宝物的等级之间换，所以宝物数量不变。
    private func relevelTouchingPresetMarbles() {
        for (a, b) in touchingSameLevelPairs() {
            let marble = a.treasure == nil ? a : b
            let neighborLevels = Set(marbleLayer.children.compactMap { node -> Int? in
                guard let other = node as? Marble, other !== marble else { return nil }
                let distance = hypot(other.position.x - marble.position.x, other.position.y - marble.position.y)
                return distance <= other.radius + marble.radius + 4 ? other.level : nil
            })
            let allowedLevels = marble.treasure?.marbleLevels ?? Marble.spawnableLevels
            let choices = allowedLevels.filter { $0 != marble.level && !neighborLevels.contains($0) }
            guard let newLevel = choices.filter({ $0 < marble.level }).randomElement() ?? choices.randomElement() else {
                continue   // 实在换不了，留给最后的兜底检查
            }

            let replacement = makeMarble(level: newLevel, treasure: marble.treasure)
            replacement.position = marble.position
            replacement.zPosition = marble.zPosition
            replacement.enablePhysics()
            replacement.physicsBody?.velocity = marble.physicsBody?.velocity ?? .zero
            marble.removeFromParent()
            marbleLayer.addChild(replacement)
        }
    }

    /// 兜底：落稳后如果还有两颗同级的挨在一起（通常是周围没有可换的等级），
    /// 每一对里移走一颗（优先移走不带宝物的），再等落稳检查一遍。
    private func removePresetConflicts(passesLeft: Int) {
        let pairs = touchingSameLevelPairs()
        guard !pairs.isEmpty, passesLeft > 0 else {
            finishSetup()
            return
        }
        for (a, b) in pairs {
            let removed = a.treasure == nil ? a : b
            removed.physicsBody = nil
            removed.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
        run(.sequence([
            .wait(forDuration: 0.35),
            .run { [weak self] in self?.removePresetConflicts(passesLeft: passesLeft - 1) },
        ]), withKey: ActionKey.setup)
    }

    private func finishSetup() {
        isSettingUp = false
        spawnHeldMarble()
    }

    private func endGame() {
        state.endGame()
        freeze()
    }

    private func clearLevel() {
        state.clearLevel()
        freeze()
    }

    /// 一局结束：冻结画面，不再出新弹珠
    private func freeze() {
        physicsWorld.speed = 0
        removeAction(forKey: ActionKey.spawn)
        setWarningLineFlashing(false)
        warningLine?.alpha = 1
        guideLine.isHidden = true
    }

    /// 检查有没有弹珠超过警戒线太久
    private func checkWarningLine(at now: TimeInterval) {
        var anyOverLongEnough = false
        for case let marble as Marble in marbleLayer.children where marble.physicsBody != nil {
            guard marble.position.y + marble.radius > warningLineY else {
                marble.overLineSince = nil
                continue
            }
            let since = marble.overLineSince ?? now
            marble.overLineSince = since
            let duration = now - since
            if duration >= overLineLimit {
                endGame()
                return
            }
            if duration >= warningFlashDelay {
                anyOverLongEnough = true
            }
        }
        setWarningLineFlashing(anyOverLongEnough)
    }

    private func setWarningLineFlashing(_ flashing: Bool) {
        guard let line = warningLine else { return }
        let isFlashing = line.action(forKey: ActionKey.flash) != nil
        if flashing, !isFlashing {
            let blink = SKAction.sequence([
                .fadeAlpha(to: 0.15, duration: 0.15),
                .fadeAlpha(to: 1.0, duration: 0.15),
            ])
            line.run(.repeatForever(blink), withKey: ActionKey.flash)
        } else if !flashing, isFlashing {
            line.removeAction(forKey: ActionKey.flash)
            line.alpha = 1
        }
    }

    // MARK: - 容器

    private func layoutContainer() {
        guard size.width > 0, size.height > 0 else { return }
        containerLayer.removeAllChildren()

        let left = sideInset
        let right = size.width - sideInset
        let bottom = bottomInset
        let top = size.height * wallTopRatio
        containerRect = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        warningLineY = size.height * warningLineRatio
        holdY = top + (size.height - top) * 0.3

        // 玻璃缸：后壁在弹珠后面，缸壁和前面的反光在弹珠前面
        let back = SKSpriteNode(texture: SKTexture(image: JarArt.backImage(size: containerRect.size)))
        back.anchorPoint = .zero
        back.position = containerRect.origin
        back.zPosition = -1
        containerLayer.addChild(back)

        let walls = SKSpriteNode(texture: SKTexture(image: JarArt.wallsImage(innerSize: containerRect.size,
                                                                              thickness: glassThickness)))
        walls.anchorPoint = .zero
        walls.position = CGPoint(x: left - glassThickness, y: bottom - glassThickness)
        walls.zPosition = 2
        containerLayer.addChild(walls)

        let reflection = SKSpriteNode(texture: SKTexture(image: JarArt.reflectionImage(size: containerRect.size)))
        reflection.anchorPoint = .zero
        reflection.position = containerRect.origin
        reflection.zPosition = 6
        containerLayer.addChild(reflection)

        // 物理边界：两侧墙和底部分开，这样可以有不同的弹性，也能分辨弹珠撞到的是哪里
        let leftWall = makeEdge(from: CGPoint(x: left, y: bottom), to: CGPoint(x: left, y: top),
                                category: PhysicsCategory.wall, restitution: Bounciness.wall)
        let rightWall = makeEdge(from: CGPoint(x: right, y: bottom), to: CGPoint(x: right, y: top),
                                 category: PhysicsCategory.wall, restitution: Bounciness.wall)
        let floor = makeEdge(from: CGPoint(x: left, y: bottom), to: CGPoint(x: right, y: bottom),
                             category: PhysicsCategory.floor, restitution: Bounciness.floor)
        [leftWall, rightWall, floor].forEach(containerLayer.addChild)

        // 红色虚线警戒线
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: left, y: warningLineY))
        linePath.addLine(to: CGPoint(x: right, y: warningLineY))
        let line = SKShapeNode(path: linePath.copy(dashingWithPhase: 0, lengths: [10, 8]))
        line.strokeColor = UIColor(red: 1, green: 0.32, blue: 0.3, alpha: 0.9)
        line.lineWidth = 2
        line.zPosition = 3
        // 下面垫一条宽而淡的红线，像在发光
        let glow = SKShapeNode(path: linePath)
        glow.strokeColor = UIColor(red: 1, green: 0.3, blue: 0.25, alpha: 0.18)
        glow.lineWidth = 7
        glow.zPosition = -0.1
        line.addChild(glow)
        containerLayer.addChild(line)
        warningLine = line
    }

    private func makeEdge(from start: CGPoint, to end: CGPoint,
                          category: UInt32, restitution: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: start, to: end)
        body.categoryBitMask = category
        body.restitution = restitution
        body.friction = 0.3
        node.physicsBody = body
        return node
    }

    // MARK: - 瞄准和下落

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        aim(at: touch.location(in: self).x)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        aim(at: touch.location(in: self).x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        aim(at: touch.location(in: self).x)
        dropHeldMarble()
    }

    private func aim(at x: CGFloat) {
        aimX = x
        guard let marble = heldMarble, !state.isFinished else { return }
        marble.position.x = clampedX(x, radius: marble.radius)
        updateGuideLine()
    }

    private func dropHeldMarble() {
        guard let marble = heldMarble, !state.isFinished else { return }
        heldMarble = nil
        isGuardingPreset = false   // 玩家动手了，之后的合成都正常计算
        // 上一颗落下后一次都没合成，连击就断了
        if chainCount == 0 {
            streak = 0
            state.setStreak(0)
        }
        chainCount = 0
        marble.zPosition = 1
        // 加一点肉眼看不出的随机偏移。否则在同一位置连续丢的弹珠会完全对准，
        // 物理上左右受力刚好平衡，会笔直地叠成一根柱子而不是滚开。
        marble.position.x += CGFloat.random(in: -0.5...0.5)
        marble.enablePhysics()
        guideLine.isHidden = true

        run(.sequence([
            .wait(forDuration: dropCooldown),
            .run { [weak self] in self?.spawnHeldMarble() },
        ]), withKey: ActionKey.spawn)
    }

    /// 把「下一颗」拿到手上，并重新随机一个新的「下一颗」
    private func spawnHeldMarble() {
        let marble = makeMarble(level: nextLevel, treasure: nextTreasure)
        rollNextMarble()

        marble.position = CGPoint(x: clampedX(aimX, radius: marble.radius), y: holdY)
        marble.zPosition = 4
        marbleLayer.addChild(marble)
        heldMarble = marble

        guideLine.isHidden = false
        updateGuideLine()
    }

    private func updateGuideLine() {
        guard let marble = heldMarble else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: marble.position.x, y: marble.position.y - marble.radius))
        path.addLine(to: CGPoint(x: marble.position.x, y: containerRect.minY))
        guideLine.path = path.copy(dashingWithPhase: 0, lengths: [6, 6])
    }

    // MARK: - 合成

    func didBegin(_ contact: SKPhysicsContact) {
        let marbleA = contact.bodyA.node as? Marble
        let marbleB = contact.bodyB.node as? Marble

        if let a = marbleA, let b = marbleB {
            if !isGuardingPreset,
               a.level == b.level,
               a.level < Marble.maxLevel,   // 两颗最高级弹珠碰到一起不合成
               !a.isMerging, !b.isMerging {
                a.isMerging = true
                b.isMerging = true
                pendingMerges.append((a, b))   // 要合成的话就只播合成的声音，不播碰撞声
            } else {
                let speed = impactSpeed(contact.collisionImpulse, a.physicsBody, b.physicsBody)
                playImpactFeedback(.marble, speed: speed)
            }
        } else if let marble = marbleA ?? marbleB {
            let speed = impactSpeed(contact.collisionImpulse, marble.physicsBody, nil)
            playImpactFeedback(.container, speed: speed)
        }
    }

    override func didSimulatePhysics() {
        if isGuardingPreset {
            relevelTouchingPresetMarbles()
        } else {
            collectTouchingPairs()
        }
        // 不在碰撞回调里直接增删节点，避免干扰物理引擎正在进行的计算
        for (a, b) in pendingMerges {
            merge(a, b)
        }
        pendingMerges.removeAll()

        if !state.isFinished, state.isGoalMet {
            clearLevel()
        }
        for case let marble as Marble in marbleLayer.children {
            marble.keepUpright()
        }
    }

    /// 保底检查：两颗同级弹珠慢慢滚到一起、轻轻贴住时，物理引擎有时不会触发 didBegin，
    /// 所以每帧再按距离找一遍贴在一起的同级弹珠。
    private func collectTouchingPairs() {
        for (a, b) in touchingSameLevelPairs() {
            a.isMerging = true
            b.isMerging = true
            pendingMerges.append((a, b))
        }
    }

    /// 找出贴在一起的同级弹珠，每颗弹珠最多出现在一对里
    private func touchingSameLevelPairs() -> [(Marble, Marble)] {
        let touchTolerance: CGFloat = 1.0
        let candidates = marbleLayer.children.compactMap { node -> Marble? in
            guard let marble = node as? Marble,
                  marble.physicsBody != nil,
                  !marble.isMerging,
                  marble.level < Marble.maxLevel
            else { return nil }
            return marble
        }
        var paired = Set<ObjectIdentifier>()
        var pairs: [(Marble, Marble)] = []
        for (i, a) in candidates.enumerated() where !paired.contains(ObjectIdentifier(a)) {
            for b in candidates[(i + 1)...] where b.level == a.level && !paired.contains(ObjectIdentifier(b)) {
                let distance = hypot(a.position.x - b.position.x, a.position.y - b.position.y)
                if distance <= a.radius + b.radius + touchTolerance {
                    paired.insert(ObjectIdentifier(a))
                    paired.insert(ObjectIdentifier(b))
                    pairs.append((a, b))
                    break
                }
            }
        }
        return pairs
    }

    private func merge(_ a: Marble, _ b: Marble) {
        let midpoint = CGPoint(x: (a.position.x + b.position.x) / 2,
                               y: (a.position.y + b.position.y) / 2)
        a.removeFromParent()
        b.removeFromParent()

        let merged = makeMarble(level: a.level + 1)
        merged.position = CGPoint(x: clampedX(midpoint.x, radius: merged.radius),
                                  y: max(midpoint.y, containerRect.minY + merged.radius))
        merged.zPosition = 1
        merged.enablePhysics()
        marbleLayer.addChild(merged)
        merged.playPopAnimation()

        // 连锁和连击：第一次合成算一次连击，之后的合成算连锁
        chainCount += 1
        if chainCount == 1 {
            streak += 1
            state.setStreak(streak)
        }
        let announcement = chainCount == 1 ? Announcement.forStreak(streak) : Announcement.forChain(chainCount)
        if let announcement, shouldAnnounce(announcement) {
            announcer.say(announcement)
            state.announce(announcement)
            lastAnnouncement = (announcement, CACurrentMediaTime())
        }

        // 得分 = 基础分 × 连锁序号（第几次合成） × 连击倍数
        let basePoints = Double(GameState.points(forMergedLevel: merged.level))
        state.addPoints(Int((basePoints * Double(chainCount) * streakMultiplier()).rounded()))

        // 合成出来的等级越高，声音越低沉
        let pitch = max(0.55, 1.5 - 0.09 * Float(merged.level))
        sound.play(.merge, volume: 0.8, pitch: pitch)
        haptics.merge(level: merged.level)

        // 合成的两颗里藏着的宝物都收集起来
        for treasure in [a.treasure, b.treasure].compactMap({ $0 }) {
            collect(treasure, from: midpoint)
        }
    }

    /// 上一句还在播（0.9 秒内）时，只有更厉害或一样厉害的播报才能打断它。
    /// 比如刚喊完「Awesome!」，同一次落下又连锁一下，就不要马上被「Good!」盖掉。
    private func shouldAnnounce(_ announcement: Announcement) -> Bool {
        guard let last = lastAnnouncement, CACurrentMediaTime() - last.time < 0.9 else { return true }
        return announcement.intensity >= last.value.intensity
    }

    // MARK: - 收集宝物

    private func collect(_ treasure: Treasure, from position: CGPoint) {
        state.collect(treasure)
        sound.play(.coin, volume: 0.9, pitch: treasure == .gem ? 1.25 : 1.0)
        haptics.collect()

        // 宝物图标从合成的位置飞向左上角的计数
        let icon = TreasureArt.makeNode(treasure, size: 26)
        icon.position = position
        icon.zPosition = 10
        addChild(icon)
        let target = CGPoint(x: 90, y: size.height - 40)
        let rise = SKAction.moveBy(x: 0, y: 30, duration: 0.15)
        rise.timingMode = .easeOut
        let fly = SKAction.group([
            .move(to: target, duration: 0.45),
            .scale(to: 0.6, duration: 0.45),
        ])
        fly.timingMode = .easeIn
        icon.run(.sequence([rise, fly, .fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    // MARK: - 撞击反馈

    private enum ImpactKind {
        case container   // 砸到底部或两侧墙
        case marble      // 砸到别的弹珠
    }

    /// 碰撞时两者在接触方向上的速度变化。和弹珠大小无关，只反映撞得有多猛。
    private func impactSpeed(_ impulse: CGFloat, _ bodyA: SKPhysicsBody?, _ bodyB: SKPhysicsBody?) -> CGFloat {
        let inverseMassA = bodyA.map { 1 / $0.mass } ?? 0
        let inverseMassB = bodyB.map { 1 / $0.mass } ?? 0
        return impulse * (inverseMassA + inverseMassB)
    }

    private func playImpactFeedback(_ kind: ImpactKind, speed: CGFloat) {
        // 轻碰不发声、不震动，避免弹珠堆在一起时响个不停
        guard speed > impactMinSpeed else { return }

        // 同一种撞击两次之间至少隔一小段时间，多颗弹珠同时落地时不会炸成一片
        let now = CACurrentMediaTime()
        guard now - (lastImpactTime[kind] ?? 0) >= minImpactInterval else { return }
        lastImpactTime[kind] = now

        let strength = min(1, (speed - impactMinSpeed) / (impactMaxSpeed - impactMinSpeed))
        let volume = Float(0.15 + 0.85 * strength)
        switch kind {
        case .container:
            sound.play(.floorHit, volume: volume, pitch: Float.random(in: 0.92...1.08))
            haptics.containerHit(intensity: 0.3 + 0.7 * strength)
        case .marble:
            sound.play(.marbleHit, volume: volume, pitch: Float.random(in: 0.9...1.1))
            haptics.marbleHit(intensity: 0.2 + 0.6 * strength)
        }
    }

    // MARK: - 工具

    private func makeMarble(level: Int, treasure: Treasure? = nil) -> Marble {
        Marble(level: level,
               radius: Marble.radius(forLevel: level, containerWidth: containerRect.width),
               treasure: treasure)
    }

    /// 随机决定下一颗弹珠的等级，以及（闯关模式下）里面有没有藏宝物。
    /// 带宝物时，等级从能藏这种宝物的弹珠里挑（金币是红/橙，钻石是黄绿/绿）。
    private func rollNextMarble() {
        nextTreasure = nil
        if case .level(let level) = mode, let treasure = level.rollTreasure() {
            nextTreasure = treasure
            nextLevel = treasure.marbleLevels.randomElement()!
        } else {
            nextLevel = Marble.spawnableLevels.randomElement()!
        }
        state.setNextMarble(level: nextLevel, treasure: nextTreasure)   // 右上角的「下一颗」预告
    }

    /// 让弹珠的水平位置不超出容器
    private func clampedX(_ x: CGFloat, radius: CGFloat) -> CGFloat {
        let margin = radius + 1
        return min(max(x, containerRect.minX + margin), containerRect.maxX - margin)
    }
}
