import SpriteKit
import SwiftUI

/// 金币和钻石的外观。画成图片后，游戏画面（SpriteKit）和界面（SwiftUI）共用。
enum TreasureArt {
    private static var imageCache: [String: UIImage] = [:]
    private static var textureCache: [String: SKTexture] = [:]

    static func image(_ treasure: Treasure, size: CGFloat) -> UIImage {
        let key = "\(treasure)-\(Int((size * 10).rounded()))"
        if let cached = imageCache[key] { return cached }
        let image = Art.render(size: CGSize(width: size, height: size)) { cg in
            switch treasure {
            case .gold: drawCoin(cg, size: size)
            case .gem:  drawGem(cg, size: size)
            }
        }
        imageCache[key] = image
        return image
    }

    static func texture(_ treasure: Treasure, size: CGFloat) -> SKTexture {
        let key = "\(treasure)-\(Int((size * 10).rounded()))"
        if let cached = textureCache[key] { return cached }
        let texture = SKTexture(image: image(treasure, size: size))
        textureCache[key] = texture
        return texture
    }

    static func makeNode(_ treasure: Treasure, size: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(treasure, size: size))
        node.size = CGSize(width: size, height: size)
        return node
    }

    // MARK: - 金币

    private static func drawCoin(_ cg: CGContext, size s: CGFloat) {
        let outer = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.04, dy: s * 0.04)
        let inner = outer.insetBy(dx: s * 0.13, dy: s * 0.13)
        let lightGold = UIColor(red: 1.0, green: 0.95, blue: 0.62, alpha: 1)
        let gold = UIColor(red: 0.96, green: 0.75, blue: 0.17, alpha: 1)
        let darkGold = UIColor(red: 0.6, green: 0.4, blue: 0.04, alpha: 1)

        // 外圈：左上亮、右下暗
        cg.saveGState()
        cg.addEllipse(in: outer)
        cg.clip()
        Art.linear(cg, [lightGold, gold, darkGold], [0, 0.45, 1],
                   from: CGPoint(x: outer.minX, y: outer.minY), to: CGPoint(x: outer.maxX, y: outer.maxY))
        cg.restoreGState()

        // 币面：渐变方向反过来，看起来是凹下去的
        cg.saveGState()
        cg.addEllipse(in: inner)
        cg.clip()
        Art.linear(cg, [darkGold.mixed(with: gold, 0.4), gold, lightGold], [0, 0.55, 1],
                   from: CGPoint(x: inner.minX, y: inner.minY), to: CGPoint(x: inner.maxX, y: inner.maxY))
        cg.restoreGState()

        // 中间的浮雕五角星
        let star = starPath(center: CGPoint(x: s / 2, y: s / 2), outerRadius: s * 0.2, innerRadius: s * 0.085)
        cg.addPath(star)
        cg.setFillColor(lightGold.cgColor)
        cg.fillPath()
        cg.addPath(star)
        cg.setStrokeColor(darkGold.withAlphaComponent(0.7).cgColor)
        cg.setLineWidth(s * 0.025)
        cg.strokePath()

        // 轮廓和左上角的反光
        cg.setStrokeColor(darkGold.cgColor)
        cg.setLineWidth(s * 0.04)
        cg.strokeEllipse(in: outer)
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        cg.setLineWidth(s * 0.045)
        cg.setLineCap(.round)
        cg.addArc(center: CGPoint(x: s / 2, y: s / 2), radius: s * 0.38,
                  startAngle: .pi * 1.1, endAngle: .pi * 1.4, clockwise: false)
        cg.strokePath()
    }

    private static func starPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    // MARK: - 钻石

    private static func drawGem(_ cg: CGContext, size s: CGFloat) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        // 台面左右两点、腰线左右两点、底尖，再加两条切面分割点
        let tableLeft = p(0.3, 0.2), tableRight = p(0.7, 0.2)
        let girdleLeft = p(0.05, 0.42), girdleRight = p(0.95, 0.42)
        let cutLeft = p(0.38, 0.42), cutRight = p(0.62, 0.42)
        let culet = p(0.5, 0.95)

        let facets: [([CGPoint], UIColor)] = [
            ([girdleLeft, tableLeft, cutLeft], UIColor(red: 0.75, green: 0.96, blue: 1.0, alpha: 1)),
            ([tableLeft, tableRight, cutRight, cutLeft], UIColor(red: 0.91, green: 0.99, blue: 1.0, alpha: 1)),
            ([tableRight, girdleRight, cutRight], UIColor(red: 0.56, green: 0.9, blue: 1.0, alpha: 1)),
            ([girdleLeft, cutLeft, culet], UIColor(red: 0.36, green: 0.8, blue: 0.94, alpha: 1)),
            ([cutLeft, cutRight, culet], UIColor(red: 0.6, green: 0.91, blue: 1.0, alpha: 1)),
            ([cutRight, girdleRight, culet], UIColor(red: 0.18, green: 0.62, blue: 0.84, alpha: 1)),
        ]
        let edge = UIColor(red: 0.1, green: 0.37, blue: 0.53, alpha: 1)
        for (points, color) in facets {
            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            cg.addPath(path)
            cg.setFillColor(color.cgColor)
            cg.fillPath()
            cg.addPath(path)
            cg.setStrokeColor(edge.withAlphaComponent(0.45).cgColor)
            cg.setLineWidth(s * 0.02)
            cg.strokePath()
        }

        let outline = CGMutablePath()
        outline.addLines(between: [tableLeft, tableRight, girdleRight, culet, girdleLeft])
        outline.closeSubpath()
        cg.addPath(outline)
        cg.setStrokeColor(edge.cgColor)
        cg.setLineWidth(s * 0.04)
        cg.setLineJoin(.round)
        cg.strokePath()

        // 右上角的四角星闪光
        let sparkle = p(0.8, 0.17)
        let ray = s * 0.13
        let sparklePath = CGMutablePath()
        sparklePath.move(to: CGPoint(x: sparkle.x, y: sparkle.y - ray))
        sparklePath.addQuadCurve(to: CGPoint(x: sparkle.x + ray, y: sparkle.y), control: sparkle)
        sparklePath.addQuadCurve(to: CGPoint(x: sparkle.x, y: sparkle.y + ray), control: sparkle)
        sparklePath.addQuadCurve(to: CGPoint(x: sparkle.x - ray, y: sparkle.y), control: sparkle)
        sparklePath.addQuadCurve(to: CGPoint(x: sparkle.x, y: sparkle.y - ray), control: sparkle)
        cg.addPath(sparklePath)
        cg.setFillColor(UIColor.white.cgColor)
        cg.fillPath()
    }
}

/// SwiftUI 用的宝物图标，显示在顶部计数和关卡列表里
struct TreasureIcon: View {
    let treasure: Treasure
    var size: CGFloat = 18

    var body: some View {
        Image(uiImage: TreasureArt.image(treasure, size: size))
            .resizable()
            .frame(width: size, height: size)
    }
}
