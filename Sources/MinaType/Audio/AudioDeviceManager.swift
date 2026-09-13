import Foundation
import CoreAudio
import AudioToolbox

public struct AudioInputDevice: Identifiable, Hashable {
    public let id: AudioDeviceID
    public let name: String

    public init(id: AudioDeviceID, name: String) {
        self.id = id
        self.name = name
    }

    public var displayLabel: String {
        let lower = name.lowercased()
        if lower.contains("built-in") || lower.contains("macbook") || lower.contains("internal") {
            return "\(name) (recommended)"
        }
        if lower.contains("bluetooth") || lower.contains("airpod") || lower.contains("buds") || lower.contains("headset") {
            return "\(name) (Bluetooth)"
        }
        if lower.contains("blackhole") || lower.contains("soundflower") || lower.contains("virtual") || lower.contains("nomachine") || lower.contains("zoom") {
            return "\(name) (Virtual)"
        }
        return name
    }
}

public class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()

    @Published public var inputDevices: [AudioInputDevice] = []
    @Published public var currentInputDeviceID: AudioDeviceID = 0

    public init() {
        refreshDevices()
    }

    public var currentDeviceName: String {
        inputDevices.first(where: { $0.id == currentInputDeviceID })?.name ?? "Default Microphone"
    }

    public func refreshDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return }
        let count = Int(propertySize / UInt32(MemoryLayout<AudioDeviceID>.size))
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs) == noErr else { return }

        var list: [AudioInputDevice] = []
        for id in deviceIDs {
            var scopeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &scopeAddress, 0, nil, &streamSize)
            if streamSize > 0 {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var unmanagedName: Unmanaged<CFString>?
                var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                if AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &unmanagedName) == noErr,
                   let cfStr = unmanagedName?.takeRetainedValue() {
                    let devName = cfStr as String
                    list.append(AudioInputDevice(id: id, name: devName))
                }
            }
        }

        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var currentID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &size, &currentID)

        DispatchQueue.main.async {
            self.inputDevices = list
            self.currentInputDeviceID = currentID
        }
    }

    public func setDefaultInputDevice(id: AudioDeviceID) {
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var newID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, size, &newID)
        if status == noErr {
            DispatchQueue.main.async {
                self.currentInputDeviceID = id
            }
        }
    }
}
