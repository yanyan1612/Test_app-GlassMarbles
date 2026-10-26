import UIKit

/// 给定种子就总是产生同样序列的随机数，保证每次画出来的花纹、木纹都一样
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    // SplitMix64 算法
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 绘图的小工具
enum Art {
    /// 用 Core Graphics 画一张图。scale 固定为 3，在所有 iPhone 上都清晰。
    static func render(size: CGSize, scale: CGFloat = 3, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
    }

    static func gradient(_ colors: [UIColor], _ locations: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                   colors: colors.map(\.cgColor) as CFArray,
                   locations: locations)!
    }

    /// 从 center 向外的径向渐变
    static func radial(_ cg: CGContext, _ colors: [UIColor], _ locations: [CGFloat],
                       center: CGPoint, radius: CGFloat) {
        cg.drawRadialGradient(gradient(colors, locations),
                              startCenter: center, startRadius: 0,
                              endCenter: center, endRadius: radius,
                              options: [.drawsAfterEndLocation])
    }

    static func linear(_ cg: CGContext, _ colors: [UIColor], _ locations: [CGFloat],
                       from start: CGPoint, to end: CGPoint) {
        cg.drawLinearGradient(gradient(colors, locations), start: start, end: end,
                              options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

extension UIColor {
    /// 和另一个颜色按比例混合，amount 为 0 时是自己，为 1 时是另一个颜色
    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: a1 + (a2 - a1) * amount)
    }

    /// 色相偏移一点，用来生成和主色搭配的辅助色
    func hueShifted(_ delta: CGFloat) -> UIColor {
        var (h, s, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: (h + delta + 1).truncatingRemainder(dividingBy: 1),
                       saturation: s, brightness: b, alpha: a)
    }
}
