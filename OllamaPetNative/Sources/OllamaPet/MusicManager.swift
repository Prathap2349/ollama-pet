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
        // Poll every 2.0s for responsive reaction
        mediaPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollActiveMediaPlayback()
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

    private func pollActiveMediaPlayback() {
        guard isMediaDetectionEnabled else { return }

        // If local audio player is playing, local takes precedence
        if let player = audioPlayer, player.isPlaying {
            return
        }

        // 1. Check System-Wide MediaRemote framework (Detects anything playing across macOS)
        let remoteResult = queryMediaRemote()

        // 2. Check Browser & Application specific metadata
        let appMetadata = queryActiveApplications()

        let isActuallyPlaying = remoteResult.isPlaying || appMetadata.isPlaying
        let track = appMetadata.title.isEmpty ? (remoteResult.title ?? "") : appMetadata.title
        let artist = appMetadata.artist.isEmpty ? (remoteResult.artist ?? "") : appMetadata.artist
        let source = appMetadata.source.isEmpty ? (isActuallyPlaying ? "macOS Media" : "") : appMetadata.source

        if isActuallyPlaying && !track.isEmpty {
            transitionMediaState(to: .playing, track: track, artist: artist, source: source)
        } else if isActuallyPlaying {
            // Media is playing but title unavailable
            transitionMediaState(to: .playing, track: "Audio Stream", artist: "", source: "System Audio")
        } else if mediaState == .playing {
            // It was playing, now stopped or paused
            if remoteResult.isPaused {
                transitionMediaState(to: .paused, track: track, artist: artist, source: source)
            } else {
                transitionMediaState(to: .noMedia)
            }
        }
    }

    // MARK: - Media State Machine & Reaction Pipeline (Requirement 1)

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

        // Check Event Priority: Yield to user interaction or focus sessions
        if PetState.shared.activeEventPriority > .musicReaction {
            return
        }

        switch (oldState, newState) {
        case (.noMedia, .playing), (.paused, .playing), (.unknown, .playing):
            // Sequence: NO_MEDIA -> PLAYING -> CURIOUS -> EXCITED -> DANCE
            triggerMusicStartReaction(track: track, artist: artist, source: source)

        case (.playing, .paused):
            // Sequence: PLAYING -> PAUSED -> RELAXED
            triggerMusicPauseReaction()

        case (.playing, .noMedia):
            // Sequence: PLAYING -> NO_MEDIA -> RELAXED
            triggerMusicStopReaction()

        default:
            break
        }
    }

    private func triggerMusicStartReaction(track: String, artist: String, source: String) {
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            isReacting = true
            let cleanTrack = track
                .replacingOccurrences(of: " - YouTube", with: "")
                .replacingOccurrences(of: " - YouTube Music", with: "")
            let subtitle = artist.isEmpty ? cleanTrack : "\(cleanTrack) — \(artist)"

            if !cleanTrack.isEmpty && cleanTrack != lastAnnouncedTrack {
                lastAnnouncedTrack = cleanTrack
                let badge = source.contains("YouTube") ? "📺 ♪" : "♪"
                PetState.shared.showBubble("\(badge) \(subtitle)", duration: 4.5)
            }

            // Step 1: CURIOUS (1.5s) - Head tilt, attentive listening
            PetState.shared.setTemporaryMood(.curious, duration: 1.5)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }

            // Step 2: EXCITED (2.0s) - Happy recognition, smile
            PetState.shared.setTemporaryMood(.excited, duration: 2.0)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            // Step 3: DANCE (8.0s) - If dance setting is enabled
            if danceWhenMusicDetected {
                PetState.shared.animState = .dance
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }

                // Gracefully return to joyful/relaxed groove rather than infinite dancing
                if PetState.shared.animState == .dance {
                    PetState.shared.animState = .idle
                    PetState.shared.setTemporaryMood(.joyful, duration: 4.0)
                }
            } else {
                PetState.shared.setTemporaryMood(.relaxed, duration: 4.0)
            }
            isReacting = false
        }
    }

    private func triggerMusicPauseReaction() {
        reactionTask?.cancel()
        isReacting = false
        if PetState.shared.animState == .dance {
            PetState.shared.animState = .idle
        }
        PetState.shared.setTemporaryMood(.relaxed, duration: 4.0)
    }

    private func triggerMusicStopReaction() {
        reactionTask?.cancel()
        isReacting = false
        if PetState.shared.animState == .dance {
            PetState.shared.animState = .idle
        }
        PetState.shared.setTemporaryMood(.relaxed, duration: 3.0)
    }

    // MARK: - System-Wide MediaRemote Dynamic Loader

    private struct MediaRemoteResult {
        let isPlaying: Bool
        let isPaused: Bool
        let title: String?
        let artist: String?
    }

    private func queryMediaRemote() -> MediaRemoteResult {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return MediaRemoteResult(isPlaying: false, isPaused: false, title: nil, artist: nil)
        }
        defer { dlclose(handle) }

        var isPlaying = false
        var isPaused = false
        var title: String?
        var artist: String?

        typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            let fn = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self)
            let sem = DispatchSemaphore(value: 0)
            fn(DispatchQueue.global(qos: .userInitiated)) { playing in
                isPlaying = playing
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 0.15)
        }

        typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            let fn = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            let sem = DispatchSemaphore(value: 0)
            fn(DispatchQueue.global(qos: .userInitiated)) { info in
                if let t = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !t.isEmpty {
                    title = t
                }
                if let a = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String, !a.isEmpty {
                    artist = a
                }
                if let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double {
                    if rate == 0.0 && title != nil {
                        isPaused = true
                    }
                }
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 0.15)
        }

        return MediaRemoteResult(isPlaying: isPlaying, isPaused: isPaused, title: title, artist: artist)
    }

    // MARK: - Browser & Media Player Inspection (YouTube in Chrome/Safari/Brave/Edge, Spotify, Music, VLC)

    private struct AppMediaResult {
        let isPlaying: Bool
        let title: String
        let artist: String
        let source: String
    }

    private func queryActiveApplications() -> AppMediaResult {
        let runningApps = NSWorkspace.shared.runningApplications

        // 1. Spotify
        if runningApps.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) {
            let script = """
            tell application "Spotify"
                if player state is playing then
                    return (name of current track) & ":::" & (artist of current track)
                else
                    return ""
                end if
            end tell
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: p.count > 1 ? p[1] : "", source: "Spotify")
            }
        }

        // 2. Apple Music
        if runningApps.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            let script = """
            tell application "Music"
                if player state is playing then
                    return (name of current track) & ":::" & (artist of current track)
                else
                    return ""
                end if
            end tell
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: p.count > 1 ? p[1] : "", source: "Apple Music")
            }
        }

        // 3. VLC
        if runningApps.contains(where: { $0.bundleIdentifier == "org.videolan.vlc" }) {
            let script = """
            tell application "VLC"
                if playing then
                    return (name of current item) & ":::VLC"
                else
                    return ""
                end if
            end tell
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: "VLC Player", source: "VLC")
            }
        }

        // 4. Google Chrome (YouTube Tabs)
        if runningApps.contains(where: { $0.bundleIdentifier == "com.google.Chrome" }) {
            let script = """
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" then
                            return (title of t) & ":::YouTube"
                        end if
                    end repeat
                end repeat
            end tell
            return ""
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: "YouTube", source: "YouTube (Chrome)")
            }
        }

        // 5. Safari (YouTube Tabs)
        if runningApps.contains(where: { $0.bundleIdentifier == "com.apple.Safari" }) {
            let script = """
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" then
                            return (name of t) & ":::YouTube"
                        end if
                    end repeat
                end repeat
            end tell
            return ""
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: "YouTube", source: "YouTube (Safari)")
            }
        }

        // 6. Brave Browser (YouTube Tabs)
        if runningApps.contains(where: { $0.bundleIdentifier == "com.brave.Browser" }) {
            let script = """
            tell application "Brave Browser"
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com/watch" or u contains "music.youtube.com" then
                            return (title of t) & ":::YouTube"
                        end if
                    end repeat
                end repeat
            end tell
            return ""
            """
            if let res = executeAppleScript(script), !res.isEmpty {
                let p = res.components(separatedBy: ":::")
                return AppMediaResult(isPlaying: true, title: p[0], artist: "YouTube", source: "YouTube (Brave)")
            }
        }

        return AppMediaResult(isPlaying: false, title: "", artist: "", source: "")
    }

    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if errorInfo == nil, let stringValue = result.stringValue, !stringValue.isEmpty {
            return stringValue
        }
        return nil
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
