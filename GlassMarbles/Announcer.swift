import AVFoundation

/// 连锁/连击时的播报词
enum Announcement: String, CaseIterable {
    // 连锁：一次落下引发多次合成
    case good, great, excellent, amazing
    // 连击：连续多次落下都有合成
    case nice, awesome, unstoppable

    var text: String {
        switch self {
        case .good:        return "Good!"
        case .great:       return "Great!"
        case .excellent:   return "Excellent!"
        case .amazing:     return "Amazing!"
        case .nice:        return "Nice!"
        case .awesome:     return "Awesome!"
        case .unstoppable: return "Unstoppable!"
        }
    }

    /// 是连击的播报（否则是连锁的播报），两种在屏幕上用不同颜色
    var isStreak: Bool {
        switch self {
        case .nice, .awesome, .unstoppable: return true
        default: return false
        }
    }

    /// 激动程度 0~1：越高语调越高、屏幕上的字越大
    var intensity: Double {
        switch self {
        case .good, .nice:        return 0.2
        case .great:              return 0.45
        case .excellent, .awesome: return 0.7
        case .amazing, .unstoppable: return 1.0
        }
    }

    /// 一次落下引发第 n 次合成时的播报（n 从 1 开始，1 次不播报）
    static func forChain(_ mergeCount: Int) -> Announcement? {
        switch mergeCount {
        case ..<2: return nil
        case 2:    return .good
        case 3:    return .great
        case 4:    return .excellent
        default:   return .amazing
        }
    }

    /// 连击达到 n 次时的播报：3 次、5 次、8 次，之后每多 5 次再播一次
    static func forStreak(_ streak: Int) -> Announcement? {
        switch streak {
        case 3: return .nice
        case 5: return .awesome
        case 8: return .unstoppable
        case let n where n > 8 && (n - 8).isMultiple(of: 5): return .unstoppable
        default: return nil
        }
    }
}

/// 播报员。如果项目里有对应的配音文件（比如 voice_amazing.m4a）就播文件，
/// 没有就用 iPhone 自带的英文朗读。以后找到配音素材，把文件放进项目就会自动改用素材。
final class Announcer {
    private static let fileExtensions = ["m4a", "wav", "mp3", "caf"]

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    private var recordings: [Announcement: AVAudioPlayer] = [:]
    private var currentRecording: AVAudioPlayer?

    init() {
        // 优先用手机上装了的高质量英文声音，听起来没那么像机器人
        voice = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "en-US")

        for announcement in Announcement.allCases {
            let name = "voice_\(announcement.rawValue)"
            for ext in Self.fileExtensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    recordings[announcement] = player
                    break
                }
            }
        }
    }

    /// 播报，会打断还没说完的上一句
    func say(_ announcement: Announcement) {
        currentRecording?.stop()
        synthesizer.stopSpeaking(at: .immediate)

        if let recording = recordings[announcement] {
            recording.currentTime = 0
            recording.play()
            currentRecording = recording
            return
        }

        let utterance = AVSpeechUtterance(string: announcement.text)
        utterance.voice = voice
        // 越激动，语速越快、语调越高
        utterance.rate = Float(0.5 + 0.08 * announcement.intensity)
        utterance.pitchMultiplier = Float(1.05 + 0.3 * announcement.intensity)
        utterance.volume = 1
        synthesizer.speak(utterance)
    }

    func stop() {
        currentRecording?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }
}
