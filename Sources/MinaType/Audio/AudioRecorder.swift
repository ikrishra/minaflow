import Foundation
import AVFoundation

public protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidUpdateLevel(_ level: Float) // 0.0 to 1.0 normalized
}

public class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    public static let shared = AudioRecorder()

    public weak var delegate: AudioRecorderDelegate?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let recordingURL: URL
    private var maxAudioLevel: Float = 0.0
    private var recordingStartTime: Date?

    public private(set) var isRecording = false

    override private init() {
        let tempDir = FileManager.default.temporaryDirectory
        self.recordingURL = tempDir.appendingPathComponent("minatype_recording.wav")
        super.init()
    }

    public func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func startMeteringTest(onLevel: @escaping (Float) -> Void) {
        stopRecordingCleanup()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("minatype_meter_test.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        do {
            recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let rec = self.recorder, rec.isRecording else { return }
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                let normalized = max(0.0, min(1.0, (power + 50.0) / 50.0))
                onLevel(normalized)
            }
        } catch {
            print("[AudioRecorder] Metering test failed: \(error)")
        }
    }

    public func stopMeteringTest() {
        stopRecordingCleanup()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("minatype_meter_test.wav")
        try? FileManager.default.removeItem(at: tempURL)
    }

    public func startRecording() throws {
        stopRecordingCleanup()

        // 1. Verify microphone permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            throw NSError(domain: "MinaFlowAudio", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Microphone access denied. Please allow MinaFlow in System Settings > Privacy & Security > Microphone."
            ])
        }

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }

        // 2. 16kHz 16-bit Mono PCM WAV
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        if FileManager.default.fileExists(atPath: recordingURL.path) {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true

        guard recorder?.record() == true else {
            throw NSError(domain: "MinaTypeAudio", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not start audio recording. Check your microphone input device."
            ])
        }

        isRecording = true
        maxAudioLevel = 0.0
        recordingStartTime = Date()
        logMessage("Recording started at \(recordingURL.path)")

        // 3. Metering timer for live UI waveform animation
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let rec = self.recorder, rec.isRecording else { return }
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0) // -160 dB to 0 dB
            // Scale -50dB to 0dB into 0.0 -> 1.0
            let normalized = max(0.0, min(1.0, (power + 50.0) / 50.0))
            if normalized > self.maxAudioLevel {
                self.maxAudioLevel = normalized
            }
            self.delegate?.audioRecorderDidUpdateLevel(normalized)
        }
    }

    public private(set) var lastPeakLevel: Float = 0.0

    public func stopRecording() -> URL? {
        guard isRecording, let rec = recorder else { return nil }

        rec.stop()
        self.recorder = nil // Instantly release audio unit & microphone hardware so system audio profile restores immediately
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        lastPeakLevel = maxAudioLevel

        // Check if recording was too short (< 0.35s tap) or silent
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        if duration < 0.35 {
            logMessage("Recording tap too short (\(String(format: "%.2f", duration))s < 0.35s). Ignored.")
            try? FileManager.default.removeItem(at: recordingURL)
            return nil
        }

        if maxAudioLevel < 0.14 {
            logMessage("Silence detected (peak: \(String(format: "%.2f", maxAudioLevel)) < 0.14). Ignored.")
            try? FileManager.default.removeItem(at: recordingURL)
            return nil
        }

        if FileManager.default.fileExists(atPath: recordingURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: recordingURL.path),
               let size = attrs[.size] as? UInt64 {
                logMessage("Recording raw capture finished. File size: \(size) bytes, peak: \(maxAudioLevel)")
                if size > 1000 {
                    // Apply acoustic silence and dead-air trimming
                    return trimSilence(at: recordingURL)
                }
            }
        }
        logMessage("Recording empty or missing.")
        return nil
    }

    /// Trims leading and trailing low-energy audio frames (VAD-style) to prevent Whisper hallucination loops
    private func trimSilence(at url: URL) -> URL? {
        guard let data = try? Data(contentsOf: url), data.count > 44 else { return nil }

        var dataOffset = 44
        if let dataRange = data.range(of: "data".data(using: .utf8)!) {
            dataOffset = dataRange.upperBound + 4
        }
        guard data.count > dataOffset else { return nil }

        let pcmData = data.subdata(in: dataOffset..<data.count)
        let sampleCount = pcmData.count / 2
        guard sampleCount > 0 else { return nil }

        var samples = [Int16](repeating: 0, count: sampleCount)
        _ = samples.withUnsafeMutableBytes { pcmData.copyBytes(to: $0) }

        // 20ms frame = 320 samples at 16kHz
        let frameSize = 320
        let frameCount = sampleCount / frameSize
        guard frameCount > 0 else { return url }

        var frameEnergies = [Double](repeating: 0.0, count: frameCount)
        var maxEnergy: Double = 0.0

        for f in 0..<frameCount {
            var sumSquares: Double = 0.0
            let start = f * frameSize
            for i in 0..<frameSize {
                let sample = Double(samples[start + i])
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Double(frameSize))
            frameEnergies[f] = rms
            if rms > maxEnergy {
                maxEnergy = rms
            }
        }

        // If overall energy never exceeded voice threshold
        if maxEnergy < 320.0 {
            logMessage("Audio energy too low throughout recording (max RMS: \(Int(maxEnergy))). Dropping as silence.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        let threshold = max(280.0, min(600.0, maxEnergy * 0.12))

        var firstSpeechFrame = 0
        while firstSpeechFrame < frameCount && frameEnergies[firstSpeechFrame] < threshold {
            firstSpeechFrame += 1
        }

        var lastSpeechFrame = frameCount - 1
        while lastSpeechFrame >= 0 && frameEnergies[lastSpeechFrame] < threshold {
            lastSpeechFrame -= 1
        }

        guard firstSpeechFrame <= lastSpeechFrame else {
            logMessage("No speech frames detected above threshold. Dropping.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        // Add 3 padding frames (60ms) before and 4 padding frames (80ms) after
        let paddedStartFrame = max(0, firstSpeechFrame - 3)
        let paddedEndFrame = min(frameCount - 1, lastSpeechFrame + 4)

        let startSample = paddedStartFrame * frameSize
        let endSample = min(sampleCount, (paddedEndFrame + 1) * frameSize)
        let trimmedSampleCount = endSample - startSample

        // If trimmed speech duration < 0.20s (3200 samples), drop as accidental click
        if trimmedSampleCount < 3200 {
            logMessage("Trimmed speech duration too brief (\(Double(trimmedSampleCount)/16000.0)s). Dropping.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        let trimmedPcmData = samples[startSample..<endSample].withUnsafeBufferPointer { Data(buffer: $0) }

        var trimmedWav = Data()
        let chunkSize = UInt32(36 + trimmedPcmData.count)
        let subchunk2Size = UInt32(trimmedPcmData.count)

        trimmedWav.append("RIFF".data(using: .utf8)!)
        var cs = chunkSize
        trimmedWav.append(Data(bytes: &cs, count: 4))
        trimmedWav.append("WAVEfmt ".data(using: .utf8)!)

        var subchunk1Size: UInt32 = 16
        var audioFormat: UInt16 = 1
        var numChannels: UInt16 = 1
        var sampleRate: UInt32 = 16000
        var byteRate: UInt32 = 32000
        var blockAlign: UInt16 = 2
        var bitsPerSample: UInt16 = 16

        trimmedWav.append(Data(bytes: &subchunk1Size, count: 4))
        trimmedWav.append(Data(bytes: &audioFormat, count: 2))
        trimmedWav.append(Data(bytes: &numChannels, count: 2))
        trimmedWav.append(Data(bytes: &sampleRate, count: 4))
        trimmedWav.append(Data(bytes: &byteRate, count: 4))
        trimmedWav.append(Data(bytes: &blockAlign, count: 2))
        trimmedWav.append(Data(bytes: &bitsPerSample, count: 2))

        trimmedWav.append("data".data(using: .utf8)!)
        var sc2 = subchunk2Size
        trimmedWav.append(Data(bytes: &sc2, count: 4))
        trimmedWav.append(trimmedPcmData)

        do {
            try trimmedWav.write(to: url)
            let origDuration = Double(sampleCount) / 16000.0
            let trimmedDuration = Double(trimmedSampleCount) / 16000.0
            logMessage("Trimmed silence: \(String(format: "%.2f", origDuration))s -> \(String(format: "%.2f", trimmedDuration))s (trimmed \(String(format: "%.2f", origDuration - trimmedDuration))s dead air)")
            return url
        } catch {
            logMessage("Failed to write trimmed WAV: \(error)")
            return url
        }
    }

    public func cancelRecording() {
        stopRecordingCleanup()
        try? FileManager.default.removeItem(at: recordingURL)
    }

    private func stopRecordingCleanup() {
        meterTimer?.invalidate()
        meterTimer = nil
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        isRecording = false
    }

    private func logMessage(_ msg: String) {
        let line = "[\(Date())] [Audio] \(msg)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8) {
            let logURL = URL(fileURLWithPath: "/tmp/minatype.log")
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
