import Foundation
import AppKit

// MARK: - Resolved Media State

public enum MediaPlaybackResolution: Equatable {
    case playing(track: String, artist: String, source: String, isYouTube: Bool)
    case paused(track: String, artist: String, source: String, isYouTube: Bool)
    case noMedia

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

// MARK: - MediaRemote Bridge (Cached Persistent Dynamic Loader)

final class MediaRemoteBridge: @unchecked Sendable {
    static let shared = MediaRemoteBridge()

    private typealias IsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias InfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var isPlayingFn: IsPlayingFn?
    private var infoFn: InfoFn?

    init() {
        if let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            self.handle = h
            if let sym = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
                self.isPlayingFn = unsafeBitCast(sym, to: IsPlayingFn.self)
            }
            if let sym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
                self.infoFn = unsafeBitCast(sym, to: InfoFn.self)
            }
        }
    }

    deinit {
        if let h = handle {
            dlclose(h)
        }
    }

    struct RawMediaInfo {
        let isPlaying: Bool
        let isPaused: Bool
        let playbackRate: Double?
        let elapsedTime: Double?
        let title: String?
        let artist: String?
        let appDisplayName: String?
    }

    func query() async -> RawMediaInfo {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: RawMediaInfo(
                        isPlaying: false, isPaused: false, playbackRate: nil, elapsedTime: nil, title: nil, artist: nil, appDisplayName: nil
                    ))
                    return
                }

                var isPlaying = false
                var isPaused = false
                var playbackRate: Double?
                var elapsedTime: Double?
                var title: String?
                var artist: String?
                var appDisplayName: String?

                let group = DispatchGroup()

                if let isPlayingFn = self.isPlayingFn {
                    group.enter()
                    isPlayingFn(DispatchQueue.global(qos: .userInitiated)) { playing in
                        isPlaying = playing
                        group.leave()
                    }
                }

                if let infoFn = self.infoFn {
                    group.enter()
                    infoFn(DispatchQueue.global(qos: .userInitiated)) { info in
                        if let t = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !t.isEmpty {
                            title = t
                        }
                        if let a = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String, !a.isEmpty {
                            artist = a
                        }
                        if let app = info["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String, !app.isEmpty {
                            appDisplayName = app
                        }
                        if let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double {
                            playbackRate = rate
                            if rate > 0.0 {
                                isPlaying = true
                            } else if rate == 0.0 && title != nil {
                                isPaused = true
                            }
                        }
                        if let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double {
                            elapsedTime = elapsed
                        }
                        group.leave()
                    }
                }

                // Wait up to 350ms on background thread (never blocks MainActor)
                _ = group.wait(timeout: .now() + 0.35)

                continuation.resume(returning: RawMediaInfo(
                    isPlaying: isPlaying,
                    isPaused: isPaused,
                    playbackRate: playbackRate,
                    elapsedTime: elapsedTime,
                    title: title,
                    artist: artist,
                    appDisplayName: appDisplayName
                ))
            }
        }
    }
}

// MARK: - Media Playback Resolver

public final class MediaPlaybackResolver: @unchecked Sendable {
    public static let shared = MediaPlaybackResolver()

    private var previousState: MediaPlaybackResolution = .noMedia
    private var lastReportedYouTubeTab: String = ""
    private var lastLoggedStatus: String = ""

    private init() {}

    public func resolve() async -> MediaPlaybackResolution {
        // 1. Query System MediaRemote state asynchronously
        let remoteInfo = await MediaRemoteBridge.shared.query()

        // 2. Query Running Applications & Browser Tabs asynchronously
        let appResult = await queryApplicationsAndBrowsers(mediaRemoteInfo: remoteInfo)

        // 3. Reconcile into clear Playback Resolution
        let resolved = reconcile(remoteInfo: remoteInfo, appResult: appResult)

        // 4. Lightweight state transition logging (Requirement 2 & Diagnostics)
        logStateTransition(from: previousState, to: resolved)
        previousState = resolved

        return resolved
    }

    private struct AppQueryResult {
        let isDedicatedAppPlaying: Bool
        let dedicatedAppTrack: String
        let dedicatedAppArtist: String
        let dedicatedAppSource: String

        let hasYouTubeTab: Bool
        let youTubeTabTitle: String
        let youTubeBrowser: String
    }

