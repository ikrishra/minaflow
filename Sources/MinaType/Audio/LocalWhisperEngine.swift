import Foundation
import SwiftUI
import Combine

public struct WhisperModelOption: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let filename: String
    public let parameters: String
    public let sizeDescription: String
    public let ramDescription: String
    public let speedDescription: String
    public let speedScore: Int
    public let accuracyScore: Int
    public let isEnglishOnly: Bool
    public let isRecommended: Bool
    public let downloadUrl: String
    public let isProOnly: Bool
    public let description: String

    public init(
        id: String,
        displayName: String,
        filename: String,
        parameters: String,
        sizeDescription: String,
        ramDescription: String,
        speedDescription: String,
        speedScore: Int,
        accuracyScore: Int,
        isEnglishOnly: Bool,
        isRecommended: Bool = false,
        downloadUrl: String,
        isProOnly: Bool = false,
        description: String
    ) {
        self.id = id
        self.displayName = displayName
        self.filename = filename
        self.parameters = parameters
        self.sizeDescription = sizeDescription
        self.ramDescription = ramDescription
        self.speedDescription = speedDescription
        self.speedScore = speedScore
        self.accuracyScore = accuracyScore
        self.isEnglishOnly = isEnglishOnly
        self.isRecommended = isRecommended
        self.downloadUrl = downloadUrl
        self.isProOnly = isProOnly
        self.description = description
    }
}

public final class LocalWhisperEngine: ObservableObject {
    public static let shared = LocalWhisperEngine()

    public static let generalModels: [WhisperModelOption] = [
        WhisperModelOption(
            id: "parakeet-v2",
            displayName: "Parakeet V2",
            filename: "ggml-base.en.bin",
            parameters: "600M params",
            sizeDescription: "458 MB",
            ramDescription: "~900 MB RAM",
            speedDescription: "~9x fast",
            speedScore: 9,
            accuracyScore: 8,
            isEnglishOnly: true,
            isRecommended: true,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin",
            isProOnly: false,
            description: "Recommended English: Ultra-low latency acoustic architecture for snappy desktop voice typing."
        ),
        WhisperModelOption(
            id: "turbo",
            displayName: "Whisper Large-v3-Turbo",
            filename: "ggml-large-v3-turbo-q5_0.bin",
            parameters: "809M params",
            sizeDescription: "547 MB",
            ramDescription: "~2.3 GB RAM",
            speedDescription: "~8x fast",
            speedScore: 8,
            accuracyScore: 9,
            isEnglishOnly: false,
            isRecommended: true,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin",
            isProOnly: false,
            description: "Recommended Multilingual: World-class accuracy across 99+ languages, Hindi, and accents."
        ),
        WhisperModelOption(
            id: "small.en",
            displayName: "Whisper Small",
            filename: "ggml-small.en.bin",
            parameters: "244M params",
            sizeDescription: "465 MB",
            ramDescription: "~852 MB RAM",
            speedDescription: "~7x fast",
            speedScore: 7,
            accuracyScore: 6,
            isEnglishOnly: true,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin",
            isProOnly: false,
            description: "High-accuracy English-only model optimized for technical jargon and fast typing."
        ),
        WhisperModelOption(
            id: "base.en",
            displayName: "Whisper Base",
            filename: "ggml-base.en.bin",
            parameters: "74M params",
            sizeDescription: "141 MB",
            ramDescription: "~388 MB RAM",
            speedDescription: "~8x fast",
            speedScore: 8,
            accuracyScore: 5,
            isEnglishOnly: true,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin",
            isProOnly: false,
            description: "Lightweight English-only model with swift sub-second response times."
        ),
        WhisperModelOption(
            id: "small",
            displayName: "Whisper Small Multilingual",
            filename: "ggml-small.bin",
            parameters: "244M params",
            sizeDescription: "466 MB",
            ramDescription: "~852 MB RAM",
            speedDescription: "~4x fast",
            speedScore: 6,
            accuracyScore: 7,
            isEnglishOnly: false,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            isProOnly: false,
            description: "Balanced precision for mixed multi-language speech and European/Indic languages."
        ),
        WhisperModelOption(
            id: "base",
            displayName: "Whisper Base Multilingual",
            filename: "ggml-base.bin",
            parameters: "74M params",
            sizeDescription: "142 MB",
            ramDescription: "~388 MB RAM",
            speedDescription: "~7x fast",
            speedScore: 7,
            accuracyScore: 5,
            isEnglishOnly: false,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
            isProOnly: false,
            description: "Everyday baseline multilingual model with minimal CPU/GPU overhead."
        ),
        WhisperModelOption(
            id: "large-v3",
            displayName: "Whisper Large-v3",
            filename: "ggml-large-v3-q5_0.bin",
            parameters: "1.55B params",
            sizeDescription: "1.1 GB",
            ramDescription: "~3.9 GB RAM",
            speedDescription: "1x baseline",
            speedScore: 4,
            accuracyScore: 9,
            isEnglishOnly: false,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin",
            isProOnly: false,
            description: "Maximum accuracy flagship model for studio transcription and noisy background audio."
        )
    ]

