// 用代码合成游戏音效，输出到 GlassMarbles/Sounds/。
// 运行方法（在项目根目录）：swift Tools/generate_sounds.swift
// 以后找到更好的音效素材，直接用同名 .wav 文件替换即可，不需要再运行这个脚本。

import Foundation

let sampleRate = 44_100.0

/// 简单的可复现随机数，让每次生成的声音都一样
var seed: UInt64 = 0x9E3779B97F4A7C15
func noise() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double(seed >> 11) / Double(1 << 53) * 2 - 1
}

func render(duration: Double, _ sample: (Double) -> Double) -> [Double] {
    let count = Int(duration * sampleRate)
    var samples = (0..<count).map { sample(Double($0) / sampleRate) }
    // 归一化到 0.85 的峰值，并在最后 10ms 淡出，避免结尾爆音
    let peak = samples.map(abs).max() ?? 1
    let fadeCount = Int(0.01 * sampleRate)
    for i in samples.indices {
        samples[i] = samples[i] / peak * 0.85
        let remaining = count - i
        if remaining < fadeCount { samples[i] *= Double(remaining) / Double(fadeCount) }
    }
    return samples
}

func writeWAV(_ samples: [Double], to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let byteCount = UInt32(samples.count * 2)
    data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + byteCount)
    data.append(contentsOf: Array("WAVE".utf8))
    data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
    append(UInt16(1)); append(UInt16(1))                      // PCM，单声道
    append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)) // 采样率，每秒字节数
    append(UInt16(2)); append(UInt16(16))                      // 每帧字节数，位深
    data.append(contentsOf: Array("data".utf8)); append(byteCount)
    for s in samples { append(Int16(max(-1, min(1, s)) * Double(Int16.max))) }
    try data.write(to: url)
}

// 砸到底部：低沉的「咚」。音高从 120Hz 快速下滑到 60Hz，加一点被闷住的撞击噪声。
func floorHit() -> [Double] {
    var phase = 0.0
    var filtered = 0.0
    return render(duration: 0.35) { t in
        let frequency = 60 + 60 * exp(-t * 25)
        phase += 2 * .pi * frequency / sampleRate
        let body = sin(phase) * exp(-t * 14) * (1 - exp(-t * 800))
        filtered += (noise() - filtered) * 0.08          // 低通，让噪声发闷
        let thump = filtered * exp(-t * 90) * 1.5
        return body + thump
    }
}

// 弹珠互相碰撞：清脆的玻璃「叮」。几个不成整数倍的高频泛音叠加，衰减很快。
func marbleHit() -> [Double] {
    let partials: [(frequency: Double, amplitude: Double, decay: Double)] = [
        (2093, 1.00, 28), (3363, 0.60, 35), (5011, 0.40, 45), (7130, 0.25, 60),
    ]
    return render(duration: 0.4) { t in
        let attack = 1 - exp(-t * 3000)
        let tone = partials.reduce(0.0) { sum, p in
            sum + p.amplitude * sin(2 * .pi * p.frequency * t) * exp(-p.decay * t)
        }
        let click = noise() * exp(-t * 400) * 0.3
        return (tone + click) * attack
    }
}

// 合成：先一个快速上扬的「啵」，再接一个明亮的和弦余音。播放时会按等级调整音高。
func merge() -> [Double] {
    var sweepPhase = 0.0
    return render(duration: 0.8) { t in
        let sweepFrequency = 300 + 600 * min(t / 0.06, 1)
        sweepPhase += 2 * .pi * sweepFrequency / sampleRate
        let pop = sin(sweepPhase) * exp(-t * 30) * 0.8
        let chimeStart = 0.03
        let ct = max(0, t - chimeStart)
        let chime = t < chimeStart ? 0 : (
            sin(2 * .pi * 880 * ct) * exp(-ct * 6) * 0.7 +
            sin(2 * .pi * 1320 * ct) * exp(-ct * 8) * 0.45 +
            sin(2 * .pi * 1760 * ct) * exp(-ct * 10) * 0.3
        ) * (1 - exp(-ct * 2000))
        return pop + chime
    }
}

// 收集金币：经典的两声「叮-叮」，第二声更高、拖得更长。钻石用同一个声音、播放时调高音高。
func coin() -> [Double] {
    render(duration: 0.5) { t in
        let split = 0.07
        let (frequency, local) = t < split ? (988.0, t) : (1319.0, t - split)
        let decay = t < split ? 10.0 : 7.0
        let tone = sin(2 * .pi * frequency * local) + 0.35 * sin(4 * .pi * frequency * local)
        return tone * exp(-local * decay) * (1 - exp(-local * 3000))
    }
}

let outputDirectory = URL(fileURLWithPath: "GlassMarbles/Sounds", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let sounds: [(String, [Double])] = [
    ("floor_hit", floorHit()),
    ("marble_hit", marbleHit()),
    ("merge", merge()),
    ("coin", coin()),
]
for (name, samples) in sounds {
    let url = outputDirectory.appendingPathComponent("\(name).wav")
    try writeWAV(samples, to: url)
    print("已生成 \(url.path)")
}
