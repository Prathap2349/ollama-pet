import Foundation
import AudioToolbox
import AVFoundation

public enum SoundEffect {
    case send
    case receive
    case click
    case wake
    case alert
    case success

    public func play() {
        switch self {
        case .send:
            playSystemSound(1004) // Navigation or subtle pop
        case .receive:
            playSystemSound(1003) // Message received chime
        case .click:
            playSystemSound(1104) // Tock
        case .wake:
            playSystemSound(1000) // Mail sound
        case .alert:
            playSystemSound(1005) // Alert tone
        case .success:
            playSystemSound(1001) // Positive chime
        }
    }

    private func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
