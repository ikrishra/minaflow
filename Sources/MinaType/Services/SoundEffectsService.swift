import AppKit
import AudioToolbox

public class SoundEffectsService {
    public static let shared = SoundEffectsService()

    private init() {}

    public func playStart() {
        guard ConfigManager.shared.config.isSoundEffectsEnabled else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            if let sound = NSSound(named: "Tink") {
                sound.volume = 0.6
                sound.play()
            } else {
                AudioServicesPlaySystemSound(1057) // Fallback Tink sound ID
            }
        }
    }

    public func playSuccess() {
        guard ConfigManager.shared.config.isSoundEffectsEnabled else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            if let sound = NSSound(named: "Pop") {
                sound.volume = 0.6
                sound.play()
            } else if let sound = NSSound(named: "Hero") {
                sound.volume = 0.5
                sound.play()
            }
        }
    }
}
