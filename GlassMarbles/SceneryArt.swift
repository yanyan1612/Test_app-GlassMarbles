import UIKit

/// 木桌面背景。所有界面共用同一张图，铺满整个屏幕。
enum WoodBackground {
    /// 按最大的 iPhone 屏幕尺寸画一次，小屏幕上等比裁切
    static let image: UIImage = draw(size: CGSize(width: 440, height: 960))

    private static func draw(size: CGSize) -> UIImage {
        Art.render(size: size, scale: 2) { cg in
            var random = SeededRandom(seed: 20261010)
            let plankCount = 3
            let plankWidth = size.width / CGFloat(plankCount)
            let plankColors = [
                UIColor(red: 0.56, green: 0.35, blue: 0.18, alpha: 1),
                UIColor(red: 0.50, green: 0.31, blue: 0.16, alpha: 1),
                UIColor(red: 0.60, green: 0.39, blue: 0.21, alpha: 1),
            ]

            for plank in 0..<plankCount {
                let rect = CGRect(x: CGFloat(plank) * plankWidth, y: 0, width: plankWidth, height: size.height)
                cg.saveGState()
                cg.clip(to: rect)

                // 木板底色，左右略有明暗
                let base = plankColors[plank % plankColors.count]
                Art.linear(cg, [base.mixed(with: .black, 0.08), base, base.mixed(with: .black, 0.12)], [0, 0.5, 1],
                           from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))

                drawGrain(cg, in: rect, base: base, random: &random)
                if Bool.random(using: &random) {
                    drawKnot(cg, in: rect, base: base, random: &random)
                }
                cg.restoreGState()

                // 木板之间的缝：一条暗线加一条亮边
                if plank > 0 {
                    cg.setFillColor(UIColor(red: 0.16, green: 0.09, blue: 0.04, alpha: 0.85).cgColor)
                    cg.fill(CGRect(x: rect.minX - 1, y: 0, width: 2, height: size.height))
                    cg.setFillColor(UIColor(red: 1, green: 0.9, blue: 0.75, alpha: 0.12).cgColor)
                    cg.fill(CGRect(x: rect.minX + 1, y: 0, width: 1, height: size.height))
                }
            }

            // 光照：上方中间亮，四周暗，让视线集中在中间
            Art.radial(cg, [UIColor(white: 1, alpha: 0.08), UIColor(white: 0, alpha: 0), UIColor(white: 0, alpha: 0.55)],
                       [0, 0.45, 1],
                       center: CGPoint(x: size.width * 0.5, y: size.height * 0.38), radius: size.height * 0.75)
        }
    }

    /// 木纹：很多条细长、微微起伏的竖线
    private static func drawGrain(_ cg: CGContext, in rect: CGRect, base: UIColor, random: inout SeededRandom) {
        let lineCount = Int(rect.width / 2.2)
        for _ in 0..<lineCount {
            let x0 = CGFloat.random(in: rect.minX...rect.maxX, using: &random)
            let amplitude = CGFloat.random(in: 1...6, using: &random)
            let frequency = CGFloat.random(in: 0.004...0.012, using: &random)
            let phase = CGFloat.random(in: 0...(2 * .pi), using: &random)
            let path = CGMutablePath()
            var y: CGFloat = 0
            path.move(to: CGPoint(x: x0 + sin(phase) * amplitude, y: 0))
            while y <= rect.maxY {
                y += 6
                let x = x0 + sin(y * frequency + phase) * amplitude + sin(y * frequency * 3.1 + phase * 2) * amplitude * 0.3
                path.addLine(to: CGPoint(x: x, y: y))
            }
            let isDark = CGFloat.random(in: 0...1, using: &random) < 0.75
            let tone = isDark ? base.mixed(with: .black, 0.45) : base.mixed(with: .white, 0.25)
            cg.addPath(path)
            cg.setStrokeColor(tone.withAlphaComponent(.random(in: 0.06...0.22, using: &random)).cgColor)
            cg.setLineWidth(.random(in: 0.4...1.6, using: &random))
            cg.strokePath()
        }
    }

    /// 木节：一圈圈竖向拉长的椭圆年轮
    private static func drawKnot(_ cg: CGContext, in rect: CGRect, base: UIColor, random: inout SeededRandom) {
        let center = CGPoint(x: CGFloat.random(in: (rect.minX + 30)...(rect.maxX - 30), using: &random),
                             y: CGFloat.random(in: 80...(rect.maxY - 80), using: &random))
        let dark = base.mixed(with: .black, 0.5)
        for ring in 0..<7 {
            let rx = 4 + CGFloat(ring) * 4
            let ry = rx * 2.4
            cg.setStrokeColor(dark.withAlphaComponent(0.28 - CGFloat(ring) * 0.03).cgColor)
            cg.setLineWidth(1.2)
            cg.strokeEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
        }
        cg.setFillColor(dark.withAlphaComponent(0.55).cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - 3, y: center.y - 7, width: 6, height: 14))
    }
}

/// 玻璃缸。分三层：缸的后壁（在弹珠后面）、缸壁（左右和底部的厚玻璃）、前面的反光（在弹珠前面）。
enum JarArt {
    /// 内部底角的圆角
    static let innerCornerRadius: CGFloat = 10

