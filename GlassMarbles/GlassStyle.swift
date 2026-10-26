import SwiftUI

extension View {
    /// 毛玻璃样式：磨砂半透明底 + 左上亮右下暗的一圈玻璃边 + 柔和的投影。
    /// tint 给玻璃染一点颜色，用来区分不同的按钮。
    func frostedGlass<S: InsettableShape>(_ shape: S, tint: Color? = nil) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint.opacity(0.35))
                }
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.08)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

/// 铺满整个屏幕的木桌面
struct WoodTableBackground: View {
    var body: some View {
        // 用 GeometryReader 把图片限制在屏幕大小内，否则等比填满会把整个界面撑大
        GeometryReader { geometry in
            Image(uiImage: WoodBackground.image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

/// 毛玻璃按钮的文字样式
struct GlassButtonLabel: View {
    let title: String
    var subtitle: String?
    var tint: Color?
    var font: Font = .headline

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(font)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .opacity(0.8)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, subtitle == nil ? 14 : 18)
        .frostedGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), tint: tint)
    }
}
