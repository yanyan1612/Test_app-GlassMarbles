import Foundation
import Observation

/// 分数、收集到的宝物和输赢状态。游戏场景负责修改，SwiftUI 界面负责显示。
@Observable
final class GameState {
    enum Phase {
        case playing
        case gameOver       // 堆过警戒线
        case levelCleared   // 闯关模式达成目标
    }

    private static let bestScoreKey = "bestScore"

    /// 无尽模式的最高分
    static var savedBestScore: Int {
        UserDefaults.standard.integer(forKey: bestScoreKey)
    }

    private(set) var mode: GameMode = .endless
    private(set) var phase: Phase = .playing
    private(set) var score = 0
    private(set) var gold = 0
    private(set) var gems = 0
    /// 连击数：连续几次落下都有合成，显示在左上角
    private(set) var streak = 0
    /// 屏幕上正在弹出的播报大字；每次播报 id 都不同，界面据此重新播放动画
    private(set) var announcement: AnnouncementEvent?
    /// 下一颗弹珠，显示在右上角的预告里
    private(set) var nextLevel = 0
    private(set) var nextTreasure: Treasure?
    /// 无尽模式的最高分
    private(set) var bestScore = GameState.savedBestScore
    /// 这一局是否打破了开局时的最高分（只在无尽模式有意义）
    private(set) var isNewBest = false

    private var bestScoreAtStart = GameState.savedBestScore

    var isFinished: Bool { phase != .playing }

    /// 合成出某个等级的弹珠得的分：每高一级翻倍（第 1 级 2 分，第 2 级 4 分……）
    static func points(forMergedLevel level: Int) -> Int {
        1 << level
    }

    /// 闯关模式下是否已经达成目标
    var isGoalMet: Bool {
        guard case .level(let level) = mode else { return false }
        switch level.goal {
        case .score(let target):
            return score >= target
        case .treasures(let goldTarget, let gemTarget):
            return gold >= goldTarget && gems >= gemTarget
        }
    }

    func reset(mode: GameMode) {
        self.mode = mode
        phase = .playing
        score = 0
        gold = 0
        gems = 0
        streak = 0
        announcement = nil
        isNewBest = false
        bestScoreAtStart = bestScore
    }

    func setStreak(_ value: Int) {
        streak = value
    }

    func announce(_ value: Announcement) {
        announcement = AnnouncementEvent(id: (announcement?.id ?? 0) + 1, value: value)
    }

    func setNextMarble(level: Int, treasure: Treasure?) {
        nextLevel = level
        nextTreasure = treasure
    }

    func addPoints(_ points: Int) {
        score += points
        // 只有无尽模式记录最高分
        if mode == .endless, score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: Self.bestScoreKey)
        }
    }

    func collect(_ treasure: Treasure) {
        switch treasure {
        case .gold: gold += 1
        case .gem:  gems += 1
        }
    }

    func endGame() {
        phase = .gameOver
        isNewBest = mode == .endless && score > bestScoreAtStart
    }

    func clearLevel() {
        guard case .level(let level) = mode else { return }
        phase = .levelCleared
        LevelProgress.markCleared(level)
    }
}

/// 一次播报。同一句话连续出现两次时 id 不同，界面能分辨出这是新的一次。
struct AnnouncementEvent: Equatable {
    let id: Int
    let value: Announcement
}
