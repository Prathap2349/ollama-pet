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

    // Beat-level Reactivity (Local Audio Engine)
    @Published public var currentBeatAmplitude: CGFloat = 0.0
    @Published public var currentBeatIntensity: BeatIntensity = .low
    @Published public var isBeatAnalysisAvailable: Bool = false
    @Published public var currentEnergyLevel: MediaEnergyLevel = .low

    // Media Pipeline & State Machine (Requirement 1)
    @Published public var mediaState: MediaPlaybackState = .noMedia
    @Published public var isMediaDetectionEnabled: Bool = true
    @Published public var danceWhenMusicDetected: Bool = true
    @Published public var isMediaPlaying: Bool = false
    @Published public var mediaTrackTitle: String = ""
    @Published public var mediaArtist: String = ""
    @Published public var mediaSource: String = "None"

    private var audioPlayer: AVAudioPlayer?
    private var meterTimer: Timer?
    private var mediaPollTimer: Timer?
    private var lastAnnouncedTrack: String = ""
    private var reactionTask: Task<Void, Never>?
    private var isReacting: Bool = false

    public override init() {
        super.init()
        let data = DataManager.shared.savedData
        self.isMediaDetectionEnabled = data.mediaDetectionEnabled ?? true
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

    // MARK: - Local Audio Player (Real Audio Metering & Beat Analysis)

    public func loadAndPlay(fileURL: URL) {
        stop()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            trackTitle = fileURL.lastPathComponent
            isBeatAnalysisAvailable = true
            transitionMediaState(to: .playing, track: trackTitle, artist: "Local Audio", source: "Local File")

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
            transitionMediaState(to: .paused, track: trackTitle, artist: "Local Audio", source: "Local File")
        } else {
            player.play()
            isPlaying = true
            transitionMediaState(to: .playing, track: trackTitle, artist: "Local Audio", source: "Local File")
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
        isBeatAnalysisAvailable = false
        currentEnergyLevel = .low
        transitionMediaState(to: .noMedia)
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer, player.isPlaying else { return }
                player.updateMeters()
                let avg = player.averagePower(forChannel: 0)
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
                    self.currentEnergyLevel = .high
                } else if avgAmp > 0.6 {
                    self.currentBeatIntensity = .strong
                    self.currentEnergyLevel = .high
                } else if avgAmp > 0.3 {
                    self.currentBeatIntensity = .medium
                    self.currentEnergyLevel = .medium
                } else {
                    self.currentBeatIntensity = .low
                    self.currentEnergyLevel = .low
                }
            }
        }
    }

    public func setVibe(_ vibe: String) {
        currentVibe = vibe
    }

    // MARK: - Multi-Source Media Detection (YouTube, Spotify, Apple Music, VLC, MediaRemote)

    private func startMediaDetection() {
        mediaPollTimer?.invalidate()
        // Responsive 0.8s polling interval (non-blocking async resolution)
        mediaPollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollActiveMediaPlayback()
            }
        }
    }

    private func stopMediaDetection() {
        mediaPollTimer?.invalidate()
        mediaPollTimer = nil
        reactionTask?.cancel()
        reactionTask = nil
        isReacting = false
        transitionMediaState(to: .noMedia)
    }

    private func pollActiveMediaPlayback() async {
        guard isMediaDetectionEnabled else { return }

        // If local audio player is playing, local takes precedence
        if let player = audioPlayer, player.isPlaying {
            return
        }

        let resolution = await MediaPlaybackResolver.shared.resolve()

        switch resolution {
        case .playing(let track, let artist, let source, _):
            let activeTrack = track.isEmpty ? (mediaTrackTitle.isEmpty ? "Audio Stream" : mediaTrackTitle) : track
            let activeArtist = artist.isEmpty ? mediaArtist : artist
            let activeSource = source.isEmpty ? (mediaSource.isEmpty ? "macOS Media" : mediaSource) : source

            if mediaState != .playing || (activeTrack != mediaTrackTitle && !activeTrack.isEmpty) {
                transitionMediaState(to: .playing, track: activeTrack, artist: activeArtist, source: activeSource)
            } else if danceWhenMusicDetected && (reactionTask == nil || !isReacting) {
                startExternalBeatClock()
                triggerMusicStartReaction(track: activeTrack, artist: activeArtist, source: activeSource)
            }

        case .paused(let track, let artist, let source, _):
            if mediaState == .playing {
                transitionMediaState(to: .paused, track: track, artist: artist, source: source)
            }

        case .noMedia:
            if mediaState != .noMedia {
                transitionMediaState(to: .noMedia)
            }
        }
    }

    // MARK: - Media State Machine & Reaction Pipeline (Requirements 5, 6, 7)

    private func transitionMediaState(to newState: MediaPlaybackState, track: String = "", artist: String = "", source: String = "") {
        let oldState = mediaState
        guard oldState != newState || (newState == .playing && track != mediaTrackTitle && !track.isEmpty) else {
            return
        }

        self.mediaState = newState
        self.isMediaPlaying = (newState == .playing)
        self.mediaTrackTitle = track
        self.mediaArtist = artist
        self.mediaSource = source

        switch (oldState, newState) {
        case (.noMedia, .playing), (.paused, .playing), (.unknown, .playing):
            // Sequence: NO_MEDIA/PAUSED -> PLAYING -> DANCE (resilient to priority conflicts)
            startExternalBeatClock()
            triggerMusicStartReaction(track: track, artist: artist, source: source)

        case (.playing, .paused):
            // Sequence: PLAYING -> PAUSED -> RELAXED
            stopExternalBeatClock()
            triggerMusicPauseReaction()

        case (.playing, .noMedia):
            // Sequence: PLAYING -> NO_MEDIA -> RELAXED
            stopExternalBeatClock()
            triggerMusicStopReaction()

        default:
            break
        }
    }

    private func triggerMusicStartReaction(track: String, artist: String, source: String) {
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            isReacting = true
            defer { isReacting = false }

            let cleanTrack = track
                .replacingOccurrences(of: " - YouTube", with: "")
                .replacingOccurrences(of: " - YouTube Music", with: "")
            let subtitle = artist.isEmpty ? cleanTrack : "\(cleanTrack) — \(artist)"

            if !cleanTrack.isEmpty && cleanTrack != lastAnnouncedTrack && !PetState.shared.isChatOpen && !VoiceAssistant.shared.isSpeaking {
                lastAnnouncedTrack = cleanTrack
                let badge = source.contains("YouTube") ? "📺 ♪" : "♪"
                PetState.shared.showBubble("\(badge) \(subtitle)", duration: 4.5)
            }

            // Immediately engage dance state so 3D character enters its choreography
            if danceWhenMusicDetected {
                PetState.shared.currentMood = .happy

                // Continuous dance loop while media is active (Requirements 5, 6, 7)
                while !Task.isCancelled && (self.isMediaPlaying || self.isPlaying) && self.danceWhenMusicDetected {
                    let isVoiceSpeaking = VoiceAssistant.shared.isSpeaking
                    let priority = PetState.shared.activeEventPriority

                    // Priority guard: yield immediately during higher priority activities or speech
                    if priority > .musicReaction ||
                       PetState.shared.isChatOpen ||
                       PetState.shared.isThinking ||
                       isVoiceSpeaking ||
                       FocusGuardian.shared.isSessionActive {
                        if isVoiceSpeaking {
                            // Speech temporarily has priority: visually distinct talking state (Requirement 6)
                            if PetState.shared.animState != .watchUser {
                                PetState.shared.animState = .watchUser
                            }
                        } else if PetState.shared.animState == .dance {
                            PetState.shared.animState = .idle
                        }
                    } else {
                        // Resume dance when speech/chat finishes while music is still playing (Requirement 5 & 6)
                        if PetState.shared.animState != .dance && PetState.shared.animState != .walk {
                            PetState.shared.animState = .dance
                        }
                    }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }

                // Gracefully finish motion when stopped or paused
                if PetState.shared.animState == .dance {
                    PetState.shared.animState = .idle
                    PetState.shared.setTemporaryMood(.relaxed, duration: 3.0)
                }
            } else {
                PetState.shared.setTemporaryMood(.relaxed, duration: 3.0)
            }
        }
    }

    private func triggerMusicPauseReaction() {
        reactionTask?.cancel()
        reactionTask = nil
        isReacting = false
        stopExternalBeatClock()
        if PetState.shared.animState == .dance {
            PetState.shared.animState = .idle
        }
        PetState.shared.setTemporaryMood(.relaxed, duration: 3.0)
    }

    private func triggerMusicStopReaction() {
        reactionTask?.cancel()
        reactionTask = nil
        isReacting = false
        stopExternalBeatClock()
        if PetState.shared.animState == .dance {
            PetState.shared.animState = .idle
        }
        PetState.shared.setTemporaryMood(.relaxed, duration: 3.0)
    }

    // MARK: - Deterministic External Rhythm Clock (~118 BPM / 2.0 Hz)

    private var externalBeatTimer: Timer?

    private func startExternalBeatClock() {
        externalBeatTimer?.invalidate()
        let bpm: Double = 118.0
        let beatInterval = 60.0 / bpm // ~0.508s
        let frameInterval = 0.05
        var phase: Double = 0.0

        externalBeatTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isMediaPlaying && !(self.audioPlayer?.isPlaying ?? false) else {
                    return
                }
                phase += frameInterval
                let beatCycle = sin(phase * (2.0 * .pi / beatInterval))
                let normalized = max(0.2, CGFloat((beatCycle + 1.0) / 2.0))

                var newLevels: [CGFloat] = []
                for i in 0..<8 {
                    let lag = Double(i) * 0.06
                    let barCycle = sin((phase - lag) * (2.0 * .pi / beatInterval))
                    let barNorm = max(0.15, min(1.0, CGFloat((barCycle + 1.0) / 2.0 * 0.85 + Double.random(in: 0.05...0.15))))
                    newLevels.append(barNorm)
                }
                self.beatLevels = newLevels
                self.currentBeatAmplitude = normalized
                self.currentBeatIntensity = normalized > 0.75 ? .strong : (normalized > 0.45 ? .medium : .low)
                self.currentEnergyLevel = normalized > 0.65 ? .high : .medium
            }
        }
    }

    private func stopExternalBeatClock() {
        externalBeatTimer?.invalidate()
        externalBeatTimer = nil
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
