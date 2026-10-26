import SwiftUI

/// 主界面：选择无尽模式或闯关模式
struct MainMenuView: View {
    let onEndless: () -> Void
    let onLevels: () -> Void

    /// 标题上方摆一排从小到大的弹珠做装饰
    private let showcaseLevels = [0, 2, 4, 6, 8, 10]

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(showcaseLevels.enumerated()), id: \.offset) { index, level in
                    let diameter = 22 + CGFloat(index) * 8
                    Image(uiImage: MarbleArt.image(level: level, diameter: diameter))
                        .resizable()
                        .frame(width: diameter, height: diameter)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 4)
                }
            }
            .padding(.bottom, 8)

            Text("玻璃弹珠")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)

            Spacer()

            Button(action: onEndless) {
                GlassButtonLabel(title: "无尽模式",
                                 subtitle: "最高分 \(GameState.savedBestScore)",
                                 tint: .cyan,
                                 font: .title2.bold())
            }
            .buttonStyle(.plain)

            Button(action: onLevels) {
                GlassButtonLabel(title: "闯关模式",
                                 subtitle: "已通关 \(LevelProgress.clearedIDs.count) / \(Level.all.count)",
                                 tint: .orange,
                                 font: .title2.bold())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

/// 关卡列表
struct LevelSelectView: View {
    let onSelect: (Level) -> Void
    let onBack: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                BackButton(action: onBack)
                Spacer()
                Text("闯关模式")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                Spacer()
                Color.clear.frame(width: 44, height: 44)   // 让标题居中
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Level.all) { level in
                    LevelCell(level: level) { onSelect(level) }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

private struct LevelCell: View {
    let level: Level
    let action: () -> Void

    var body: some View {
        let unlocked = LevelProgress.isUnlocked(level)
        let cleared = LevelProgress.isCleared(level)

        Button(action: action) {
            VStack(spacing: 8) {
                if unlocked {
                    Text("\(level.id)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    GoalSummary(goal: level.goal)
                        .font(.caption.bold())
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .frame(height: 52)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .frostedGlass(RoundedRectangle(cornerRadius: 18, style: .continuous),
                          tint: cleared ? .green : nil)
            .overlay(alignment: .topTrailing) {
                if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .green)
                        .padding(6)
                }
            }
            .opacity(unlocked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

/// 关卡目标的简短说明，比如「300 分」或「🪙×3 💎×2」
struct GoalSummary: View {
    let goal: Level.Goal

    var body: some View {
        switch goal {
        case .score(let target):
            Text("\(target) 分")
        case .treasures(let gold, let gems):
            HStack(spacing: 6) {
                if gold > 0 { TreasureCount(treasure: .gold, text: "×\(gold)") }
                if gems > 0 { TreasureCount(treasure: .gem, text: "×\(gems)") }
            }
        }
    }
}

/// 宝物图标加一个数字
struct TreasureCount: View {
    let treasure: Treasure
    let text: String
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            TreasureIcon(treasure: treasure, size: iconSize)
            Text(text).monospacedDigit()
        }
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .frostedGlass(Circle())
        }
        .buttonStyle(.plain)
    }
}
