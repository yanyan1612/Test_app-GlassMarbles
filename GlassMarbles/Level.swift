import Foundation

/// 弹珠里可能藏着的宝物
enum Treasure {
    case gold   // 金币：只出现在小弹珠里
    case gem    // 钻石：只出现在大弹珠里

    /// 能藏这种宝物的弹珠等级
    var marbleLevels: ClosedRange<Int> {
        switch self {
        case .gold: return 0...1   // 红、橙
        case .gem:  return 3...4   // 黄绿、绿
        }
    }
}

enum GameMode: Hashable {
    case endless
    case level(Level)
}

/// 闯关模式的一关
struct Level: Identifiable, Hashable {
    enum Goal: Hashable {
        case score(Int)
        case treasures(gold: Int, gems: Int)
    }

    let id: Int
    let goal: Goal
    /// 每颗掉落的弹珠是「带金币的红/橙弹珠」的概率
    var goldChance: Double = 0
    /// 每颗掉落的弹珠是「带钻石的黄绿/绿弹珠」的概率
    var gemChance: Double = 0

    /// 金币关和双币关开局时底部预先铺好一层弹珠
    var hasPresetMarbles: Bool {
        if case .treasures = goal { return true }
        return false
    }

    /// 按概率决定下一颗掉落的弹珠里藏什么宝物，nil 表示不藏
    func rollTreasure() -> Treasure? {
        let roll = Double.random(in: 0..<1)
        if roll < goldChance { return .gold }
        if roll < goldChance + gemChance { return .gem }
        return nil
    }

    /// 预置弹珠里的宝物种类，按两种宝物的掉落概率比例来分配
    func randomPresetTreasure() -> Treasure? {
        let total = goldChance + gemChance
        guard total > 0 else { return nil }
        return Double.random(in: 0..<total) < goldChance ? .gold : .gem
    }

    var next: Level? {
        Level.all.first { $0.id == id + 1 }
    }

    /// 全部关卡。调整难度只需要改这里的数字。
    static let all: [Level] = [
        Level(id: 1, goal: .score(100)),
        Level(id: 2, goal: .score(300)),
        Level(id: 3, goal: .treasures(gold: 15, gems: 0), goldChance: 0.30),
        Level(id: 4, goal: .score(600)),
        Level(id: 5, goal: .treasures(gold: 30, gems: 0), goldChance: 0.35),
        Level(id: 6, goal: .treasures(gold: 50, gems: 0), goldChance: 0.40),
        Level(id: 7, goal: .treasures(gold: 20, gems: 8), goldChance: 0.30, gemChance: 0.15),
        Level(id: 8, goal: .score(1200)),
        Level(id: 9, goal: .treasures(gold: 35, gems: 12), goldChance: 0.30, gemChance: 0.20),
        Level(id: 10, goal: .treasures(gold: 50, gems: 20), goldChance: 0.35, gemChance: 0.20),
    ]
}

/// 记录哪些关卡已经通过，保存在手机里
enum LevelProgress {
    private static let clearedKey = "clearedLevelIDs"

    static var clearedIDs: Set<Int> {
        Set(UserDefaults.standard.array(forKey: clearedKey) as? [Int] ?? [])
    }

    static func isCleared(_ level: Level) -> Bool {
        clearedIDs.contains(level.id)
    }

    /// 第 1 关总是开放；之后每一关要先通过前一关。
    /// 从 Xcode 直接运行的调试版全部开放，方便测试。
    static func isUnlocked(_ level: Level) -> Bool {
        #if DEBUG
        return true
        #else
        return level.id == 1 || clearedIDs.contains(level.id - 1)
        #endif
    }

    static func markCleared(_ level: Level) {
        var ids = clearedIDs
        ids.insert(level.id)
        UserDefaults.standard.set(Array(ids), forKey: clearedKey)
    }
}
