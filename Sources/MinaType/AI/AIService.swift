import Foundation
import IOKit
import CryptoKit

public enum AIServiceError: LocalizedError {
    case missingApiKey(String)
    case invalidResponse(String)
    case apiError(String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "\(provider) configuration or API Key is missing. Please check Settings."
        case .invalidResponse(let msg):
            return "Invalid AI response: \(msg)"
        case .apiError(let msg):
            return "AI API Error: \(msg)"
        case .networkError(let err):
            return "Network connection failed: \(err.localizedDescription)"
        }
    }
}

public class AIService {
    public static let shared = AIService()
    private let session = URLSession.shared
    private let cloudflareGatewaySecret = "mf_sec_99a8b1c4e7f2401893d56a27e31b7829"

    private init() {}

    private func applyCloudflareSecurityHeaders(to request: inout URLRequest) {
        let hwUUID = getHardwareUUID() ?? "GENERIC-MAC-CLIENT"
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let message = "\(timestamp):\(hwUUID)"
        let key = SymmetricKey(data: Data(cloudflareGatewaySecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let sigHex = signature.map { String(format: "%02x", $0) }.joined()

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        request.setValue("Bearer \(cloudflareGatewaySecret)", forHTTPHeaderField: "Authorization")
        request.setValue(hwUUID, forHTTPHeaderField: "X-Hardware-UUID")
        request.setValue(timestamp, forHTTPHeaderField: "X-MinaFlow-Timestamp")
        request.setValue(sigHex, forHTTPHeaderField: "X-MinaFlow-Signature")
        request.setValue("\(appVersion) (\(buildNumber))", forHTTPHeaderField: "X-App-Version")
        request.setValue("MinaFlow/\(appVersion) (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
    }

    // MARK: - Transcribe Audio
    public func transcribeAudio(fileURL: URL, prompt: String? = nil) async throws -> String {
        let config = ConfigManager.shared.config

        if config.isLicenseActivated {
            backgroundRevalidateLicense()
        }

        let effectiveMode = config.languageMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isTranslateToEnglish = (effectiveMode == "translatetoenglish")

        let selectedLanguage: String
        if isTranslateToEnglish {
            selectedLanguage = "auto"
        } else if config.selectedLanguages.count == 1 {
            let single = config.selectedLanguages[0]
            if single.caseInsensitiveCompare("hinglish") == .orderedSame {
                selectedLanguage = "hi"
            } else {
                let code = AppLanguages.code(for: single)
                selectedLanguage = (code.isEmpty || code == "auto") ? "auto" : code
            }
        } else {
            // When user selected multiple languages (e.g. English + Hindi, English + Hinglish),
            // Whisper MUST run in auto mode so it can transcribe speech in ANY of the chosen languages!
            selectedLanguage = "auto"
        }

        let whisperPrompt = prompt ?? Self.buildWhisperPrompt(config: config)

        let isHinglish = effectiveMode == "hinglish" || config.selectedLanguages.contains(where: { $0.caseInsensitiveCompare("hinglish") == .orderedSame })

        if isHinglish {
            // Dedicated Hinglish Routing:
            // Standard Whisper on cloud/local outputs Devanagari Hindi or English translation.
            // Apex model specifically decodes Indian code-switched speech directly into Latin script.
            var hinglishModelToUse = config.hinglishModel.isEmpty ? "apex-q8" : config.hinglishModel
            if !LocalWhisperEngine.shared.isModelDownloaded(hinglishModelToUse) {
                if LocalWhisperEngine.shared.isModelDownloaded("apex-q8") {
                    hinglishModelToUse = "apex-q8"
                } else if LocalWhisperEngine.shared.isModelDownloaded("apex-q5") {
                    hinglishModelToUse = "apex-q5"
                } else {
                    throw AIServiceError.apiError("Dedicated Hinglish model is not downloaded. Please download it in Dashboard -> Speech Models.")
                }
            }

            var rawText = try await LocalWhisperEngine.shared.transcribe(
                audioUrl: fileURL,
                modelId: hinglishModelToUse,
                language: "en", // Oriserve Apex requirement: decode with -l en to output Latin script
                prompt: whisperPrompt,
                translate: false
            )

            let containsArabicScript = rawText.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }
            let userSelectedArabicOrUrdu = config.selectedLanguages.contains {
                let low = $0.lowercased()
                return low.contains("arabic") || low.contains("urdu")
            } || config.languageMode.lowercased().contains("arabic") || config.languageMode.lowercased().contains("urdu")

            if containsArabicScript && !userSelectedArabicOrUrdu {
                let filtered = rawText.unicodeScalars.filter { $0.value < 0x0600 || $0.value > 0x06FF }
                rawText = String(String.UnicodeScalarView(filtered)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return rawText
        }

        switch config.sttProvider {
        case .localWhisper:
            var modelToUse = config.localWhisperModel
            if !LocalWhisperEngine.shared.isModelDownloaded(modelToUse) {
                // Fall back gracefully to any already-downloaded general model
                if let fallback = LocalWhisperEngine.generalModels.first(where: { LocalWhisperEngine.shared.isModelDownloaded($0.id) })?.id ?? LocalWhisperEngine.shared.downloadedModels.first {
                    print("[AIService] Model '\(modelToUse)' not downloaded, using downloaded '\(fallback)' as fallback")
                    modelToUse = fallback
                } else {
                    LocalWhisperEngine.shared.downloadModel(id: modelToUse)
                    throw AIServiceError.apiError("Whisper model is downloading. Please wait a moment...")
                }
            }

            let effectiveLang: String
            if LocalWhisperEngine.shared.isEnglishOnlyModel(modelToUse) {
                effectiveLang = "en"
            } else {
                effectiveLang = selectedLanguage
            }

            var rawText = try await LocalWhisperEngine.shared.transcribe(
                audioUrl: fileURL,
                modelId: modelToUse,
                language: effectiveLang,
                prompt: whisperPrompt,
                translate: isTranslateToEnglish
            )

            // Anti-script-confusion guard:
            // If Whisper outputs Arabic/Urdu unicode characters (0x0600-0x06FF) but user did NOT select Arabic or Urdu:
            let containsArabicScript = rawText.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }
            let userSelectedArabicOrUrdu = config.selectedLanguages.contains {
                let l = $0.lowercased()
                return l.contains("arabic") || l.contains("urdu")
            } || effectiveMode.contains("arabic") || effectiveMode.contains("urdu")

            if containsArabicScript && !userSelectedArabicOrUrdu && !LocalWhisperEngine.shared.isHinglishModel(modelToUse) {
                print("[AIService] Whisper generated foreign Arabic/Urdu script when unselected. Recovering via Hindi language lock...")
                rawText = try await LocalWhisperEngine.shared.transcribe(
                    audioUrl: fileURL,
                    modelId: modelToUse,
                    language: "hi",
                    prompt: AppLanguages.nativePrompt(for: "hi"),
                    translate: isTranslateToEnglish
                )
            }

            return rawText

        case .groq:
            guard !config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.missingApiKey("Groq")
            }
            return try await transcribeGroq(fileURL: fileURL, config: config, prompt: whisperPrompt)

        case .deepgram:
            guard !config.deepgramApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.missingApiKey("Deepgram")
            }
            return try await transcribeDeepgram(fileURL: fileURL, config: config)

        case .openai:
            guard !config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.missingApiKey("OpenAI")
            }
            return try await transcribeOpenAI(fileURL: fileURL, config: config, prompt: whisperPrompt)

        case .cohere:
            guard !config.cohereApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.missingApiKey("Cohere")
            }
            return try await transcribeCohere(fileURL: fileURL, config: config)

        case .soniox:
            guard !config.sonioxApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.missingApiKey("Soniox")
            }
            return try await transcribeSoniox(fileURL: fileURL, config: config)