    public static let hinglishModels: [WhisperModelOption] = [
        WhisperModelOption(
            id: "apex-q8",
            displayName: "Apex Hinglish (Q8 Best)",
            filename: "ggml-hindi2hinglish-apex-q8_0.bin",
            parameters: "809M params",
            sizeDescription: "874 MB",
            ramDescription: "~2.4 GB RAM",
            speedDescription: "~8x fast",
            speedScore: 8,
            accuracyScore: 9,
            isEnglishOnly: false,
            isRecommended: true,
            downloadUrl: "https://huggingface.co/imYChaudhary22/zenvoice-hinglish-apex-ggml/resolve/main/ggml-hindi2hinglish-apex-q8_0.bin",
            isProOnly: false,
            description: "Best Hinglish Model: Fine-tuned on Indian speech to transcribe Hindi & English code-switching directly into natural Romanized Latin text."
        ),
        WhisperModelOption(
            id: "apex-q5",
            displayName: "Apex Hinglish (Q5 Smaller)",
            filename: "ggml-apex-hinglish-q5_0.bin",
            parameters: "809M params",
            sizeDescription: "547 MB",
            ramDescription: "~1.8 GB RAM",
            speedDescription: "~9x fast",
            speedScore: 9,
            accuracyScore: 8,
            isEnglishOnly: false,
            isRecommended: false,
            downloadUrl: "https://huggingface.co/Marquestra/Whisper-Hindi2Hinglish-Apex-GGML/resolve/main/ggml-apex-hinglish-q5_0.bin",
            isProOnly: false,
            description: "Faster, lightweight Hinglish model with lower memory footprint and instant Latin script transcription."
        )
    ]

    public static var availableModels: [WhisperModelOption] {
        generalModels + hinglishModels
    }

    @Published public var downloadedModels: Set<String> = []
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var isDownloading: [String: Bool] = [:]
    @Published public var activeDownloadTasks: [String: URLSessionDownloadTask] = [:]

    private let modelsDirectory: URL
    private var downloadObservers: [String: NSKeyValueObservation] = [:]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelsDirectory = appSupport.appendingPathComponent("MinaFlow/models", isDirectory: true)

