import SpriteKit

/// 写实玻璃弹珠的贴图，全部用代码画，每种只画一次然后缓存。
///
/// 一颗弹珠由三层叠成：
/// - 花纹层（core）：玻璃本体和里面的花纹，跟着弹珠一起转，能看出它在滚
/// - 光影层（overlay）：边缘变暗、高光、底部聚光，位置固定不转，因为光源不会动
/// - 阴影（shadow）：弹珠投在背后的影子，也固定不转
enum MarbleArt {
    private enum Style {
        case catsEye(vanes: Int)     // 猫眼：透明玻璃里夹着几片彩色花瓣
        case swirl(ribbons: Int)     // 缠丝：螺旋形的彩色丝带
        case galaxy                  // 星空：深色玻璃里的星云和星星
        case opal                    // 欧泊：乳白底上泛彩虹光
    }

    private static func style(forLevel level: Int) -> Style {
        switch level {
        case 0, 1: return .catsEye(vanes: 3)
        case 2, 3: return .catsEye(vanes: 4)
        case 4, 5: return .swirl(ribbons: 3)
        case 6, 7: return .swirl(ribbons: 4)
        case 8, 9: return .galaxy
        default:   return .opal
        }
    }

    // MARK: - 对外接口

    private static var textureCache: [String: SKTexture] = [:]
    private static var imageCache: [String: UIImage] = [:]

    static func coreTexture(level: Int, radius: CGFloat) -> SKTexture {
        cachedTexture("core-\(level)-\(key(radius))") { coreImage(level: level, radius: radius) }
    }

    static func overlayTexture(radius: CGFloat) -> SKTexture {
        cachedTexture("overlay-\(key(radius))") { overlayImage(radius: radius) }
    }

    static func shadowTexture(radius: CGFloat) -> SKTexture {
        cachedTexture("shadow-\(key(radius))") { shadowImage(radius: radius) }
    }

    /// 阴影贴图相对弹珠直径的大小
    static let shadowScale: CGFloat = 1.3

    /// SwiftUI 界面里用的完整弹珠图（花纹 + 宝物 + 光影）
    static func image(level: Int, treasure: Treasure? = nil, diameter: CGFloat) -> UIImage {
        let cacheKey = "full-\(level)-\(String(describing: treasure))-\(key(diameter))"
        if let cached = imageCache[cacheKey] { return cached }
        let radius = diameter / 2
        let image = Art.render(size: CGSize(width: diameter, height: diameter)) { _ in
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            coreImage(level: level, radius: radius).draw(in: rect)
            if let treasure {
                let size = radius * 1.05
                TreasureArt.image(treasure, size: size)
                    .draw(in: CGRect(x: radius - size / 2, y: radius - size / 2, width: size, height: size))
            }
            overlayImage(radius: radius).draw(in: rect)
        }
        imageCache[cacheKey] = image
        return image
    }

    private static func key(_ value: CGFloat) -> Int { Int((value * 10).rounded()) }

    private static func cachedTexture(_ key: String, _ make: () -> UIImage) -> SKTexture {
        if let cached = textureCache[key] { return cached }
        let texture = SKTexture(image: make())
        textureCache[key] = texture
        return texture
    }

    // MARK: - 花纹层

    private static func coreImage(level: Int, radius r: CGFloat) -> UIImage {
        let d = r * 2
        return Art.render(size: CGSize(width: d, height: d)) { cg in
            let center = CGPoint(x: r, y: r)
            cg.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
            cg.clip()
            let color = Marble.color(forLevel: level)
            var random = SeededRandom(seed: UInt64(level + 1) * 7919)

            switch style(forLevel: level) {
            case .catsEye(let vanes):
                drawClearGlass(cg, center: center, r: r, color: color)
                drawCatsEye(cg, center: center, r: r, color: color, vanes: vanes)
            case .swirl(let ribbons):
                drawClearGlass(cg, center: center, r: r, color: color)
                drawSwirl(cg, center: center, r: r, color: color, ribbons: ribbons)
            case .galaxy:
                drawGalaxy(cg, center: center, r: r, color: color, random: &random)
            case .opal:
                drawOpal(cg, center: center, r: r, random: &random)
            }
        }
    }

    /// 有色玻璃本体：中间较透，越往边缘颜色越深。
    /// 染色要够深，否则会透出后面的木纹，红、橙、黄几种小弹珠就分不清了。
    private static func drawClearGlass(_ cg: CGContext, center: CGPoint, r: CGFloat, color: UIColor) {
        let lightCenter = CGPoint(x: center.x - r * 0.2, y: center.y - r * 0.25)
        Art.radial(cg, [
            color.mixed(with: .white, 0.45).withAlphaComponent(0.55),
            color.withAlphaComponent(0.7),
            color.mixed(with: .black, 0.3).withAlphaComponent(0.92),
        ], [0, 0.6, 1], center: lightCenter, radius: r * 1.15)
    }

