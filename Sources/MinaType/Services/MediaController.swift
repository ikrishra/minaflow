import AppKit
import AudioToolbox
import CoreAudio
import Foundation

// MARK: - MediaController
// Manages acoustic feedback prevention during voice dictation.
//
// Behavior:
// 1. Built-in MacBook Speakers: Mutes hardware speaker output (<1ms) via CoreAudio mute bit during dictation
//    so speaker audio does not bleed into the built-in microphone. Unmutes instantly on completion.
// 2. Earphones, AirPods & Bluetooth: NEVER touched or muted.
//    Headphones direct audio into the user's ears (zero mic bleed) and manipulating Bluetooth volume
//    breaks macOS AVRCP / A2DP audio routes, causing media to remain muted.

final class MediaController {
    static let shared = MediaController()

    private var isMutedByUs = false
    private let stateQueue = DispatchQueue(label: "minaflow.media.controller")

    private init() {}

    // MARK: - Public API

    /// Call this the instant the trigger is pressed, before startRecording().
    func muteNow() {
        stateQueue.sync {
            // When user is wearing Bluetooth headphones, AirPods, or wired earphones, DO NOT mute or touch volume!
            if SystemAudio.isBluetoothOrHeadphones() {
                return
            }

            // Built-in speakers only: apply hardware CoreAudio mute
            if SystemAudio.setDeviceMuted(true) {
                self.isMutedByUs = true
            }
        }
    }

    /// Call this immediately when dictation recording or processing finishes.
    func unmuteNow() {
        stateQueue.sync {
            if isMutedByUs {
                isMutedByUs = false
                SystemAudio.setDeviceMuted(false)
            }
        }
    }

    /// Emergency restore on app exit or error.
    func emergencyUnmute() {
        unmuteNow()
    }
}

// MARK: - SystemAudio Helpers
private enum SystemAudio {

    /// Checks if the current default output device is Bluetooth, AirPods, or Headphones.
    static func isBluetoothOrHeadphones() -> Bool {
        guard let id = defaultOutputDeviceID() else { return false }

        // 1. Check Transport Type (Bluetooth, Bluetooth LE, AirPlay)
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var transportAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(id, &transportAddr) &&
           AudioObjectGetPropertyData(id, &transportAddr, 0, nil, &size, &transportType) == noErr {
            if transportType == kAudioDeviceTransportTypeBluetooth ||
               transportType == kAudioDeviceTransportTypeBluetoothLE ||
               transportType == kAudioDeviceTransportTypeAirPlay {
                return true
            }
        }

        // 2. Check Data Source (e.g. wired headphones in 3.5mm jack: 'hdpn' or 'head')
        var sourceID: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var sourceAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(id, &sourceAddr) &&
           AudioObjectGetPropertyData(id, &sourceAddr, 0, nil, &size, &sourceID) == noErr {
            let hdpn: UInt32 = 0x6864706e // 'hdpn'
            let head: UInt32 = 0x68656164 // 'head'
            if sourceID == hdpn || sourceID == head {
                return true
            }
        }

        // 3. Check if device supports hardware CoreAudio mute bit
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &muteAddr) else {
            // If the output device has no hardware mute property, treat it as external/headphones and DO NOT touch it
            return true
        }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &muteAddr, &settable)
        guard settable.boolValue else {
            return true
        }

        return false
    }

    // MARK: - CoreAudio Device Mute (Internal Speakers)

    static func isDeviceMuted() -> Bool {
        guard let id = defaultOutputDeviceID() else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &addr) else { return false }
        return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &muted) == noErr && muted == 1
    }

    @discardableResult
    static func setDeviceMuted(_ muted: Bool) -> Bool {
        guard let id = defaultOutputDeviceID() else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &addr) else { return false }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &addr, &settable)
        guard settable.boolValue else { return false }
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    // MARK: - Shared Output Device Resolution

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        var id: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id
        ) == noErr, id != kAudioObjectUnknown else { return nil }
        return id
    }
}