        case .custom:
            return try await transcribeCustom(fileURL: fileURL, config: config, prompt: whisperPrompt)
        }
    }

    /// Non-blocking periodic license check (throttled to at most once every 24 hours).
    /// Offline or unreachable connections will NEVER revoke an activated license.
    public func backgroundRevalidateLicense() {
        let lastCheck = UserDefaults.standard.object(forKey: "MinaFlow_LastLicenseValidation") as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) > 86400 else { return }
        UserDefaults.standard.set(Date(), forKey: "MinaFlow_LastLicenseValidation")
        DodoPaymentsService.shared.recheckLicenseInBackground()
    }

    /// Syncs the free trial count directly from Cloudflare D1 using the Mac's hardware UUID.
    public func syncTrialStatusWithServer() async {
        let config = ConfigManager.shared.config
        guard !config.isLicenseActivated else { return }
        let endpointString = config.cloudflareGatewayUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/trial/status"
        guard let url = URL(string: endpointString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        applyCloudflareSecurityHeaders(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let used = json["used"] as? Int {
                await MainActor.run {
                    ConfigManager.shared.updateTrialDictationsUsed(used)
                }
            }
        } catch {
            print("[AIService] Could not sync trial count from D1: \(error.localizedDescription)")
        }
    }


    // MARK: - Polish & Format Text
    public func polishText(rawTranscript: String, systemPrompt: String, userPrompt: String? = nil) async throws -> String {
        let config = ConfigManager.shared.config
        let containsArabic = rawTranscript.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }
        let userWantsArabicOrUrdu = config.selectedLanguages.contains {
            let low = $0.lowercased()
            return low.contains("arabic") || low.contains("urdu")
        } || config.languageMode.lowercased().contains("arabic") || config.languageMode.lowercased().contains("urdu")

        // 1. If on Free Plan or Polish is disabled, return clean raw transcript directly (zero cloud cost!)
        if !config.canUseAIPolish || !config.isAIPolishEnabled {
            let cleaned = stripQuotes(rawTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
            return AIService.applyCustomVocabulary(cleaned, vocabulary: config.customVocabulary)
        }

        let wordCount = rawTranscript.split { $0.isWhitespace }.count
        let isEditMode = (userPrompt != nil && userPrompt!.contains("\"selectedText\""))

        // Fast path for short utterances (<= 4 words) in dictation mode:
        // Whisper's transcription is already accurate. Only bypass if there are no script mismatches
        let hasScriptMismatch = (containsArabic && !userWantsArabicOrUrdu)
        if !isEditMode && wordCount <= 4 && !hasScriptMismatch {
            let cleaned = stripQuotes(rawTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
            return AIService.applyCustomVocabulary(cleaned, vocabulary: config.customVocabulary)
        }

        let effectiveUserPrompt = userPrompt ?? AppContextDetector.shared.wrapCleanupTranscript(rawTranscript)

        let result: String
        switch config.provider {
        case .groq:
            guard !config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "Groq API key is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishGroq(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .openai:
            guard !config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishOpenAI(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .anthropic:
            guard !config.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishAnthropic(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .gemini:
            guard !config.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishGemini(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .openrouter:
            guard !config.openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "OpenRouter API key is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishOpenRouter(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .custom:
            guard !config.customApiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isEditMode { throw NSError(domain: "MinaType", code: 400, userInfo: [NSLocalizedDescriptionKey: "Custom AI / Ollama endpoint URL is missing."]) }
                return AIService.applyCustomVocabulary(stripQuotes(rawTranscript), vocabulary: config.customVocabulary)
            }
            result = try await polishCustom(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        case .cloudflare:
            result = try await polishGroq(userPrompt: effectiveUserPrompt, rawTranscript: rawTranscript, systemPrompt: systemPrompt, config: config)
        }

        let stripped = AIService.stripThinkingTags(result)
        return AIService.applyCustomVocabulary(stripped, vocabulary: config.customVocabulary)
    }

    public static func applyCustomVocabulary(_ text: String, vocabulary: [String]) -> String {
        var out = text
        for term in vocabulary {
            let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTerm.isEmpty else { continue }

            // 1. Direct word-boundary case replacement (e.g. groq -> Groq)
            let directPattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: cleanTerm) + "\\b"
            if let regex = try? NSRegularExpression(pattern: directPattern, options: []) {
                out = regex.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: cleanTerm)
            }

            // 2. Known homophones: "groq" vs "grok" or "groc"
            if cleanTerm.lowercased() == "groq" {
                if let homophoneRegex = try? NSRegularExpression(pattern: "(?i)\\b(grok|groc)\\b", options: []) {
                    out = homophoneRegex.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: cleanTerm)
                }
            }
        }
        return out
    }

    public static func stripThinkingTags(_ text: String) -> String {
        var out = text
        let innermostClosed = "(?i)<think>(?:(?!<think>)[\\s\\S])*?</think>"
        while let regex = try? NSRegularExpression(pattern: innermostClosed, options: []),
              let match = regex.firstMatch(in: out, range: NSRange(out.startIndex..., in: out)) {
            out = (out as NSString).replacingCharacters(in: match.range, with: "")
        }
        if let unclosed = try? NSRegularExpression(pattern: "(?i)<think>[\\s\\S]*$", options: []) {
            out = unclosed.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        return out.replacingOccurrences(of: "</think>", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
    }



    private func transcribeGroq(fileURL: URL, config: MinaConfig, prompt: String?) async throws -> String {
        let apiKey = config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Groq") }

        let url = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)

        let isHinglish = config.languageMode.caseInsensitiveCompare("hinglish") == .orderedSame ||
                         config.selectedLanguages.contains { $0.caseInsensitiveCompare("hinglish") == .orderedSame }
        let promptText = AIService.buildWhisperPrompt(config: config, userPrompt: prompt)

        if !promptText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(promptText)\r\n".data(using: .utf8)!)
        }

        if config.languageMode != "auto" && !isHinglish {
            let activeLang = config.selectedLanguages.first ?? config.languageMode
            let langCode = AppLanguages.code(for: activeLang)
            if !langCode.isEmpty && langCode != "auto" {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(langCode)\r\n".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = AIService.parseErrorMessage(from: data, fallback: "Groq transcription failed")
            throw AIServiceError.apiError(errorMsg)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return cleanWhisperHallucinations(decoded.text, vocabulary: config.customVocabulary)
    }

    private func polishGroq(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let apiKey = config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Groq") }

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

        // Free Groq LLM candidate pool in priority order (combined 10,250+ free requests/day)
        let fallbackPool = [
            "openai/gpt-oss-20b",
            "qwen/qwen3.8-27b",
            "allam-2-7b",
            "openai/gpt-oss-120b",
            "groq/compound-mini"
        ]

        let rawModel = config.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyGroq = ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "mixtral-8x7b-32768", "llama3-8b-8192"]
        let primaryModel: String
        if rawModel.isEmpty || legacyGroq.contains(rawModel) {
            primaryModel = "openai/gpt-oss-20b"
        } else {
            primaryModel = rawModel
        }

        // Check if user enabled auto-failover on rate limits
        let shouldAutoFailover = config.autoFailoverOnRateLimit
        let modelsToTry: [String]
        if shouldAutoFailover {
            var pool = [primaryModel]
            for m in fallbackPool where m != primaryModel {
                pool.append(m)
            }
            modelsToTry = pool
        } else {
            modelsToTry = [primaryModel]
        }

        var lastErrorMsg = "Groq error"

        for (index, model) in modelsToTry.enumerated() {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": 0.0,
                "max_tokens": 1024
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                if httpResponse.statusCode == 200 {
                    struct ChatResponse: Decodable {
                        struct Choice: Decodable {
                            struct Message: Decodable {
                                let content: String
                            }
                            let message: Message
                        }
                        let choices: [Choice]
                    }

                    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                    if let content = decoded.choices.first?.message.content {
                        // If we auto-failed over due to rate limit, persist the working model for future calls
                        if index > 0 {
                            print("[AIService] Limit reached on \(primaryModel). Auto-switched to \(model)")
                            DispatchQueue.main.async {
                                ConfigManager.shared.updateLlmModel(model)
                            }
                        }
                        return stripQuotes(content)
                    }
                } else if httpResponse.statusCode == 429 {
                    // Rate limit reached for this specific model -> automatically try next model in the pool
                    let err = AIService.parseErrorMessage(from: data, fallback: "Rate limit reached")
                    print("[AIService] Model '\(model)' limit reached (429): \(err). Trying fallback...")
                    lastErrorMsg = err
                    continue
                } else if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
                    // Model decommissioned or bad format -> try next model
                    continue
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "Groq error")
                    lastErrorMsg = err
                    if index == modelsToTry.count - 1 {
                        // Return raw transcript rather than breaking user dictation
                        return rawTranscript
                    }
                }
            } catch {
                if index == modelsToTry.count - 1 {
                    print("[AIService] Polish failed: \(error). Gracefully falling back to raw speech transcript.")
                    return rawTranscript
                }
            }
        }

        // Never lose speech: if all LLMs are rate-limited, raw Whisper transcript is returned
        print("[AIService] All LLM models rate limited (\(lastErrorMsg)). Returning raw transcript.")
        return rawTranscript
    }

    // MARK: - OpenAI Implementation
    private func transcribeOpenAI(fileURL: URL, config: MinaConfig, prompt: String?) async throws -> String {
        let apiKey = config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("OpenAI") }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        let isHinglish = config.languageMode.caseInsensitiveCompare("hinglish") == .orderedSame ||
                         config.selectedLanguages.contains { $0.caseInsensitiveCompare("hinglish") == .orderedSame }
        let promptText = AIService.buildWhisperPrompt(config: config, userPrompt: prompt)

        if !promptText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(promptText)\r\n".data(using: .utf8)!)
        }

        if config.languageMode != "auto" && !isHinglish {
            let activeLang = config.selectedLanguages.first ?? config.languageMode
            let langCode = AppLanguages.code(for: activeLang)
            if !langCode.isEmpty && langCode != "auto" {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(langCode)\r\n".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "OpenAI transcription error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return cleanWhisperHallucinations(decoded.text, vocabulary: config.customVocabulary)
    }

    private func transcribeCustom(fileURL: URL, config: MinaConfig, prompt: String?) async throws -> String {
        let baseUrl = config.customApiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = baseUrl.hasSuffix("/audio/transcriptions") ? baseUrl : "\(baseUrl)/audio/transcriptions"
        guard let url = URL(string: endpoint) else {
            throw AIServiceError.invalidResponse("Invalid Custom STT URL: \(endpoint)")
        }

        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !config.customApiKey.isEmpty {
            request.setValue("Bearer \(config.customApiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        let model = config.customModel.isEmpty ? "whisper-1" : config.customModel
        body.append("\(model)\r\n".data(using: .utf8)!)

        let promptText = AIService.buildWhisperPrompt(config: config, userPrompt: prompt)
        if !promptText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(promptText)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Custom STT endpoint error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return cleanWhisperHallucinations(decoded.text, vocabulary: config.customVocabulary)
    }

    private func polishOpenAI(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let apiKey = config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("OpenAI") }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = config.llmModel.isEmpty ? "gpt-4o-mini" : config.llmModel
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.0,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "OpenAI chat error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return stripQuotes(decoded.choices.first?.message.content ?? rawTranscript)
    }

    // MARK: - Anthropic (Claude) Implementation
    private func polishAnthropic(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let apiKey = config.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Anthropic") }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = config.llmModel.isEmpty ? "claude-3-5-haiku-latest" : config.llmModel
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Anthropic API error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct AnthropicResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
            }
            let content: [ContentBlock]
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let firstText = decoded.content.first(where: { $0.type == "text" })?.text ?? rawTranscript
        return stripQuotes(firstText)
    }

    // MARK: - OpenRouter Implementation
    private func transcribeOpenRouter(fileURL: URL, config: MinaConfig, prompt: String?) async throws -> String {
        let apiKey = config.openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("OpenRouter") }

        let url = URL(string: "https://openrouter.ai/api/v1/audio/transcriptions")!
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("openai/whisper-large-v3-turbo\r\n".data(using: .utf8)!)

        let promptText = prompt ?? config.customVocabulary.joined(separator: ", ")
        if !promptText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(promptText)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "OpenRouter error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return cleanWhisperHallucinations(decoded.text, vocabulary: config.customVocabulary)
    }

    private func polishOpenRouter(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let apiKey = config.openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("OpenRouter") }

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        let primaryModel = config.llmModel.isEmpty ? "meta-llama/llama-3.3-70b-instruct:free" : config.llmModel

        let openRouterFallbackPool = [
            "meta-llama/llama-3.3-70b-instruct:free",
            "google/gemini-2.0-flash-exp:free",
            "mistralai/mistral-7b-instruct:free",
            "qwen/qwen-2.5-72b-instruct:free"
        ]

        let modelsToTry: [String]
        if config.autoFailoverOnRateLimit && primaryModel.contains(":free") {
            var pool = [primaryModel]
            for m in openRouterFallbackPool where m != primaryModel {
                pool.append(m)
            }
            modelsToTry = pool
        } else {
            modelsToTry = [primaryModel]
        }

        for (index, model) in modelsToTry.enumerated() {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": 0.0,
                "max_tokens": 1024
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }

                if httpResponse.statusCode == 200 {
                    struct ChatResponse: Decodable {
                        struct Choice: Decodable {
                            struct Message: Decodable { let content: String }
                            let message: Message
                        }
                        let choices: [Choice]
                    }
                    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                    if let content = decoded.choices.first?.message.content {
                        if index > 0 {
                            print("[AIService] OpenRouter rate limit on \(primaryModel). Auto-switched to \(model)")
                            DispatchQueue.main.async {
                                ConfigManager.shared.updateLlmModel(model)
                            }
                        }
                        return stripQuotes(content)
                    }
                } else if httpResponse.statusCode == 429 && index < modelsToTry.count - 1 {
                    print("[AIService] OpenRouter 429 on \(model). Trying next free candidate...")
                    continue
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "OpenRouter error (\(httpResponse.statusCode))"
                    if index == modelsToTry.count - 1 {
                        throw AIServiceError.apiError(errorMsg)
                    }
                }
            } catch {
                if index == modelsToTry.count - 1 { throw error }
            }
        }

        return rawTranscript
    }

    // MARK: - Custom / Local (Ollama, LocalAI, vLLM)

    private func polishCustom(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let baseUrl = config.customApiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseUrl)/chat/completions") else {
            throw AIServiceError.invalidResponse("Invalid Custom API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !config.customApiKey.isEmpty {
            request.setValue("Bearer \(config.customApiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = config.customModel.isEmpty ? "llama3.1" : config.customModel
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.0,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Custom chat error"
            throw AIServiceError.apiError(errorMsg)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return stripQuotes(decoded.choices.first?.message.content ?? rawTranscript)
    }

    // MARK: - OpenAI-Compatible Connection Test
    public func testOpenAICompatibleConnection(baseUrl: String, modelId: String, apiKey: String) async -> (success: Bool, message: String) {
        var cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if cleanBase.isEmpty {
            return (false, "URL cannot be empty")
        }
        if !cleanBase.hasPrefix("http://") && !cleanBase.hasPrefix("https://") {
            cleanBase = "https://" + cleanBase
        }
        guard let url = URL(string: "\(cleanBase)/chat/completions") else {
            return (false, "Invalid endpoint URL format")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let effectiveModel = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4o-mini" : modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "model": effectiveModel,
            "messages": [
                ["role": "user", "content": "Respond with 'OK' only."]
            ],
            "max_tokens": 8
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "No HTTP response received from server")
            }
            if http.statusCode == 200 {
                return (true, "Successfully connected to \(effectiveModel)!")
            } else {
                let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(http.statusCode)")
                return (false, "HTTP \(http.statusCode): \(err)")
            }
        } catch {
            return (false, "Connection error: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Gemini Implementation
    private func polishGemini(userPrompt: String, rawTranscript: String, systemPrompt: String, config: MinaConfig) async throws -> String {
        let apiKey = config.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Google Gemini") }

        let model = config.geminiModel.isEmpty ? "gemini-2.0-flash" : config.geminiModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw AIServiceError.apiError("Invalid Google Gemini endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": userPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "maxOutputTokens": 1024
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return rawTranscript
            }
            if http.statusCode == 200 {
                struct GeminiResponse: Decodable {
                    struct Candidate: Decodable {
                        struct Content: Decodable {
                            struct Part: Decodable {
                                let text: String?
                            }
                            let parts: [Part]?
                        }
                        let content: Content?
                    }
                    let candidates: [Candidate]?
                }
                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                if let text = decoded.candidates?.first?.content?.parts?.first?.text {
                    return stripQuotes(text)
                }
            } else {
                let err = AIService.parseErrorMessage(from: data, fallback: "Gemini error (\(http.statusCode))")
                print("[AIService] Gemini API error: \(err)")
            }
        } catch {
            print("[AIService] Gemini polish error: \(error)")
        }
        return rawTranscript
    }

    // MARK: - Cohere Transcribe Implementation
    private func transcribeCohere(fileURL: URL, config: MinaConfig) async throws -> String {
        let apiKey = config.cohereApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Cohere") }

        let url = URL(string: "https://api.cohere.com/v2/audio/transcriptions") ?? URL(string: "https://api.cohere.ai/v1/transcribe")!
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("cohere-transcribe-03-2026\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse("No response from Cohere")
        }
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let errMsg = AIService.parseErrorMessage(from: data, fallback: "Cohere returned HTTP \(httpResponse.statusCode)")
        throw AIServiceError.apiError("Cohere Error: \(errMsg)")
    }

    // MARK: - Soniox Implementation
    private func transcribeSoniox(fileURL: URL, config: MinaConfig) async throws -> String {
        let apiKey = config.sonioxApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey("Soniox") }

        let url = URL(string: "https://api.soniox.com/v1/transcribe")!
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("stt-async-v5\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse("No response from Soniox")
        }
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let errMsg = AIService.parseErrorMessage(from: data, fallback: "Soniox returned HTTP \(httpResponse.statusCode)")
        throw AIServiceError.apiError("Soniox Error: \(errMsg)")
    }

    // MARK: - Deepgram Speech-to-Text
    private func transcribeDeepgram(fileURL: URL, config: MinaConfig) async throws -> String {
        let apiKey = config.deepgramApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AIServiceError.apiError("Deepgram API key is missing. Please enter your key in Settings > AI & Models.")
        }

        let audioData = try Data(contentsOf: fileURL)
        let rawModel = config.deepgramModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = rawModel.isEmpty ? "nova-3" : rawModel

        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        var queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true")
        ]

        if config.languageMode != "auto" {
            let activeLang = config.selectedLanguages.first ?? config.languageMode
            let langCode = AppLanguages.code(for: activeLang)
            if !langCode.isEmpty && langCode != "auto" {
                queryItems.append(URLQueryItem(name: "language", value: langCode))
            }
        } else {
            queryItems.append(URLQueryItem(name: "detect_language", value: "true"))
        }

        // Custom vocabulary keyterm biasing for Deepgram Nova-3
        for term in config.customVocabulary {
            let clean = term.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                queryItems.append(URLQueryItem(name: "keyterm", value: clean))
            }
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw AIServiceError.apiError("Invalid Deepgram endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse("No HTTP response received from Deepgram")
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = AIService.parseErrorMessage(from: data, fallback: "Deepgram STT returned HTTP \(httpResponse.statusCode)")
            throw AIServiceError.apiError("Deepgram Error (\(httpResponse.statusCode)): \(errorMsg)")
        }

        struct DeepgramResponse: Decodable {
            struct Results: Decodable {
                struct Channel: Decodable {
                    struct Alternative: Decodable {
                        let transcript: String?
                    }
                    let alternatives: [Alternative]?
                }
                let channels: [Channel]?
            }
            let results: Results?
        }

        let decoded = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        let transcript = decoded.results?.channels?.first?.alternatives?.first?.transcript ?? ""
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers
    private func getHardwareUUID() -> String? {
        let dev = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard dev != 0 else { return nil }
        defer { IOObjectRelease(dev) }
        return IORegistryEntryCreateCFProperty(dev, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    }

    /// Constructs vocabulary biasing prompt for Whisper without hardcoded English keywords
    public static func buildWhisperPrompt(config: MinaConfig, userPrompt: String? = nil) -> String {
        let vocabTerms = Array(config.customVocabulary.prefix(30))
        let vocabStr = vocabTerms.joined(separator: ", ")

        if let p = userPrompt, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !vocabStr.isEmpty {
                return p + ", " + vocabStr
            }
            return p
        }

        let isHinglishExplicit = config.languageMode.caseInsensitiveCompare("hinglish") == .orderedSame ||
                                 config.selectedLanguages.contains { $0.caseInsensitiveCompare("hinglish") == .orderedSame }

        var promptParts: [String] = []

        if isHinglishExplicit {
            promptParts.append(AppLanguages.nativePrompt(for: "hinglish"))
            if config.selectedLanguages.contains(where: { $0.caseInsensitiveCompare("english") == .orderedSame }) {
                promptParts.append(AppLanguages.nativePrompt(for: "en"))
            }
        } else if !config.selectedLanguages.isEmpty {
            for lang in config.selectedLanguages.prefix(3) {
                let p = AppLanguages.nativePrompt(for: lang)
                if !p.isEmpty && !promptParts.contains(p) {
                    promptParts.append(p)
                }
            }
        } else {
            let activeLang = config.languageMode
            let p = AppLanguages.nativePrompt(for: activeLang)
            if !p.isEmpty {
                promptParts.append(p)
            }
        }

        var basePrompt = promptParts.joined(separator: " ")
        if !vocabStr.isEmpty {
            basePrompt = basePrompt.isEmpty ? vocabStr : "\(basePrompt), \(vocabStr)"
        }
        return basePrompt
    }

    /// Detects and eliminates degenerate Whisper repetition loops (e.g. "of a more path of a of a more path...")
    public static func removeRepetitionLoops(_ text: String) -> String {
        let words = text.split { $0.isWhitespace }.map(String.init)
        guard words.count >= 6 else { return text }

        let uniqueWords = Set(words.map { $0.lowercased() })
        if Double(uniqueWords.count) / Double(words.count) < 0.35 {
            print("[\(Date())] [AIService] Dropped degenerate runaway loop transcript (unique ratio \(Double(uniqueWords.count) / Double(words.count)) < 0.35)")
            return ""
        }

        // Check for repeating n-grams of lengths 1 to 8 words
        for n in 1...8 {
            guard words.count >= n * 3 else { continue }
            var repeats = 1
            for i in stride(from: words.count - n, through: n, by: -n) {
                let current = words[i..<i + n]
                let previous = words[i - n..<i]
                if current.elementsEqual(previous, by: { $0.caseInsensitiveCompare($1) == .orderedSame }) {
                    repeats += 1
                    if repeats >= 3 {
                        let valid = Array(words[0..<(i - n)])
                        if valid.count < 3 { return "" }
                        return valid.joined(separator: " ")
                    }
                } else {
                    repeats = 1
                }
            }
        }
        return text
    }

    private func cleanWhisperHallucinations(_ text: String, vocabulary: [String] = [], peakAudioLevel: Float? = nil) -> String {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuationSet = CharacterSet(charactersIn: ".,!?:;\"'()[]{}<>-")
        let lower = raw.lowercased().trimmingCharacters(in: punctuationSet).trimmingCharacters(in: .whitespacesAndNewlines)

        // Known Whisper silence / low-energy hallucination prefixes (including Indonesian/Portuguese YouTube captions)
        let hallucinationPrefixes = [
            "countering minimal save", "subtitles by", "amara.org", "sous-titres",
            "thank you for watching", "please subscribe", "like and subscribe",
            "jangan lupa", "terima kasih sudah", "terima kasih telah", "sampai jumpa di",
            "selamat menonton", "subscribe to my channel", "like, share", "like and share",
            "don't forget to like", "don't forget to subscribe", "obrigado por assistir",
            "inscreva-se", "gracias por ver", "suscríbete a", "dan subscribe channel",
            "alô, alô", "alô alô"
        ]
        for prefix in hallucinationPrefixes {
            if lower.hasPrefix(prefix) || lower.contains("jangan lupa") || lower.contains("subscribe channel ini") {
                print("[\(Date())] [AIService] Discarded known Whisper silence hallucination prefix: '\(raw.prefix(50))'")
                return ""
            }
        }

        // Known Whisper silence / low-energy Portuguese & YouTube hallucination loops
        let commonHallucinations: Set<String> = [
            "thank you", "thank you.", "thanks for watching", "thanks for watching.", "you",
            "bye", "bye.", "bye bye", "subtitles by", "amara.org", "countering minimal save",
            "tchau", "tchau tchau", "tchau, tchau", "tchau!", "tchau tchau!", "adeus",
            "obrigado", "obrigada", "obrigado.", "obrigada.", "ynys",
            "alô", "alô alô", "alô, alô", "alô!", "alô, alô!", "alô, alô.", "olá", "olá!",
            "aló", "aló aló", "aló, aló", "aló!", "aló, aló!", "aló, aló.", "¡aló!", "¡aló, aló!",
            "sous-titres réalisés par", "sous-titres", "please subscribe", "like and subscribe",
            "subscribe to my channel", "watch more videos", "see you next time",
            "jangan lupa, share, subscribe, dan subscribe channel ini",
            "jangan lupa share subscribe dan subscribe channel ini",
            "jangan lupa like comment dan subscribe",
            "jangan lupa like, comment, dan subscribe",
            "jangan lupa subscribe",
            "terima kasih sudah menonton",
            "terima kasih telah menonton",
            "sampai jumpa di video berikutnya",
            "selamat menonton"
        ]

        // If Whisper misclassified "hello, hello" into Spanish/Portuguese "Aló, aló":
        let lowerStripped = lower.replacingOccurrences(of: "¡", with: "").replacingOccurrences(of: "!", with: "").replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerStripped == "aló, aló" || lowerStripped == "aló aló" || lowerStripped == "alô, alô" || lowerStripped == "alô alô" || lowerStripped == "aló" || lowerStripped == "alô" {
            let userLangs = ConfigManager.shared.config.selectedLanguages
            let hasRomance = userLangs.contains(where: { $0.caseInsensitiveCompare("spanish") == .orderedSame || $0.caseInsensitiveCompare("portuguese") == .orderedSame })
            if !hasRomance {
                print("[\(Date())] [AIService] Corrected Whisper romance phone greeting '\(raw)' to English 'Hello, hello.'")
                return (lowerStripped.contains("aló aló") || lowerStripped.contains("alô alô") || lowerStripped.contains("aló, aló") || lowerStripped.contains("alô, alô")) ? "Hello, hello." : "Hello."
            }
        }

        if commonHallucinations.contains(lower) {
            print("[\(Date())] [AIService] Discarded known Whisper silence hallucination: '\(raw)'")
            return ""
        }

        // 1. Custom vocabulary / prompt echo filter:
        let cleanedTranscript = lower.trimmingCharacters(in: punctuationSet).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedVocab = vocabulary.map {
            $0.lowercased().trimmingCharacters(in: punctuationSet).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        if !cleanedVocab.isEmpty {
            let peak = peakAudioLevel ?? AudioRecorder.shared.lastPeakLevel
            if cleanedVocab.contains(cleanedTranscript) && peak < 0.35 {
                print("[\(Date())] [AIService] Discarded silence prompt hallucination: '\(raw)' matches vocabulary word with low voice peak (\(String(format: "%.2f", peak)) < 0.35)")
                return ""
            }

            let joinedVocab = cleanedVocab.joined(separator: ", ")
            if (cleanedTranscript == joinedVocab || cleanedTranscript == cleanedVocab.joined(separator: " ")) && peak < 0.35 {
                print("[\(Date())] [AIService] Discarded silence prompt hallucination: '\(raw)' matches joined vocabulary list")
                return ""
            }

            let transcriptWords = cleanedTranscript.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map { String($0) }
            if !transcriptWords.isEmpty && transcriptWords.allSatisfy({ cleanedVocab.contains($0) }) && peak < 0.30 {
                print("[\(Date())] [AIService] Discarded silence prompt hallucination: all words match vocabulary with low voice peak (\(String(format: "%.2f", peak)))")
                return ""
            }
        }

        // 2. Remove degenerate repetition loops
        raw = AIService.removeRepetitionLoops(raw)
        if raw.isEmpty { return "" }

        // 3. Remove degenerate short particle chains (e.g. "of a of a of a", "path of a path of a")
        let runawayChain = #"(?:(?:\b(?:of|the|a|to|in|and|more|path|for|with|on|at|by|from|top|minimal|save|slight|normal|common|only|create|any|this)\b\s*){2,}){3,}"#
        if let regex = try? NSRegularExpression(pattern: runawayChain, options: .caseInsensitive) {
            raw = regex.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: "")
        }

        // 4. Check unique word ratio to catch degenerate runaway loops
        let words = raw.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        if words.count > 6 {
            let uniqueWords = Set(words.map { $0.lowercased() })
            if Double(uniqueWords.count) / Double(words.count) < 0.45 {
                print("[\(Date())] [AIService] Dropped degenerate runaway loop transcript (unique ratio \(Double(uniqueWords.count) / Double(words.count)) < 0.45)")
                return ""
            }
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripQuotes(_ text: String) -> String {
        var polished = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (polished.hasPrefix("\"") && polished.hasSuffix("\"")) ||
           (polished.hasPrefix("“") && polished.hasSuffix("”")) {
            polished = String(polished.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if polished == "EMPTY" {
            return ""
        }
        return polished
    }

    public static func parseErrorMessage(from data: Data, fallback: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = json["error"] as? [String: Any] {
                if let msg = err["message"] as? String {
                    return msg
                }
            } else if let msg = json["message"] as? String {
                return msg
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback
        return raw.isEmpty ? fallback : raw
    }

    // MARK: - Instant API Key Validation
    public func validateGroqKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else { return (false, "Invalid endpoint URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to Groq")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API Key (Unauthorized - check key)")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No network response from Groq")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateDeepgramKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://api.deepgram.com/v1/projects") else { return (false, "Invalid endpoint URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to Deepgram")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API Key (Unauthorized - check key)")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No network response from Deepgram")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateCustomUrl(_ urlString: String, key: String?) async -> (isValid: Bool, message: String) {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty, let base = URL(string: cleanUrl) else { return (false, "Invalid URL format") }

        let testUrl = base.appendingPathComponent("models")
        var request = URLRequest(url: testUrl)
        request.httpMethod = "GET"
        if let k = key?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty {
            request.setValue("Bearer \(k)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return (true, "Connected to Local Endpoint")
            } else {
                return (true, "Endpoint responded (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
            }
        } catch {
            return (false, "Could not reach endpoint: \(error.localizedDescription)")
        }
    }

    public func validateCustomEndpoint(baseUrl: String, apiKey: String, model: String) async -> (isValid: Bool, message: String) {
        return await validateCustomUrl(baseUrl, key: apiKey.isEmpty ? nil : apiKey)
    }

    public func validateOpenAIKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return (false, "Invalid endpoint URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to OpenAI")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API Key (Unauthorized)")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No response from OpenAI")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateAnthropicKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else { return (false, "Invalid endpoint URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cleanKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to Anthropic")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API Key (Unauthorized)")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No response from Anthropic")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateOpenRouterKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://openrouter.ai/api/v1/auth/key") else { return (false, "Invalid endpoint URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to OpenRouter")
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid API Key (Unauthorized)")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No response from OpenRouter")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateGeminiKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(cleanKey)") else {
            return (false, "Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to Gemini")
                } else if httpResponse.statusCode == 400 || httpResponse.statusCode == 403 {
                    return (false, "Invalid Gemini API Key")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No response from Gemini")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateCohereKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard let url = URL(string: "https://api.cohere.com/v1/check-api-key") else {
            return (false, "Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, "Valid & Connected to Cohere")
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return (false, "Invalid Cohere API Key")
                } else {
                    let err = AIService.parseErrorMessage(from: data, fallback: "HTTP \(httpResponse.statusCode)")
                    return (false, err)
                }
            }
            return (false, "No response from Cohere")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func validateSonioxKey(_ key: String) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return (false, "API key cannot be empty") }
        guard cleanKey.count >= 16 else { return (false, "Invalid Soniox API key length") }
        return (true, "Soniox Key Configured")
    }
}

