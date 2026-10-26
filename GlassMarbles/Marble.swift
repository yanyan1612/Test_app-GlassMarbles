import SpriteKit

enum PhysicsCategory {
    static let marble: UInt32 = 1 << 0
    /// 容器左右两面墙
    static let wall: UInt32 = 1 << 1
    /// 容器底部
    static let floor: UInt32 = 1 << 2
}

/// 弹性系数。物理引擎碰撞时取两者中较大的那个，
/// 所以弹珠本身设得低，「弹珠碰弹珠」就闷；底部设得高，「弹珠砸底部」就弹。
enum Bounciness {
    static let marble: CGFloat = 0.2
    static let wall: CGFloat = 0.3
    static let floor: CGFloat = 0.6
}

/// 一颗弹珠。物理形状挂在这个节点上，外观画在子节点 visual 上，
/// 这样做缩放动画时不会影响物理碰撞。
final class Marble: SKNode {
    static let levelCount = 11
    static var maxLevel: Int { levelCount - 1 }
    /// 随机掉落时只会出现这些等级，更大的必须靠合成
    static let spawnableLevels = 0...4

    /// 每个等级的半径，占容器宽度的比例。最大一级的直径约为容器宽度的一半。
    private static let radiusRatios: [CGFloat] = [
        0.040, 0.052, 0.066, 0.080, 0.096, 0.114, 0.134, 0.156, 0.180, 0.208, 0.240,
    ]

    /// 每个等级的主色，决定弹珠花纹的颜色
    private static let colors: [UIColor] = [
        UIColor(red: 0.95, green: 0.30, blue: 0.35, alpha: 1),  // 红
        UIColor(red: 1.00, green: 0.58, blue: 0.20, alpha: 1),  // 橙
        UIColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 1),  // 黄
        UIColor(red: 0.60, green: 0.88, blue: 0.30, alpha: 1),  // 黄绿
        UIColor(red: 0.20, green: 0.75, blue: 0.45, alpha: 1),  // 绿
        UIColor(red: 0.20, green: 0.78, blue: 0.78, alpha: 1),  // 青
        UIColor(red: 0.30, green: 0.62, blue: 1.00, alpha: 1),  // 蓝
        UIColor(red: 0.42, green: 0.40, blue: 0.95, alpha: 1),  // 靛
        UIColor(red: 0.68, green: 0.40, blue: 0.95, alpha: 1),  // 紫
        UIColor(red: 0.98, green: 0.45, blue: 0.75, alpha: 1),  // 粉
        UIColor(red: 0.96, green: 0.96, blue: 1.00, alpha: 1),  // 白（最高级）
    ]

    static func radius(forLevel level: Int, containerWidth: CGFloat) -> CGFloat {
        containerWidth * radiusRatios[level]
    }

    static func color(forLevel level: Int) -> UIColor {
        colors[level]
    }

    let level: Int
    let radius: CGFloat
    /// 藏在弹珠里的宝物；合成这颗弹珠时就能收集到
    let treasure: Treasure?
    /// 已经被安排合成，防止同一颗弹珠在一帧里和两颗弹珠同时合成
    var isMerging = false
    /// 开始超过警戒线的时间；没超线时为 nil
    var overLineSince: TimeInterval?

    /// 外观的根节点。合成时的弹出动画缩放的是它，不影响物理形状。
    private let visual = SKNode()
    /// 不跟着弹珠转的部分：光影、阴影、宝物图标
    private let upright = SKNode()

    init(level: Int, radius: CGFloat, treasure: Treasure? = nil) {
        self.level = level
        self.radius = radius
        self.treasure = treasure
        super.init()
        addChild(visual)
        drawAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 松手下落或合成出来时调用，让弹珠开始受重力和碰撞影响
    func enablePhysics() {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.restitution = Bounciness.marble   // 弹性：0 不弹，1 完全弹回
        body.friction = 0.3
        body.linearDamping = 0.1
        body.angularDamping = 0.3
        body.categoryBitMask = PhysicsCategory.marble
        let everything = PhysicsCategory.marble | PhysicsCategory.wall | PhysicsCategory.floor
        body.collisionBitMask = everything
        body.contactTestBitMask = everything   // 撞到任何东西都要通知，用来发声音和震动
        physicsBody = body
    }

    /// 每帧调用：抵消弹珠的旋转，让光影、阴影和宝物图标保持不动。
    /// 光源不会跟着弹珠转，所以高光一直在左上角；里面的花纹照常转动，看得出在滚。
    func keepUpright() {
        upright.zRotation = -zRotation
    }

    /// 合成出来时的弹出动画
    func playPopAnimation() {
        visual.setScale(0.6)
        let grow = SKAction.scale(to: 1.12, duration: 0.10)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.08)
        settle.timingMode = .easeIn
        visual.run(.sequence([grow, settle]))
    }

    private func drawAppearance() {
        let diameter = radius * 2

        // 花纹层：随机转一个角度，同级的弹珠看起来不会一模一样
        let core = SKSpriteNode(texture: MarbleArt.coreTexture(level: level, radius: radius))
        core.size = CGSize(width: diameter, height: diameter)
        core.zRotation = .random(in: 0..<(2 * .pi))
        visual.addChild(core)
        visual.addChild(upright)

        // 阴影：往右下偏一点，放在所有弹珠下面
        let shadow = SKSpriteNode(texture: MarbleArt.shadowTexture(radius: radius))
        shadow.size = CGSize(width: diameter * MarbleArt.shadowScale, height: diameter * MarbleArt.shadowScale)
        shadow.position = CGPoint(x: radius * 0.1, y: -radius * 0.16)
        shadow.zPosition = -0.6
        upright.addChild(shadow)

        // 宝物在玻璃里面，所以画在光影层下面
        if let treasure {
            let icon = TreasureArt.makeNode(treasure, size: radius * 1.05)
            icon.zPosition = 0.005
            upright.addChild(icon)
        }

        let overlay = SKSpriteNode(texture: MarbleArt.overlayTexture(radius: radius))
        overlay.size = CGSize(width: diameter, height: diameter)
        overlay.zPosition = 0.01
        upright.addChild(overlay)
    }
}
