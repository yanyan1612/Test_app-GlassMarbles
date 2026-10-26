import UIKit

/// 手机震动反馈。模拟器不会震动，需要在真机上感受。
final class Haptics {
    /// 砸到容器：厚重的一下
    private let containerGenerator = UIImpactFeedbackGenerator(style: .heavy)
    /// 弹珠互相碰撞：轻而脆的一下
    private let marbleGenerator = UIImpactFeedbackGenerator(style: .rigid)
    /// 合成
    private let mergeGenerator = UIImpactFeedbackGenerator(style: .medium)
    /// 收集到金币或钻石
    private let collectGenerator = UINotificationFeedbackGenerator()

    init() {
        containerGenerator.prepare()
        marbleGenerator.prepare()
        mergeGenerator.prepare()
        collectGenerator.prepare()
    }

    /// intensity: 0~1
    func containerHit(intensity: CGFloat) {
        containerGenerator.impactOccurred(intensity: intensity)
    }

    func marbleHit(intensity: CGFloat) {
        marbleGenerator.impactOccurred(intensity: intensity)
    }

    /// 合成出来的等级越高，震动越强
    func merge(level: Int) {
        let intensity = min(1, 0.5 + CGFloat(level) * 0.05)
        mergeGenerator.impactOccurred(intensity: intensity)
    }

    func collect() {
        collectGenerator.notificationOccurred(.success)
    }
}