        try? FileManager.default.createDirectory(at: self.modelsDirectory, withIntermediateDirectories: true)
        refreshDownloadedModels()
    }

    public func refreshDownloadedModels() {
        var found = Set<String>()
        for model in Self.availableModels {
            let path = modelsDirectory.appendingPathComponent(model.filename)
            if FileManager.default.fileExists(atPath: path.path) {
                // Check if non-empty
                if let attr = try? FileManager.default.attributesOfItem(atPath: path.path),
                   let size = attr[.size] as? Int64, size > 1_000_000 {
                    found.insert(model.id)
                }
            }
        }
        DispatchQueue.main.async {
            self.downloadedModels = found
        }
    }

    public func isModelDownloaded(_ id: String) -> Bool {
        return downloadedModels.contains(id)
    }

    public func getModelPath(for id: String) -> URL? {
        guard let model = Self.availableModels.first(where: { $0.id == id }) else { return nil }
        let path = modelsDirectory.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    public func downloadModel(id: String) {
        guard let model = Self.availableModels.first(where: { $0.id == id }) else { return }
        guard isDownloading[id] != true else { return }
        guard let url = URL(string: model.downloadUrl) else { return }

        DispatchQueue.main.async {
            self.isDownloading[id] = true
            self.downloadProgress[id] = 0.01
        }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, response, error in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    self.isDownloading[id] = false
                    self.downloadObservers[id] = nil
                    self.activeDownloadTasks[id] = nil
                }
            }

            if let error = error {
                NSLog("[LocalWhisperEngine] Download failed for %@: %@", id, error.localizedDescription)
                return
            }

            guard let tempUrl = tempUrl else { return }
            let destination = self.modelsDirectory.appendingPathComponent(model.filename)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempUrl, to: destination)
                NSLog("[LocalWhisperEngine] Successfully installed model: %@", destination.path)
                self.refreshDownloadedModels()

                DispatchQueue.main.async {
                    let cfg = ConfigManager.shared.config
                    if self.isHinglishModel(id) {
                        ConfigManager.shared.updateHinglishModel(id)
                    } else if cfg.localWhisperModel == id {
                        ConfigManager.shared.updateLocalWhisperModel(id)
                        ConfigManager.shared.updateSTTProvider(.localWhisper)
                    }
                }
            } catch {
                NSLog("[LocalWhisperEngine] Failed to save downloaded model: %@", error.localizedDescription)
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadProgress[id] = progress.fractionCompleted
            }
        }

        downloadObservers[id] = observation
        activeDownloadTasks[id] = task
        task.resume()
    }

    public func cancelDownload(id: String) {
        activeDownloadTasks[id]?.cancel()
        activeDownloadTasks[id] = nil
        downloadObservers[id] = nil
        DispatchQueue.main.async {
            self.isDownloading[id] = false
            self.downloadProgress[id] = 0.0
        }
    }

    public func startDownload(for id: String) {
        downloadModel(id: id)
    }

    public func cancelDownload(for id: String) {
        cancelDownload(id: id)
    }

    public func deleteModel(id: String) {
        guard let model = Self.availableModels.first(where: { $0.id == id }) else { return }
        let path = modelsDirectory.appendingPathComponent(model.filename)
        try? FileManager.default.removeItem(at: path)
        refreshDownloadedModels()
    }

    public func repairModel(id: String) {
        cancelDownload(id: id)
        deleteModel(id: id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.downloadModel(id: id)
        }
    }

    public func isEnglishOnlyModel(_ id: String) -> Bool {
        return Self.availableModels.first(where: { $0.id == id })?.isEnglishOnly ?? false
    }

    public func isHinglishModel(_ id: String) -> Bool {
        return id == "apex-q8" || id == "apex-q5"
    }

    public static func promptForHinglishDownloadIfNeeded(onAccept: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        let isDownloaded = shared.isModelDownloaded("apex-q8") || shared.isModelDownloaded("apex-q5")
        if isDownloaded {
            onAccept?()
            return
        }

        DispatchQueue.main.async {
            // Close menu popover if it's currently open
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowCloseMenuPopover"), object: nil)

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Download Hinglish Speech Model?"
            alert.informativeText = "Hinglish voice typing requires downloading a dedicated speech model so Hindi & English mixed speech decodes directly into natural Latin script.\n\nWould you like to open Speech Models to choose and download a Hinglish model?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open Speech Models")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                DashboardWindowController.shared.show(tab: 2, subTab: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: Notification.Name("MinaFlowScrollToHinglishModels"), object: nil)
                }
                onCancel?()
            } else {
                onCancel?()
            }
        }
    }

    // MARK: - Binary Resolution
    public func resolveWhisperCli() -> String? {
        // 1. Check in App Bundle Resources/bin/whisper-cli
        if let resourcePath = Bundle.main.resourceURL?.appendingPathComponent("bin/whisper-cli").path,
           FileManager.default.isExecutableFile(atPath: resourcePath) {
            return resourcePath
        }

        // 2. Check in Local build path
        let relativePaths = [
            "Resources/bin/whisper-cli",
            "MinaFlow.app/Contents/Resources/bin/whisper-cli"
        ]
        for rel in relativePaths {
            let full = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(rel).path
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }

        // 3. System Homebrew path
        let systemPath = "/opt/homebrew/bin/whisper-cli"
        if FileManager.default.isExecutableFile(atPath: systemPath) {
            return systemPath
        }

        return nil
    }

    // MARK: - Offline Transcription
    public func transcribe(audioUrl: URL, modelId: String, language: String = "auto", prompt: String? = nil, translate: Bool = false) async throws -> String {
        guard let binaryPath = resolveWhisperCli() else {
            throw NSError(domain: "MinaFlow.LocalWhisper", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "whisper-cli engine binary not found on system."
            ])
        }

        guard let modelPath = getModelPath(for: modelId) else {
            throw NSError(domain: "MinaFlow.LocalWhisper", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Local Whisper model '\(modelId)' is not downloaded yet. Please download it in Settings > Models."
            ])
        }

        var arguments: [String] = [
            "-m", modelPath.path,
            "-f", audioUrl.path,
            "-nt",          // no timestamps
            "-np",          // no prints
            "-nf",          // no fallback (prevents degenerate repetition loops on silence)
            "-sns",         // suppress non-speech tokens
            "--flash-attn"  // Apple Silicon Metal GPU acceleration
        ]

        if translate {
            arguments.append("-tr") // translate directly into English offline
        }

        if isHinglishModel(modelId) {
            // Oriserve Whisper-Hindi2Hinglish Apex requirement: decode with -l en to output Latin script
            arguments.append(contentsOf: ["-l", "en"])
        } else if language != "auto" && !language.isEmpty {
            arguments.append(contentsOf: ["-l", language])
        } else {
            arguments.append(contentsOf: ["-l", "auto"])
        }

        if let prompt = prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--prompt", prompt])
        }

        NSLog("[LocalWhisperEngine] Transcribing with model: %@, language: '%@', translate: %@, prompt: '%@'", modelId, language, translate ? "true" : "false", prompt ?? "")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    var output = String(data: data, encoding: .utf8) ?? ""

                    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Check stderr if stdout was empty
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errOutput = String(data: errData, encoding: .utf8) ?? ""
                        NSLog("[LocalWhisperEngine] stderr: %@", errOutput)
                    }

                    // Clean whisper timestamps if any leaked
                    output = output.replacingOccurrences(of: "\\[\\d{2}:\\d{2}:\\d{2}\\.\\d{3} --> \\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\]\\s*", with: "", options: .regularExpression)
                    output = output.trimmingCharacters(in: .whitespacesAndNewlines)

                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
