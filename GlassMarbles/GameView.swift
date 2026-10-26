import SwiftUI
import SpriteKit

/// 游戏画面：SpriteKit 场景 + 顶部信息栏 + 结算窗口
struct GameView: View {
    let scene: GameScene
    let onExit: () -> Void
    let onPlay: (GameMode) -> Void

    private var state: GameState { scene.state }

    var body: some View {
        ZStack {
            // 场景背景是透明的，露出后面的木桌面
            SpriteView(scene: scene, options: [.allowsTransparency])

            GameHUD(state: state, onBack: onExit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            AnnouncementBanner(event: state.announcement)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 190)

            #if targetEnvironment(simulator)
            SimulatedTiltButtons(tilt: scene.tilt)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            #endif

            if state.isFinished {
                ResultCard(state: state,
                           onRestart: { scene.restart() },
                           onPlay: onPlay,
                           onExit: onExit)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: state.isFinished)
    }
}

/// 顶部：左边返回按钮 + 分数或关卡目标，右边「下一颗」预告
private struct GameHUD: View {
    let state: GameState
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topRow
            if state.streak >= 2 {
                StreakBadge(streak: state.streak)
                    .padding(.leading, 54)
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state.streak >= 2)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            BackButton(action: onBack)

            Group {
                switch state.mode {
                case .endless:
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(state.score)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(.snappy, value: state.score)
                        Text("最高 \(state.bestScore)")
                            .font(.caption)
                            .opacity(0.75)
                    }
                case .level(let level):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第 \(level.id) 关")
                            .font(.caption.bold())
                            .opacity(0.8)
                        GoalProgress(goal: level.goal, state: state)
                            .font(.title3.bold())
                    }
                }
            }
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frostedGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)   // 不挡住下面游戏画面的触摸

            Spacer()

            NextMarblePreview(level: state.nextLevel, treasure: state.nextTreasure)
                .allowsHitTesting(false)
        }
    }
}

/// 连击数，比如「连击 ×4」
private struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange, .yellow)
            Text("连击 ×\(streak)")
                .contentTransition(.numericText())
                .animation(.snappy, value: streak)
        }
        .font(.subheadline.bold())
        .monospacedDigit()
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frostedGlass(Capsule(), tint: .orange)
        .allowsHitTesting(false)
    }
}

/// 连锁、连击时在容器上方弹出的大字，比如「Amazing!」。弹出后约 1 秒淡出。
private struct AnnouncementBanner: View {
    let event: AnnouncementEvent?
    @State private var visible: AnnouncementEvent?

    var body: some View {
        ZStack {
            if let visible {
                let announcement = visible.value
                // 连锁用金色，连击用青色
                let colors: [Color] = announcement.isStreak
                    ? [.white, .cyan, Color(red: 0.2, green: 0.5, blue: 1)]
                    : [.white, .yellow, .orange]
                Text(announcement.text)
                    .font(.system(size: 40 + 22 * announcement.intensity, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .shadow(color: colors[2].opacity(0.8), radius: 14)
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                    .rotationEffect(.degrees(-6))
                    .id(visible.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity),
                                            removal: .scale(scale: 1.3).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: visible)
        .allowsHitTesting(false)
        .onChange(of: event) { _, newEvent in
            visible = newEvent
            guard let newEvent else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                // 如果这期间又有新的播报，就不要把新的那个藏起来
                if visible == newEvent { visible = nil }
            }
        }
    }
}

/// 右上角「下一颗」预告
private struct NextMarblePreview: View {
    let level: Int
    let treasure: Treasure?

    var body: some View {
        VStack(spacing: 3) {
            Text("下一颗")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.8))
            Image(uiImage: MarbleArt.image(level: level, treasure: treasure, diameter: 30))
                .resizable()
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frostedGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// 关卡目标的当前进度，比如「120 / 300 分」或「🪙 2/3  💎 0/2」
private struct GoalProgress: View {
    let goal: Level.Goal
    let state: GameState

    var body: some View {
        switch goal {
        case .score(let target):
            Text("\(min(state.score, target)) / \(target) 分")
                .contentTransition(.numericText())
                .animation(.snappy, value: state.score)
        case .treasures(let goldTarget, let gemTarget):
            HStack(spacing: 12) {
                if goldTarget > 0 {
                    TreasureCount(treasure: .gold, text: "\(min(state.gold, goldTarget))/\(goldTarget)", iconSize: 20)
                }
                if gemTarget > 0 {
                    TreasureCount(treasure: .gem, text: "\(min(state.gems, gemTarget))/\(gemTarget)", iconSize: 20)
                }
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: state.gold + state.gems)
        }
    }
}

/// 一局结束时的窗口：无尽模式结束 / 闯关失败 / 闯关成功
private struct ResultCard: View {
    let state: GameState
    let onRestart: () -> Void
    let onPlay: (GameMode) -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                content
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .padding(28)
            .frame(maxWidth: 310)
            .frostedGlass(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch (state.mode, state.phase) {
        case (.endless, _):
            Text("游戏结束").font(.title2.bold())
            VStack(spacing: 4) {
                Text("\(state.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if state.isNewBest {
                    Text("新纪录！").font(.headline).foregroundStyle(.yellow)
                } else {
                    Text("最高 \(state.bestScore)").font(.subheadline).opacity(0.75)
                }
            }
            primaryButton("再来一局", action: onRestart)
            secondaryButton("主界面", action: onExit)

        case (.level(let level), .levelCleared):
            Text("第 \(level.id) 关").font(.headline).opacity(0.75)
            Text("通关！")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            if let next = level.next {
                primaryButton("下一关") { onPlay(.level(next)) }
            } else {
                Text("全部关卡已完成").font(.subheadline)
            }
            secondaryButton("关卡列表", action: onExit)

        case (.level(let level), _):
            Text("第 \(level.id) 关").font(.headline).opacity(0.75)
            Text("挑战失败").font(.title.bold())
            GoalProgress(goal: level.goal, state: state)
                .font(.title3.bold())
                .monospacedDigit()
            primaryButton("重试", action: onRestart)
            secondaryButton("关卡列表", action: onExit)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassButtonLabel(title: title, tint: .cyan)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
    }
}

#if targetEnvironment(simulator)
/// 仅模拟器：按住按钮模拟手机往左/右倾斜。真机版本不会编译这段代码。
private struct SimulatedTiltButtons: View {
    let tilt: TiltController
    /// 按住按钮相当于把手机倾斜到多少（1 为侧放 90°）
    private let amount = 0.7

    var body: some View {
        HStack {
            button(symbol: "chevron.left", direction: -1)
            Spacer()
            button(symbol: "chevron.right", direction: 1)
        }
    }

    private func button(symbol: String, direction: Double) -> some View {
        Image(systemName: symbol)
            .font(.title2.bold())
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 52, height: 52)
            .frostedGlass(Circle())
            .opacity(0.7)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in tilt.simulatedTilt = direction * amount }
                    .onEnded { _ in tilt.simulatedTilt = nil }
            )
    }
}
#endif