    /// 猫眼：从中心伸出几片微微扭转的花瓣
    private static func drawCatsEye(_ cg: CGContext, center: CGPoint, r: CGFloat, color: UIColor, vanes: Int) {
        // 花瓣用更亮的颜色，在有色玻璃里也能看清
        let deep = color.mixed(with: .black, 0.2)
        let bright = color.mixed(with: .white, 0.45)
        let length = r * 0.88
        let width = r * 0.26

        for i in 0..<vanes {
            cg.saveGState()
            cg.translateBy(x: center.x, y: center.y)
            cg.rotate(by: CGFloat(i) * 2 * .pi / CGFloat(vanes) + 0.3)

            // 花瓣两侧的曲线不对称，看起来像被扭了一下
            let petal = UIBezierPath()
            petal.move(to: .zero)
            petal.addCurve(to: CGPoint(x: length, y: 0),
                           controlPoint1: CGPoint(x: length * 0.3, y: -width * 1.1),
                           controlPoint2: CGPoint(x: length * 0.75, y: -width * 0.5))
            petal.addCurve(to: .zero,
                           controlPoint1: CGPoint(x: length * 0.7, y: width * 0.9),
                           controlPoint2: CGPoint(x: length * 0.3, y: width * 1.2))

            cg.saveGState()
            cg.addPath(petal.cgPath)
            cg.clip()
            Art.linear(cg, [deep, bright, bright.withAlphaComponent(0.8)], [0, 0.6, 1],
                       from: .zero, to: CGPoint(x: length, y: 0))
            cg.restoreGState()

            cg.addPath(petal.cgPath)
            cg.setStrokeColor(deep.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(r * 0.015)
            cg.strokePath()

            // 花瓣中间一道浅色的反光
            cg.move(to: CGPoint(x: length * 0.12, y: 0))
            cg.addQuadCurve(to: CGPoint(x: length * 0.85, y: -width * 0.1),
                            control: CGPoint(x: length * 0.5, y: -width * 0.35))
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(r * 0.03)
            cg.setLineCap(.round)
            cg.strokePath()
            cg.restoreGState()
        }

        cg.setFillColor(deep.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - r * 0.07, y: center.y - r * 0.07, width: r * 0.14, height: r * 0.14))
    }

