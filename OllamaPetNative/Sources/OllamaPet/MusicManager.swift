import Foundation
import AVFoundation
import AppKit

public enum BeatIntensity: String {
    case low
    case medium
    case strong
    case beatDrop
}

@MainActor
public class MusicManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = MusicManager()

    @Published public var isPlaying: Bool = false
    @Published public var trackTitle: String = ""
    @Published public var beatLevels: [CGFloat] = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
    @Published public var currentVibe: String = "pop"

    // Beat-level Reactivity
    @Published public var currentBeatAmplitude: CGFloat = 0.0
    @Published public var currentBeatIntensity: BeatIntensity = .low

    // Media Awareness (Spotify & Apple Music)
    @Published public var isMediaDetectionEnabled: Bool = false
    @Published public var danceWhenMusicDetected: Bool = true
    @Published public var isMediaPlaying: Bool = false
    @Published public var mediaTrackTitle: String = ""
    @Published public var mediaArtist: String = ""

    private var audioPlayer: AVAudioPlayer?
    private var meterTimer: Timer?
    private var mediaPollTimer: Timer?
    private var lastAnnouncedTrack: String = ""

    public override init() {
        super.init()
        let data = DataManager.shared.savedData
        self.isMediaDetectionEnabled = data.mediaDetectionEnabled ?? false
        self.danceWhenMusicDetected = data.danceWhenMusicDetected ?? true

        if self.isMediaDetectionEnabled {
            startMediaDetection()
        }
    }

    public func setMediaDetectionEnabled(_ enabled: Bool) {
        self.isMediaDetectionEnabled = enabled
        DataManager.shared.savedData.mediaDetectionEnabled = enabled
        DataManager.shared.saveData()

        if enabled {
            startMediaDetection()
        } else {
            stopMediaDetection()
        }
    }

    public func setDanceWhenMusicDetected(_ enabled: Bool) {
        self.danceWhenMusicDetected = enabled
        DataManager.shared.savedData.danceWhenMusicDetected = enabled
        DataManager.shared.saveData()
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
        currentBeatAmplitude = 0.0
        currentBeatIntensity = .low
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

                let avgAmp = newLevels.reduce(0, +) / CGFloat(newLevels.count)
                self.currentBeatAmplitude = avgAmp

                if avgAmp > 0.85 {
                    self.currentBeatIntensity = .beatDrop
                } else if avgAmp > 0.6 {
                    self.currentBeatIntensity = .strong
                } else if avgAmp > 0.3 {
                    self.currentBeatIntensity = .medium
                } else {
                    self.currentBeatIntensity = .low
                }
            }
        }
    }

    public func setVibe(_ vibe: String) {
        currentVibe = vibe
    }

    // MARK: - Safe Media Awareness (Spotify & Apple Music via standard AppleScript)

    private func startMediaDetection() {
        mediaPollTimer?.invalidate()
        mediaPollTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollActiveMediaPlayback()
            }
        }
    }

    private func stopMediaDetection() {
        mediaPollTimer?.invalidate()
        mediaPollTimer = nil
        isMediaPlaying = false
        mediaTrackTitle = ""
        mediaArtist = ""
    }

    private func pollActiveMediaPlayback() {
        guard isMediaDetectionEnabled else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        let hasSpotify = runningApps.contains(where: { $0.bundleIdentifier == "com.spotify.client" })
        let hasAppleMusic = runningApps.contains(where: { $0.bundleIdentifier == "com.apple.Music" })

        if hasSpotify {
            let scriptSource = """
            tell application "Spotify"
                if player state is playing then
                    return (name of current track) & ":::" & (artist of current track)
                else
                    return ""
                end if
            end tell
            """
            if let result = executeAppleScript(scriptSource), !result.isEmpty {
                handleMediaPlaybackDetected(result)
                return
            }
        }

        if hasAppleMusic {
            let scriptSource = """
            tell application "Music"
                if player state is playing then
                    return (name of current track) & ":::" & (artist of current track)
                else
                    return ""
                end if
            end tell
            """
            if let result = executeAppleScript(scriptSource), !result.isEmpty {
                handleMediaPlaybackDetected(result)
                return
            }
        }

        if isMediaPlaying {
            isMediaPlaying = false
            mediaTrackTitle = ""
            mediaArtist = ""
        }
    }

    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if errorInfo == nil, let stringValue = result.stringValue {
            return stringValue
        }
        return nil
    }

    private func handleMediaPlaybackDetected(_ payload: String) {
        let parts = payload.components(separatedBy: ":::")
        let track = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let artist = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

        guard !track.isEmpty else { return }

        let changed = (track != mediaTrackTitle)
        self.isMediaPlaying = true
        self.mediaTrackTitle = track
        self.mediaArtist = artist

        if changed && track != lastAnnouncedTrack {
            lastAnnouncedTrack = track
            let subtitle = artist.isEmpty ? track : "\(track) — \(artist)"
            PetState.shared.showBubble("♪ \(subtitle)", duration: 4.0)

            if danceWhenMusicDetected {
                PetState.shared.setTemporaryMood(.excited, duration: 6.0)
            }
        }
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