    /// 缸的后壁：一层很淡的玻璃色，让缸里和缸外的桌面有区别
    static func backImage(size: CGSize) -> UIImage {
        Art.render(size: size, scale: 2) { cg in
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                                    byRoundingCorners: [.bottomLeft, .bottomRight],
                                    cornerRadii: CGSize(width: innerCornerRadius, height: innerCornerRadius))
            cg.addPath(path.cgPath)
            cg.clip()
            Art.linear(cg, [UIColor(red: 0.85, green: 1, blue: 0.97, alpha: 0.05),
                            UIColor(red: 0.85, green: 1, blue: 0.97, alpha: 0.11)], [0, 1],
                       from: .zero, to: CGPoint(x: 0, y: size.height))
            // 左右两边稍亮，像弧形的玻璃
            Art.linear(cg, [UIColor(white: 1, alpha: 0.06), .clear, .clear, UIColor(white: 1, alpha: 0.04)],
                       [0, 0.15, 0.85, 1], from: .zero, to: CGPoint(x: size.width, y: 0))
        }
    }

    /// 缸壁。innerSize 是缸内空间的大小，图片四周比它多出 thickness（顶部除外，缸口是开的）。
    static func wallsImage(innerSize: CGSize, thickness t: CGFloat) -> UIImage {
        let w = innerSize.width, h = innerSize.height
        let size = CGSize(width: w + t * 2, height: h + t)
        let ri = innerCornerRadius
        let ro = innerCornerRadius + t

        return Art.render(size: size, scale: 2) { cg in
            // 缸壁的形状：左壁顶端圆头 → 内侧 U 形 → 右壁顶端圆头 → 外侧 U 形
            let glass = UIBezierPath()
            glass.move(to: CGPoint(x: 0, y: t / 2))
            glass.addArc(withCenter: CGPoint(x: t / 2, y: t / 2), radius: t / 2,
                         startAngle: .pi, endAngle: 0, clockwise: true)
            glass.addLine(to: CGPoint(x: t, y: h - ri))
            glass.addArc(withCenter: CGPoint(x: t + ri, y: h - ri), radius: ri,
                         startAngle: .pi, endAngle: .pi / 2, clockwise: false)
            glass.addLine(to: CGPoint(x: t + w - ri, y: h))
            glass.addArc(withCenter: CGPoint(x: t + w - ri, y: h - ri), radius: ri,
                         startAngle: .pi / 2, endAngle: 0, clockwise: false)
            glass.addLine(to: CGPoint(x: t + w, y: t / 2))
            glass.addArc(withCenter: CGPoint(x: t + w + t / 2, y: t / 2), radius: t / 2,
                         startAngle: .pi, endAngle: 0, clockwise: true)
            glass.addLine(to: CGPoint(x: w + t * 2, y: h + t - ro))
            glass.addArc(withCenter: CGPoint(x: w + t * 2 - ro, y: h + t - ro), radius: ro,
                         startAngle: 0, endAngle: .pi / 2, clockwise: true)
            glass.addLine(to: CGPoint(x: ro, y: h + t))
            glass.addArc(withCenter: CGPoint(x: ro, y: h + t - ro), radius: ro,
                         startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            glass.close()

            // 玻璃本体：淡淡的青白色，越靠底部越厚越绿
            cg.saveGState()
            cg.addPath(glass.cgPath)
            cg.clip()
            Art.linear(cg, [UIColor(red: 0.85, green: 1, blue: 0.96, alpha: 0.22),
                            UIColor(red: 0.7, green: 0.95, blue: 0.88, alpha: 0.32)], [0, 1],
                       from: .zero, to: CGPoint(x: 0, y: size.height))
            // 左右壁上竖直的亮条，让玻璃有厚度感
            let streakWidth = t * 0.3
            for x in [t * 0.25, w + t * 1.45] {
                Art.linear(cg, [.clear, UIColor(white: 1, alpha: 0.55), .clear], [0, 0.5, 1],
                           from: CGPoint(x: x, y: 0), to: CGPoint(x: x + streakWidth, y: 0))
            }
            // 底部的一道横向亮条
            Art.linear(cg, [.clear, UIColor(white: 1, alpha: 0.35), .clear], [0, 0.5, 1],
                       from: CGPoint(x: 0, y: h + t * 0.15), to: CGPoint(x: 0, y: h + t * 0.6))
            cg.restoreGState()

            // 外轮廓和内轮廓
            cg.addPath(glass.cgPath)
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor)
            cg.setLineWidth(1.2)
            cg.strokePath()
        }
    }

    /// 缸前面的反光，盖在弹珠上面，要很淡，不能挡住弹珠
    static func reflectionImage(size: CGSize) -> UIImage {
        Art.render(size: size, scale: 2) { cg in
            let streaks: [(x: CGFloat, width: CGFloat, alpha: CGFloat)] = [
                (0.04, 0.07, 0.12),
                (0.13, 0.015, 0.14),
                (0.9, 0.035, 0.07),
            ]
            for streak in streaks {
                let rect = CGRect(x: size.width * streak.x, y: size.height * 0.03,
                                  width: size.width * streak.width, height: size.height * 0.92)
                cg.saveGState()
                cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2).cgPath)
                cg.clip()
                Art.linear(cg, [.clear, UIColor(white: 1, alpha: streak.alpha), .clear], [0, 0.5, 1],
                           from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))
                cg.restoreGState()
            }
        }
    }
}