    /// 缠丝：几条从中心盘旋出来的彩色丝带
    private static func drawSwirl(_ cg: CGContext, center: CGPoint, r: CGFloat, color: UIColor, ribbons: Int) {
        let palette = [
            color.mixed(with: .white, 0.1),
            UIColor(white: 0.97, alpha: 1),
            color.hueShifted(0.09).mixed(with: .white, 0.2),
            color.mixed(with: .black, 0.25),
        ]
        // 中心的柔光
        Art.radial(cg, [color.mixed(with: .white, 0.5).withAlphaComponent(0.5), .clear], [0, 1],
                   center: center, radius: r * 0.5)

        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        for i in 0..<ribbons {
            let startAngle = CGFloat(i) * 2 * .pi / CGFloat(ribbons)
            let path = CGMutablePath()
            for step in 0...60 {
                let t = CGFloat(step) / 60
                let distance = r * (0.06 + 0.92 * t)
                let angle = startAngle + t * 2.1 * .pi
                let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                step == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            let ribbonColor = palette[i % palette.count]
            cg.addPath(path)
            cg.setStrokeColor(ribbonColor.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(r * 0.15)
            cg.strokePath()
            // 丝带上的一道亮边，让它有立体感
            cg.addPath(path)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            cg.setLineWidth(r * 0.035)
            cg.strokePath()
        }
    }

    /// 星空：深色玻璃，里面有几团星云和散落的星星
    private static func drawGalaxy(_ cg: CGContext, center: CGPoint, r: CGFloat, color: UIColor,
                                   random: inout SeededRandom) {
        Art.radial(cg, [color.mixed(with: .black, 0.5), color.mixed(with: .black, 0.88)], [0, 1],
                   center: CGPoint(x: center.x - r * 0.15, y: center.y - r * 0.2), radius: r * 1.1)

        let nebulaColors = [
            color.mixed(with: .white, 0.2),
            UIColor(red: 1.0, green: 0.45, blue: 0.75, alpha: 1),
            UIColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1),
            color,
        ]
        cg.setBlendMode(.screen)
        for i in 0..<6 {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &random)
            let distance = CGFloat.random(in: 0...(r * 0.6), using: &random)
            let blobCenter = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            let blobColor = nebulaColors[i % nebulaColors.count]
            Art.radial(cg, [blobColor.withAlphaComponent(0.55), blobColor.withAlphaComponent(0)], [0, 1],
                       center: blobCenter, radius: r * CGFloat.random(in: 0.3...0.6, using: &random))
        }
        cg.setBlendMode(.normal)

        for i in 0..<55 {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &random)
            let distance = r * sqrt(CGFloat.random(in: 0...0.9, using: &random))
            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            let size = r * CGFloat.random(in: 0.008...0.025, using: &random)
            cg.setFillColor(UIColor.white.withAlphaComponent(.random(in: 0.5...1, using: &random)).cgColor)
            cg.fillEllipse(in: CGRect(x: point.x - size, y: point.y - size, width: size * 2, height: size * 2))
            // 少数几颗亮星带十字星芒
            if i < 4 {
                let ray = size * 5
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
                cg.setLineWidth(size * 0.5)
                cg.move(to: CGPoint(x: point.x - ray, y: point.y))
                cg.addLine(to: CGPoint(x: point.x + ray, y: point.y))
                cg.move(to: CGPoint(x: point.x, y: point.y - ray))
                cg.addLine(to: CGPoint(x: point.x, y: point.y + ray))
                cg.strokePath()
            }
        }
    }

    /// 欧泊：乳白色底，表面浮着粉、青、黄、紫的彩光
    private static func drawOpal(_ cg: CGContext, center: CGPoint, r: CGFloat, random: inout SeededRandom) {
        Art.radial(cg, [UIColor(white: 1, alpha: 1), UIColor(red: 0.84, green: 0.86, blue: 0.93, alpha: 1)], [0, 1],
                   center: CGPoint(x: center.x - r * 0.2, y: center.y - r * 0.25), radius: r * 1.2)
        let sheens = [
            UIColor(red: 1.0, green: 0.68, blue: 0.85, alpha: 1),
            UIColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 1),
            UIColor(red: 0.78, green: 0.68, blue: 1.0, alpha: 1),
            UIColor(red: 0.6, green: 1.0, blue: 0.8, alpha: 1),
        ]
        for i in 0..<9 {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &random)
            let distance = CGFloat.random(in: 0...(r * 0.7), using: &random)
            let blobCenter = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            let sheen = sheens[i % sheens.count]
            Art.radial(cg, [sheen.withAlphaComponent(0.5), sheen.withAlphaComponent(0)], [0, 1],
                       center: blobCenter, radius: r * CGFloat.random(in: 0.25...0.5, using: &random))
        }
        drawSwirl(cg, center: center, r: r, color: UIColor(white: 0.92, alpha: 0.6), ribbons: 2)
    }

    // MARK: - 光影层（固定不转）

    private static func overlayImage(radius r: CGFloat) -> UIImage {
        let d = r * 2
        return Art.render(size: CGSize(width: d, height: d)) { cg in
            let center = CGPoint(x: r, y: r)
            cg.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
            cg.clip()

            // 边缘变暗：球体边缘的玻璃更厚、反射更多
            Art.radial(cg, [.clear, .clear, UIColor(white: 0, alpha: 0.18), UIColor(white: 0, alpha: 0.45)],
                       [0, 0.6, 0.82, 1],
                       center: CGPoint(x: center.x - r * 0.08, y: center.y - r * 0.12), radius: r * 1.08)

            // 底部聚光：光穿过玻璃球后汇聚在背光的一侧
            cg.saveGState()
            cg.translateBy(x: center.x + r * 0.22, y: center.y + r * 0.5)
            cg.scaleBy(x: 1, y: 0.55)
            Art.radial(cg, [UIColor(white: 1, alpha: 0.45), UIColor(white: 1, alpha: 0)], [0, 1],
                       center: .zero, radius: r * 0.5)
            cg.restoreGState()

            // 左上边缘一道弧形反光（窗户的倒影）
            cg.addArc(center: center, radius: r * 0.86, startAngle: .pi * 1.05, endAngle: .pi * 1.45, clockwise: false)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            cg.setLineWidth(r * 0.07)
            cg.setLineCap(.round)
            cg.strokePath()

            // 主高光：左上方一块柔和的椭圆光斑
            cg.saveGState()
            cg.translateBy(x: center.x - r * 0.35, y: center.y - r * 0.4)
            cg.rotate(by: -0.6)
            cg.scaleBy(x: 1, y: 0.6)
            Art.radial(cg, [UIColor(white: 1, alpha: 0.95), UIColor(white: 1, alpha: 0.5), UIColor(white: 1, alpha: 0)],
                       [0, 0.4, 1], center: .zero, radius: r * 0.3)
            cg.restoreGState()

            // 一个很小很亮的点，让玻璃看起来更硬、更亮
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - r * 0.48, y: center.y - r * 0.52, width: r * 0.12, height: r * 0.12))

            // 玻璃的轮廓
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(max(0.8, r * 0.025))
            cg.strokeEllipse(in: CGRect(x: 0, y: 0, width: d, height: d).insetBy(dx: r * 0.015, dy: r * 0.015))
        }
    }

    // MARK: - 阴影

    private static func shadowImage(radius r: CGFloat) -> UIImage {
        let d = r * 2 * shadowScale
        return Art.render(size: CGSize(width: d, height: d), scale: 2) { cg in
            Art.radial(cg, [UIColor(white: 0, alpha: 0.38), UIColor(white: 0, alpha: 0.22), UIColor(white: 0, alpha: 0)],
                       [0, 0.55, 1], center: CGPoint(x: d / 2, y: d / 2), radius: d / 2)
        }
    }
}
