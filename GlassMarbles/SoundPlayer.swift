import AVFoundation

/// 播放短音效，可以分别控制每一次播放的音量和音高。
/// 用一组播放器轮流发声，这样多颗弹珠同时撞击时声音可以叠在一起。
final class SoundPlayer {
    enum Sound: String, CaseIterable {
        case floorHit = "floor_hit"
        case marbleHit = "marble_hit"
        case merge
        case coin
    }

    private struct Voice {
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()   // 改变播放速度来改变音高
    }

    private let engine = AVAudioEngine()
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var voices: [Voice] = []
    private var nextVoiceIndex = 0
    private let voiceCount = 10

    init() {
        // ambient：手机静音键打开时不出声，也不会打断用户正在听的音乐
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil
            else {
                assertionFailure("找不到或无法读取音效 \(sound.rawValue).wav")
                continue
            }
            buffers[sound] = buffer
        }

        guard let format = buffers.values.first?.format else { return }
        for _ in 0..<voiceCount {
            let voice = Voice()
            engine.attach(voice.player)
            engine.attach(voice.varispeed)
            engine.connect(voice.player, to: voice.varispeed, format: format)
            engine.connect(voice.varispeed, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        try? engine.start()
    }

    /// - Parameters:
    ///   - volume: 0~1
    ///   - pitch: 1 是原始音高，大于 1 更高更短，小于 1 更低更长
    func play(_ sound: Sound, volume: Float, pitch: Float = 1) {
        guard let buffer = buffers[sound], !voices.isEmpty else { return }
        // 来电等打断之后音频引擎会停下来，这里自动重新启动
        if !engine.isRunning {
            try? engine.start()
        }

        let voice = voices[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voices.count
        voice.player.stop()
        voice.player.volume = volume
        voice.varispeed.rate = pitch
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.player.play()
    }
}
