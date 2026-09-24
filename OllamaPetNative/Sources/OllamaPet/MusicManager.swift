import Foundation
import AVFoundation

@MainActor
public class MusicManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = MusicManager()

    @Published public var isPlaying: Bool = false
    @Published public var trackTitle: String = ""
    @Published public var beatLevels: [CGFloat] = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
    @Published public var currentVibe: String = "pop"

    private var audioPlayer: AVAudioPlayer?
    private var meterTimer: Timer?

    public override init() {
        super.init()
    }

    public func loadAndPlay(fileURL: URL) {
        stop()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.numberOfLoops = -1 // loop
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            trackTitle = fileURL.lastPathComponent

            startMetering()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            stop()
        }
    }

    public func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            meterTimer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startMetering()
        }
    }

    public func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        trackTitle = ""
        beatLevels = Array(repeating: 0.1, count: 8)
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer, player.isPlaying else { return }
                player.updateMeters()
                let avg = player.averagePower(forChannel: 0) // -160 to 0 dB
                let normalized = max(0.1, min(1.0, CGFloat((avg + 50) / 50)))

                var newLevels: [CGFloat] = []
                for i in 0..<8 {
                    let jitter = CGFloat.random(in: -0.15...0.15)
                    let scale = (1.0 - CGFloat(i) * 0.07)
                    let val = max(0.1, min(1.0, (normalized * scale) + jitter))
                    newLevels.append(val)
                }
                self.beatLevels = newLevels
            }
        }
    }

    public func setVibe(_ vibe: String) {
        currentVibe = vibe
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