    private func queryApplicationsAndBrowsers(mediaRemoteInfo: MediaRemoteBridge.RawMediaInfo) async -> AppQueryResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: AppQueryResult(
                        isDedicatedAppPlaying: false, dedicatedAppTrack: "", dedicatedAppArtist: "", dedicatedAppSource: "",
                        hasYouTubeTab: false, youTubeTabTitle: "", youTubeBrowser: ""
                    ))
                    return
                }

                let runningApps = NSWorkspace.shared.runningApplications
                let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })

                // A. Check Dedicated Desktop Music Players (Spotify, Apple Music, VLC)
                if runningBundleIds.contains("com.spotify.client") {
                    let script = """
                    tell application "Spotify"
                        if player state is playing then
                            return (name of current track) & ":::" & (artist of current track)
                        else
                            return ""
                        end if
                    end tell
                    """
                    if let res = self.executeAppleScript(script), !res.isEmpty {
                        let parts = res.components(separatedBy: ":::")
                        continuation.resume(returning: AppQueryResult(
                            isDedicatedAppPlaying: true,
                            dedicatedAppTrack: parts[0],
                            dedicatedAppArtist: parts.count > 1 ? parts[1] : "",
                            dedicatedAppSource: "Spotify",
                            hasYouTubeTab: false,
                            youTubeTabTitle: "",
                            youTubeBrowser: ""
                        ))
                        return
                    }
                }

                if runningBundleIds.contains("com.apple.Music") {
                    let script = """
                    tell application "Music"
                        if player state is playing then
                            return (name of current track) & ":::" & (artist of current track)
                        else
                            return ""
                        end if
                    end tell
                    """
                    if let res = self.executeAppleScript(script), !res.isEmpty {
                        let parts = res.components(separatedBy: ":::")
                        continuation.resume(returning: AppQueryResult(
                            isDedicatedAppPlaying: true,
                            dedicatedAppTrack: parts[0],
                            dedicatedAppArtist: parts.count > 1 ? parts[1] : "",
                            dedicatedAppSource: "Apple Music",
                            hasYouTubeTab: false,
                            youTubeTabTitle: "",
                            youTubeBrowser: ""
                        ))
                        return
                    }
                }

                if runningBundleIds.contains("org.videolan.vlc") {
                    let script = """
                    tell application "VLC"
                        if playing then
                            return (name of current item) & ":::VLC Player"
                        else
                            return ""
                        end if
                    end tell
                    """
                    if let res = self.executeAppleScript(script), !res.isEmpty {
                        let parts = res.components(separatedBy: ":::")
                        continuation.resume(returning: AppQueryResult(
                            isDedicatedAppPlaying: true,
                            dedicatedAppTrack: parts[0],
                            dedicatedAppArtist: "VLC",
                            dedicatedAppSource: "VLC",
                            hasYouTubeTab: false,
                            youTubeTabTitle: "",
                            youTubeBrowser: ""
                        ))
                        return
                    }
                }

                // B. Check Browsers for YouTube tabs (Chrome, Safari, Brave, Edge, Arc)
                var foundYouTubeTab = false
                var ytTitle = ""
                var ytBrowser = ""

                // 1. Google Chrome
                if runningBundleIds.contains("com.google.Chrome") {
                    let script = """
                    tell application "Google Chrome"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" then
                                    return (title of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let title = self.executeAppleScript(script), !title.isEmpty {
                        foundYouTubeTab = true
                        ytTitle = title
                        ytBrowser = "Chrome"
                    }
                }

                // 2. Safari (if not found in Chrome)
                if !foundYouTubeTab && runningBundleIds.contains("com.apple.Safari") {
                    let script = """
                    tell application "Safari"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" or u contains "soundcloud.com" then
                                    return (name of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let title = self.executeAppleScript(script), !title.isEmpty {
                        foundYouTubeTab = true
                        ytTitle = title
                        ytBrowser = "Safari"
                    }
                }

                // 3. Brave Browser
                if !foundYouTubeTab && runningBundleIds.contains("com.brave.Browser") {
                    let script = """
                    tell application "Brave Browser"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" then
                                    return (title of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let title = self.executeAppleScript(script), !title.isEmpty {
                        foundYouTubeTab = true
                        ytTitle = title
                        ytBrowser = "Brave"
                    }
                }

                // 4. Microsoft Edge
                if !foundYouTubeTab && runningBundleIds.contains("com.microsoft.edgemac") {
                    let script = """
                    tell application "Microsoft Edge"
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com/watch" or u contains "music.youtube.com" then
                                    return (title of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let title = self.executeAppleScript(script), !title.isEmpty {
                        foundYouTubeTab = true
                        ytTitle = title
                        ytBrowser = "Edge"
                    }
                }

                continuation.resume(returning: AppQueryResult(
                    isDedicatedAppPlaying: false,
                    dedicatedAppTrack: "",
                    dedicatedAppArtist: "",
                    dedicatedAppSource: "",
                    hasYouTubeTab: foundYouTubeTab,
                    youTubeTabTitle: ytTitle,
                    youTubeBrowser: ytBrowser
                ))
            }
        }
    }

    private func reconcile(
        remoteInfo: MediaRemoteBridge.RawMediaInfo,
        appResult: AppQueryResult
    ) -> MediaPlaybackResolution {
        // Priority 1: Dedicated app is actively playing (Spotify, Apple Music, VLC)
        if appResult.isDedicatedAppPlaying {
            return .playing(
                track: appResult.dedicatedAppTrack,
                artist: appResult.dedicatedAppArtist,
                source: appResult.dedicatedAppSource,
                isYouTube: false
            )
        }

        // Priority 2: YouTube tab detected in browser
        if appResult.hasYouTubeTab {
            let cleanTabTitle = sanitizeTitle(appResult.youTubeTabTitle)

            // Resolve whether YouTube is ACTUALLY PLAYING vs PAUSED vs Idle Tab
            let rate = remoteInfo.playbackRate ?? 0.0
            let isMediaRemoteActive = remoteInfo.isPlaying || rate > 0.0

            // Determine if MediaRemote correlates with YouTube playback:
            // MediaRemote playing flag is true OR playbackRate > 0 OR MediaRemote title matches YouTube
            let isCorrelatedPlayback = isMediaRemoteActive || (rate > 0.0)

            if isCorrelatedPlayback {
                let trackTitle = !cleanTabTitle.isEmpty ? cleanTabTitle : (remoteInfo.title ?? "YouTube Video")
                let artist = remoteInfo.artist ?? "YouTube"
                let source = "YouTube (\(appResult.youTubeBrowser))"
                return .playing(track: trackTitle, artist: artist, source: source, isYouTube: true)
            } else if remoteInfo.isPaused || rate == 0.0 {
                // Verified pause: tab exists and MediaRemote reports paused or rate == 0
                let trackTitle = !cleanTabTitle.isEmpty ? cleanTabTitle : (remoteInfo.title ?? "YouTube Video")
                return .paused(track: trackTitle, artist: "YouTube", source: "YouTube (\(appResult.youTubeBrowser))", isYouTube: true)
            } else {
                // Tab exists, but neither playing nor explicitly paused (idle tab)
                // IMPORTANT: A YouTube tab existing does NOT automatically mean YouTube is playing.
                return .noMedia
            }
        }

        // Priority 3: System-Wide MediaRemote active without specific detected tab
        if remoteInfo.isPlaying || (remoteInfo.playbackRate ?? 0.0) > 0.0 {
            let title = remoteInfo.title ?? "Audio Stream"
            let artist = remoteInfo.artist ?? (remoteInfo.appDisplayName ?? "macOS Media")
            let source = remoteInfo.appDisplayName ?? "macOS Audio"
            return .playing(track: title, artist: artist, source: source, isYouTube: false)
        }

        if remoteInfo.isPaused {
            let title = remoteInfo.title ?? ""
            let artist = remoteInfo.artist ?? ""
            return .paused(track: title, artist: artist, source: "macOS Audio", isYouTube: false)
        }

        return .noMedia
    }

    private func sanitizeTitle(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " - YouTube Music", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func logStateTransition(from old: MediaPlaybackResolution, to new: MediaPlaybackResolution) {
        guard old != new else { return }

        switch (old, new) {
        case (_, .playing(let track, _, let source, let isYouTube)):
            if isYouTube {
                print("[Music] YouTube PLAYING: '\(track)' via \(source)")
                print("[Music] External dance started")
            } else {
                print("[Music] Media PLAYING: '\(track)' via \(source)")
                print("[Music] External dance started")
            }

        case (.playing(_, _, _, let isYouTube), .paused(let track, _, _, _)):
            if isYouTube {
                print("[Music] YouTube PAUSED: '\(track)'")
            } else {
                print("[Music] Media PAUSED: '\(track)'")
            }
            print("[Music] External dance stopped")

        case (.playing(_, _, _, let isYouTube), .noMedia):
            if isYouTube {
                print("[Music] YouTube STOPPED")
            } else {
                print("[Music] Media STOPPED")
            }
            print("[Music] External dance stopped")

        case (.paused, .noMedia):
            break

        case (.noMedia, .paused(let track, _, let source, let isYouTube)):
            if isYouTube {
                print("[Music] YouTube detected (paused): '\(track)' in \(source)")
            }

        default:
            break
        }
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
}
