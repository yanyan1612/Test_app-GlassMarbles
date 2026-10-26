import CoreMotion

/// 把手机的左右倾斜换算成物理世界里的侧向重力。
final class TiltController {
    /// 手机侧放到 90° 时，侧向力是重力的多少倍
    var sensitivity: Double = 0.6
    /// 倾斜量小于这个值当作没倾斜（约 3°），正常拿手机时手的轻微晃动不会让弹珠乱跑
    private let deadZone: Double = 0.05
    /// 平滑系数：越小越平滑，但反应越慢
    private let smoothing: Double = 0.25

    /// 模拟器没有传感器，用屏幕按钮设置这个值来模拟倾斜（-1 向左倒到底，1 向右倒到底）
    var simulatedTilt: Double?

    private let motionManager = CMMotionManager()
    private var smoothedTilt: Double = 0

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60
        motionManager.startDeviceMotionUpdates()
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// 每帧调用一次。返回侧向重力占重力的比例，负数向左，正数向右。
    func lateralGravityRatio() -> Double {
        // gravity.x：手机竖着拿时，往左歪是负数，往右歪是正数，侧放到 90° 时为 ±1
        let raw = simulatedTilt ?? motionManager.deviceMotion?.gravity.x ?? 0
        let beyondDeadZone = max(0, abs(raw) - deadZone) / (1 - deadZone)
        let target = beyondDeadZone * (raw < 0 ? -1 : 1)
        smoothedTilt += (target - smoothedTilt) * smoothing
        return smoothedTilt * sensitivity
    }
}
