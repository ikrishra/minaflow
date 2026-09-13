import Foundation
import AppKit

public enum AIProvider: String, Codable, CaseIterable {
    case groq = "groq"
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case openrouter = "openrouter"
    case custom = "custom"
    case cloudflare = "cloudflare" // Internal fallback for initial trial
    
    public var displayName: String {
        switch self {
        case .groq: return "Groq Cloud"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter"
        case .custom: return "Custom"
        case .cloudflare: return "Cloudflare Trial"
        }
    }

    /// User-facing selectable providers in Settings
    public static var userProviders: [AIProvider] {
        return [.groq, .openai, .anthropic, .gemini, .openrouter, .custom]
    }
}

public enum STTProvider: String, Codable, CaseIterable {
    case localWhisper = "localWhisper"
    case groq = "groq"
    case deepgram = "deepgram"
    case openai = "openai"
    case cohere = "cohere"
    case soniox = "soniox"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .localWhisper: return "Local Whisper"
        case .groq: return "Groq Whisper"
        case .deepgram: return "Deepgram Nova-3"
        case .openai: return "OpenAI Whisper-1"
        case .cohere: return "Cohere Transcribe"
        case .soniox: return "Soniox STT"
        case .custom: return "Local Server"
        }
    }
}

public struct AIModelOption: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let description: String

    public init(id: String, displayName: String, description: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
}

public extension AIProvider {
    var availableModels: [AIModelOption] {
        switch self {
        case .groq:
            return [
                AIModelOption(id: "openai/gpt-oss-20b", displayName: "GPT-OSS 20B", description: "Ultra-fast sub-100ms response, ideal for live voice dictation (Recommended)"),
                AIModelOption(id: "qwen/qwen3.8-27b", displayName: "Qwen 3.8 27B", description: "23ms blazing speed, superior multilingual grammar & structure"),
                AIModelOption(id: "allam-2-7b", displayName: "Allam 2 7B", description: "High volume tier with 7,000 requests per day limit"),
                AIModelOption(id: "openai/gpt-oss-120b", displayName: "GPT-OSS 120B", description: "Flagship intelligence for deep reasoning and executive prose"),
                AIModelOption(id: "groq/compound-mini", displayName: "Compound Mini", description: "Balanced fast compound intelligence")
            ]
        case .openai:
            return [
                AIModelOption(id: "gpt-4o-mini", displayName: "GPT-4o Mini", description: "Lightning fast, cost-effective OpenAI model (Recommended)"),
                AIModelOption(id: "gpt-4o", displayName: "GPT-4o", description: "Flagship intelligence for executive prose")
            ]
        case .anthropic:
            return [
                AIModelOption(id: "claude-3-5-haiku-latest", displayName: "Claude 3.5 Haiku", description: "Sub-second response, crisp writing polish (Recommended)"),
                AIModelOption(id: "claude-3-5-sonnet-latest", displayName: "Claude 3.5 Sonnet", description: "Nuanced voice, impeccable style and flow"),
                AIModelOption(id: "claude-3-opus-latest", displayName: "Claude 3 Opus", description: "Deep editorial reasoning and long transformations")
            ]
        case .gemini:
            return [
                AIModelOption(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash", description: "Sub-second speed, multimodal intelligence (Recommended)"),
                AIModelOption(id: "gemini-1.5-flash", displayName: "Gemini 1.5 Flash", description: "Fast, balanced general writing assistant"),
                AIModelOption(id: "gemini-1.5-pro", displayName: "Gemini 1.5 Pro", description: "Deep editorial reasoning and complex document structuring")
            ]
        case .openrouter:
            return [
                AIModelOption(id: "google/gemini-2.0-flash-001", displayName: "Gemini 2.0 Flash", description: "Sub-second speed from Google (Recommended)"),
                AIModelOption(id: "anthropic/claude-3.5-sonnet", displayName: "Claude 3.5 Sonnet", description: "Gold standard for writing style & prose"),
                AIModelOption(id: "deepseek/deepseek-chat", displayName: "DeepSeek V3", description: "Superb coding and technical reasoning")
            ]
        case .custom:
            return [
                AIModelOption(id: "llama3.1", displayName: "Llama 3.1", description: "Meta open-weights standard for Ollama"),
                AIModelOption(id: "mistral", displayName: "Mistral 7B", description: "Fast, accurate local European multilingual model"),
                AIModelOption(id: "qwen2.5", displayName: "Qwen 2.5", description: "High-reasoning local model"),
                AIModelOption(id: "phi4", displayName: "Phi-4", description: "Microsoft compact reasoning model")
            ]
        case .cloudflare:
            return [
                AIModelOption(id: "@cf/meta/llama-3.1-8b-instruct-fast", displayName: "Llama 3.1 8B Fast", description: "Cloudflare Workers AI")
            ]
        }
    }
}

public struct MinaConfig: Codable {
    public var provider: AIProvider
    public var cloudflareGatewayUrl: String
    public var cloudflareApiToken: String
    public var groqApiKey: String
    public var openaiApiKey: String
    public var anthropicApiKey: String
    public var openrouterApiKey: String
    public var geminiApiKey: String
    public var geminiModel: String
    public var customApiUrl: String
    public var customApiKey: String
    public var customModel: String
    public var whisperModel: String
    public var llmModel: String
    public var hotkey: String
    public var mode: String // "pushToTalk" or "toggle"
    public var languageMode: String // "manual", "hinglish", "english", "translateToEnglish", etc.
    public var selectedLanguages: [String]
    public var toneMode: String // "auto", "formal", "casual", "veryCasual"
    public var snippets: [String: String]
    public var playSounds: Bool
    public var customVocabulary: [String]
    public var systemPromptOverride: String?
    public var licenseKey: String
    public var licenseInstanceId: String
    public var isLicenseActivated: Bool
    public var dodoEnvironment: String // "test" or "live"
    public var trialDictationsUsed: Int
    public var appTheme: String // "light" or "dark"
    public var autoFailoverOnRateLimit: Bool
    public var isBrowserURLExtractionEnabled: Bool
    public var hudStyle: String // "pill" or "notch"
    public var showDockIcon: Bool
    public var sttProvider: STTProvider
    public var deepgramApiKey: String
    public var deepgramModel: String
    public var cohereApiKey: String
    public var sonioxApiKey: String

    // Local Whisper & Tier Configurations
    public var localWhisperModel: String // "parakeet-v2", "turbo", "small", etc. (Primary General Model)
    public var hinglishModel: String // "apex-q8" or "apex-q5" (Dedicated Hinglish Model)
    public var isAIPolishEnabled: Bool
    public var voiceMacros: [String: String]
    public var isEditModeEnabled: Bool
    public var editModeHotkey: String

    // Tier Capabilities (Free vs Paid)
    public var canUseAIPolish: Bool { isLicenseActivated }
    public var canUseHighlightToEdit: Bool { isLicenseActivated }
    public var isHighlightToEditEnabled: Bool { canUseHighlightToEdit && isEditModeEnabled }
    public var canUseSpokenShortcuts: Bool { isLicenseActivated }
    public var canUseAppContext: Bool { isLicenseActivated }

    public var hasConfiguredAIProvider: Bool {
        switch provider {
        case .groq:
            return !groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openai:
            return !openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .anthropic:
            return !anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gemini:
            return !geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openrouter:
            return !openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .custom:
            return !customApiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cloudflare:
            return true
        }
    }

    public var configuredAIProviderName: String {
        switch provider {
        case .groq: return "Groq Cloud"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter"
        case .custom:
            if customApiUrl.contains("localhost") || customApiUrl.contains("127.0.0.1") {
                return "Local Ollama"
            }
            return "Custom AI Endpoint"
        case .cloudflare: return "Cloudflare Gateway"
        }
    }

    // App-Specific Persona & Style Configurations
    public var personalChatStyle: String // "formal", "casual", "veryCasual" (no caps, less punct)
    public var workChatStyle: String     // "formal", "casual", "excited"
    public var emailStyle: String        // "formal", "casual", "excited"
    public var aiCleanupLevel: String    // "none" (exact verbatim), "light" (filler & grammar), "medium" (clarity & conciseness)

    public var isSoundEffectsEnabled: Bool {
        get { playSounds }
        set { playSounds = newValue }
    }

    public static let `default` = MinaConfig(
        provider: .groq,
        cloudflareGatewayUrl: "https://krishra.com/api/minaflow",
        cloudflareApiToken: "",
        groqApiKey: "",
        openaiApiKey: "",
        anthropicApiKey: "",
        openrouterApiKey: "",
        geminiApiKey: "",
        geminiModel: "gemini-2.0-flash",
        customApiUrl: "https://api.openai.com/v1",
        customApiKey: "",
        customModel: "gpt-4o-mini",
        whisperModel: "whisper-large-v3-turbo",
        llmModel: "openai/gpt-oss-20b",
        hotkey: "rightCommand",
        mode: "toggle",
        languageMode: "manual",
        selectedLanguages: ["English"],
        toneMode: "veryCasual",
        snippets: [
            "my linkedin": "https://linkedin.com",
            "my meeting link": "https://meet.google.com"
        ],
        playSounds: true,
        customVocabulary: [],
        systemPromptOverride: nil,
        licenseKey: "",
        licenseInstanceId: "",
        isLicenseActivated: false,
        dodoEnvironment: "live",
        trialDictationsUsed: 0,
        appTheme: "light",
        autoFailoverOnRateLimit: true,
        isBrowserURLExtractionEnabled: true,
        hudStyle: "pill",
        showDockIcon: false,
        sttProvider: .localWhisper,
        deepgramApiKey: "",
        deepgramModel: "nova-3",
        cohereApiKey: "",
        sonioxApiKey: "",
        localWhisperModel: "turbo",
        hinglishModel: "apex-q8",
        isAIPolishEnabled: false,
        voiceMacros: [:],
        isEditModeEnabled: false,
        editModeHotkey: "⌥ Space",
        personalChatStyle: "casual",
        workChatStyle: "formal",
        emailStyle: "formal",
        aiCleanupLevel: "light"
    )

    public init(
        provider: AIProvider = .groq,
        cloudflareGatewayUrl: String = "https://krishra.com/api/minaflow",
        cloudflareApiToken: String = "",
        groqApiKey: String = "",
        openaiApiKey: String = "",
        anthropicApiKey: String = "",
        openrouterApiKey: String = "",
        geminiApiKey: String = "",
        geminiModel: String = "gemini-2.0-flash",
        customApiUrl: String = "https://api.openai.com/v1",
        customApiKey: String = "",
        customModel: String = "gpt-4o-mini",
        whisperModel: String = "whisper-large-v3-turbo",
        llmModel: String = "openai/gpt-oss-20b",
        hotkey: String = "rightCommand",
        mode: String = "toggle",
        languageMode: String = "manual",
        selectedLanguages: [String] = ["English"],
        toneMode: String = "veryCasual",
        snippets: [String: String] = [:],
        playSounds: Bool = true,
        customVocabulary: [String] = [],
        systemPromptOverride: String? = nil,
        licenseKey: String = "",
        licenseInstanceId: String = "",
        isLicenseActivated: Bool = false,
        dodoEnvironment: String = "live",
        trialDictationsUsed: Int = 0,
        appTheme: String = "light",
        autoFailoverOnRateLimit: Bool = true,
        isBrowserURLExtractionEnabled: Bool = true,
        hudStyle: String = "pill",
        showDockIcon: Bool = false,
        sttProvider: STTProvider = .localWhisper,
        deepgramApiKey: String = "",
        deepgramModel: String = "nova-3",
        cohereApiKey: String = "",
        sonioxApiKey: String = "",
        localWhisperModel: String = "turbo",
        hinglishModel: String = "apex-q8",
        isAIPolishEnabled: Bool = false,
        voiceMacros: [String: String] = [:],
        isEditModeEnabled: Bool = false,
        editModeHotkey: String = "⌥ Space",
        personalChatStyle: String = "casual",
        workChatStyle: String = "formal",
        emailStyle: String = "formal",
        aiCleanupLevel: String = "light"
    ) {
        self.provider = provider
        self.cloudflareGatewayUrl = cloudflareGatewayUrl
        self.cloudflareApiToken = cloudflareApiToken
        self.groqApiKey = groqApiKey
        self.openaiApiKey = openaiApiKey
        self.anthropicApiKey = anthropicApiKey
        self.openrouterApiKey = openrouterApiKey
        self.geminiApiKey = geminiApiKey
        self.geminiModel = geminiModel
        self.customApiUrl = customApiUrl
        self.customApiKey = customApiKey
        self.customModel = customModel
        self.whisperModel = whisperModel
        self.llmModel = llmModel
        self.hotkey = hotkey
        self.mode = mode
        self.languageMode = languageMode
        self.selectedLanguages = selectedLanguages
        self.toneMode = toneMode
        self.snippets = snippets
        self.playSounds = playSounds
        self.customVocabulary = customVocabulary
        self.systemPromptOverride = systemPromptOverride
        self.licenseKey = licenseKey
        self.licenseInstanceId = licenseInstanceId
        self.isLicenseActivated = isLicenseActivated
        self.dodoEnvironment = dodoEnvironment
        self.trialDictationsUsed = trialDictationsUsed
        self.appTheme = appTheme
        self.autoFailoverOnRateLimit = autoFailoverOnRateLimit
        self.isBrowserURLExtractionEnabled = isBrowserURLExtractionEnabled
        self.hudStyle = hudStyle
        self.showDockIcon = showDockIcon
        self.sttProvider = sttProvider
        self.deepgramApiKey = deepgramApiKey
        self.deepgramModel = deepgramModel
        self.cohereApiKey = cohereApiKey
        self.sonioxApiKey = sonioxApiKey
        self.localWhisperModel = localWhisperModel
        self.hinglishModel = hinglishModel
        self.isAIPolishEnabled = isAIPolishEnabled
        self.voiceMacros = voiceMacros
        self.isEditModeEnabled = isEditModeEnabled
        self.editModeHotkey = editModeHotkey
        self.personalChatStyle = personalChatStyle
        self.workChatStyle = workChatStyle
        self.emailStyle = emailStyle
        self.aiCleanupLevel = aiCleanupLevel
    }

    enum CodingKeys: String, CodingKey {
        case provider, cloudflareGatewayUrl, cloudflareApiToken
        case groqApiKey, openaiApiKey, anthropicApiKey, openrouterApiKey
        case geminiApiKey, geminiModel
        case customApiUrl, customApiKey, customModel
        case whisperModel, llmModel
        case hotkey, mode, languageMode, selectedLanguages, toneMode, snippets
        case playSounds, customVocabulary, systemPromptOverride
        case licenseKey, licenseInstanceId, isLicenseActivated, dodoEnvironment, trialDictationsUsed
        case appTheme
        case autoFailoverOnRateLimit
        case isBrowserURLExtractionEnabled, hudStyle, showDockIcon
        case sttProvider, deepgramApiKey, deepgramModel, cohereApiKey, sonioxApiKey
        case localWhisperModel, hinglishModel, isAIPolishEnabled, voiceMacros, isEditModeEnabled, editModeHotkey
        case personalChatStyle, workChatStyle, emailStyle, aiCleanupLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.provider = try container.decodeIfPresent(AIProvider.self, forKey: CodingKeys.provider) ?? .groq
        self.cloudflareGatewayUrl = "https://krishra.com/api/minaflow"
        self.cloudflareApiToken = try container.decodeIfPresent(String.self, forKey: CodingKeys.cloudflareApiToken) ?? ""
        self.groqApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.groqApiKey) ?? ""
        self.openaiApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.openaiApiKey) ?? ""
        self.anthropicApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.anthropicApiKey) ?? ""
        self.openrouterApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.openrouterApiKey) ?? ""
        self.geminiApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.geminiApiKey) ?? ""
        self.geminiModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.geminiModel) ?? "gemini-2.0-flash"
        self.customApiUrl = try container.decodeIfPresent(String.self, forKey: CodingKeys.customApiUrl) ?? "https://api.openai.com/v1"
        self.customApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.customApiKey) ?? ""
        self.customModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.customModel) ?? "gpt-4o-mini"
        self.whisperModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.whisperModel) ?? "whisper-large-v3-turbo"
        self.llmModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.llmModel) ?? "openai/gpt-oss-20b"
        self.hotkey = try container.decodeIfPresent(String.self, forKey: CodingKeys.hotkey) ?? "rightCommand"
        self.mode = try container.decodeIfPresent(String.self, forKey: CodingKeys.mode) ?? "toggle"
        self.languageMode = try container.decodeIfPresent(String.self, forKey: CodingKeys.languageMode) ?? "manual"
        self.selectedLanguages = try container.decodeIfPresent([String].self, forKey: CodingKeys.selectedLanguages) ?? ["English"]
        let polishEnabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isAIPolishEnabled) ?? false
        self.isAIPolishEnabled = polishEnabled
        let rawTone = try container.decodeIfPresent(String.self, forKey: CodingKeys.toneMode) ?? "veryCasual"
        self.toneMode = polishEnabled ? rawTone : "veryCasual"
        self.snippets = try container.decodeIfPresent([String: String].self, forKey: CodingKeys.snippets) ?? [:]
        self.playSounds = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.playSounds) ?? true
        self.customVocabulary = try container.decodeIfPresent([String].self, forKey: CodingKeys.customVocabulary) ?? []
        self.systemPromptOverride = try container.decodeIfPresent(String.self, forKey: CodingKeys.systemPromptOverride)
        self.licenseKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.licenseKey) ?? ""
        self.licenseInstanceId = try container.decodeIfPresent(String.self, forKey: CodingKeys.licenseInstanceId) ?? ""
        self.isLicenseActivated = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isLicenseActivated) ?? false
        self.dodoEnvironment = try container.decodeIfPresent(String.self, forKey: CodingKeys.dodoEnvironment) ?? "live"
        self.trialDictationsUsed = try container.decodeIfPresent(Int.self, forKey: CodingKeys.trialDictationsUsed) ?? 0
        self.appTheme = try container.decodeIfPresent(String.self, forKey: CodingKeys.appTheme) ?? "light"
        self.autoFailoverOnRateLimit = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.autoFailoverOnRateLimit) ?? true
        self.isBrowserURLExtractionEnabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isBrowserURLExtractionEnabled) ?? true
        self.hudStyle = try container.decodeIfPresent(String.self, forKey: CodingKeys.hudStyle) ?? "pill"
        self.showDockIcon = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.showDockIcon) ?? false
        self.sttProvider = try container.decodeIfPresent(STTProvider.self, forKey: CodingKeys.sttProvider) ?? .localWhisper
        self.deepgramApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.deepgramApiKey) ?? ""
        self.deepgramModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.deepgramModel) ?? "nova-3"
        self.cohereApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.cohereApiKey) ?? ""
        self.sonioxApiKey = try container.decodeIfPresent(String.self, forKey: CodingKeys.sonioxApiKey) ?? ""
        self.localWhisperModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.localWhisperModel) ?? "turbo"
        self.hinglishModel = try container.decodeIfPresent(String.self, forKey: CodingKeys.hinglishModel) ?? "apex-q8"
        self.isAIPolishEnabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isAIPolishEnabled) ?? false
        self.voiceMacros = try container.decodeIfPresent([String: String].self, forKey: CodingKeys.voiceMacros) ?? [:]
        self.isEditModeEnabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isEditModeEnabled) ?? false
        self.editModeHotkey = try container.decodeIfPresent(String.self, forKey: CodingKeys.editModeHotkey) ?? "⌥ Space"
        self.personalChatStyle = try container.decodeIfPresent(String.self, forKey: CodingKeys.personalChatStyle) ?? "casual"
        self.workChatStyle = try container.decodeIfPresent(String.self, forKey: CodingKeys.workChatStyle) ?? "formal"
        self.emailStyle = try container.decodeIfPresent(String.self, forKey: CodingKeys.emailStyle) ?? "formal"
        self.aiCleanupLevel = try container.decodeIfPresent(String.self, forKey: CodingKeys.aiCleanupLevel) ?? "light"
    }
}

import Combine

public class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()

    private let fileManager = FileManager.default
    private let configDirectory: URL
    private let configFile: URL

    @Published public private(set) var config: MinaConfig

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("MinaType", isDirectory: true)
        self.configFile = configDirectory.appendingPathComponent("config.json")
        self.config = MinaConfig.default

        load()
    }

    public func load() {
        guard fileManager.fileExists(atPath: configFile.path) else {
            save()
            return
        }

        do {
            let data = try Data(contentsOf: configFile)
            let decoded = try JSONDecoder().decode(MinaConfig.self, from: data)
            self.config = decoded

            // Normalize legacy groq models if needed
            if self.config.provider == .groq {
                let legacyGroq = ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "llama-3.3-70b", "mixtral-8x7b-32768", "llama3-8b-8192"]
                if legacyGroq.contains(self.config.llmModel) || self.config.llmModel.isEmpty {
                    self.config.llmModel = "openai/gpt-oss-20b"
                    save()
                }
            }

            // Ensure bogus / offline mock activations without a valid instance ID do not persist
            if self.config.isLicenseActivated && self.config.licenseInstanceId.isEmpty {
                self.config.isLicenseActivated = false
                self.config.licenseKey = ""
                save()
            }

            // Ensure pro features remain disabled on free tier
            if !self.config.isLicenseActivated {
                if self.config.isAIPolishEnabled {
                    self.config.isAIPolishEnabled = false
                    save()
                }
                if self.config.isEditModeEnabled {
                    self.config.isEditModeEnabled = false
                    save()
                }
            }

            // Always ensure production live Dodo Payments API is used
            if self.config.dodoEnvironment == "test" {
                self.config.dodoEnvironment = "live"
                save()
            }

            // Ensure valid language mode and single language selection (no auto mode)
            if self.config.languageMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.config.languageMode.lowercased() == "auto" {
                self.config.languageMode = "manual"
                save()
            }
            if self.config.selectedLanguages.isEmpty {
                self.config.selectedLanguages = ["English"]
                save()
            } else if self.config.selectedLanguages.count > 1 {
                self.config.selectedLanguages = [self.config.selectedLanguages.first ?? "English"]
                save()
            }

            // If AI Polish is off, always ensure tone is set to Direct (veryCasual)
            if !self.config.isAIPolishEnabled {
                self.config.toneMode = "veryCasual"
                save()
            }
        } catch {
            print("[ConfigManager] Failed to load config, using default:", error)
        }
    }

    public func save() {
        do {
            if !fileManager.fileExists(atPath: configDirectory.path) {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
        } catch {
            print("[ConfigManager] Failed to save config:", error)
        }
    }

    public func updateProvider(_ provider: AIProvider) {
        config.provider = provider
        switch provider {
        case .groq:
            config.whisperModel = "whisper-large-v3-turbo"
            config.llmModel = "openai/gpt-oss-20b"
        case .openai:
            config.whisperModel = "whisper-1"
            config.llmModel = "gpt-4o-mini"
        case .anthropic:
            config.whisperModel = "whisper-large-v3-turbo"
            config.llmModel = "claude-3-5-haiku-latest"
        case .gemini:
            config.whisperModel = "whisper-large-v3-turbo"
            config.llmModel = config.geminiModel.isEmpty ? "gemini-2.0-flash" : config.geminiModel
        case .openrouter:
            config.whisperModel = "openai/whisper-large-v3-turbo"
            config.llmModel = "google/gemini-2.0-flash-001"
        case .custom:
            config.whisperModel = "whisper-1"
            config.llmModel = config.customModel.isEmpty ? "gpt-4o-mini" : config.customModel
        case .cloudflare:
            config.whisperModel = "@cf/openai/whisper-large-v3-turbo"
            config.llmModel = "@cf/meta/llama-3.1-8b-instruct-fast"
        }
        save()
    }

    public func updateApiKey(_ key: String) {
        config.groqApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateGeminiApiKey(_ key: String) {
        config.geminiApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateGeminiModel(_ model: String) {
        config.geminiModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.provider == .gemini {
            config.llmModel = config.geminiModel
        }
        save()
    }

    public func updateCohereApiKey(_ key: String) {
        config.cohereApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateSonioxApiKey(_ key: String) {
        config.sonioxApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateSpokenLanguage(_ lang: String) {
        let trimmed = lang.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? "English" : trimmed

        if normalized.lowercased() == "hinglish" {
            let hModel = config.hinglishModel.isEmpty ? "apex-q8" : config.hinglishModel
            let isHinglishReady = LocalWhisperEngine.shared.isModelDownloaded(hModel) ||
                                  LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                                  LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
            if !isHinglishReady {
                LocalWhisperEngine.promptForHinglishDownloadIfNeeded(
                    onAccept: {
                        self.config.selectedLanguages = ["Hinglish"]
                        self.config.languageMode = "hinglish"
                        self.save()
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowLanguagesUpdated"), object: nil)
                        }
                    },
                    onCancel: {
                        // User cancelled download -> revert to previous language or default to English
                        if self.config.selectedLanguages == ["Hinglish"] {
                            self.config.selectedLanguages = ["English"]
                            self.config.languageMode = "manual"
                            self.save()
                        }
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowLanguagesUpdated"), object: nil)
                        }
                    }
                )
                return
            }
            config.selectedLanguages = ["Hinglish"]
            config.languageMode = "hinglish"
        } else if normalized.lowercased() == "hindi" {
            config.selectedLanguages = [normalized]
            config.languageMode = "hindi"
        } else {
            config.selectedLanguages = [normalized]
            config.languageMode = "manual"
        }
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowLanguagesUpdated"), object: nil)
        }
    }

    public func updateOpenAIApiKey(_ key: String) {
        config.openaiApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateAnthropicApiKey(_ key: String) {
        config.anthropicApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateOpenRouterApiKey(_ key: String) {
        config.openrouterApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateCustomConfig(url: String, key: String, model: String) {
        config.customApiUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        config.customApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        config.customModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        config.llmModel = config.customModel
        save()
    }

    public func setLicenseActivated(key: String, instanceId: String) {
        config.licenseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        config.licenseInstanceId = instanceId
        config.isLicenseActivated = true
        save()
    }

    public func activateLicenseLocally(licenseKey: String, instanceId: String) {
        setLicenseActivated(key: licenseKey, instanceId: instanceId)
    }

    public func updateCustomApiKey(_ key: String) {
        config.customApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateCustomModel(_ model: String) {
        config.customModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func deactivateLicenseLocally() {
        config.licenseKey = ""
        config.licenseInstanceId = ""
        config.isLicenseActivated = false
        config.isAIPolishEnabled = false
        config.isEditModeEnabled = false
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
        }
    }

    public func updateDodoEnvironment(_ env: String) {
        config.dodoEnvironment = env
        save()
    }

    public func updateTheme(_ theme: String) {
        config.appTheme = theme
        save()
    }

    public func incrementTrialUsage() {
        DispatchQueue.main.async {
            self.config.trialDictationsUsed += 1
            self.save()
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
        }
    }

    public func updateTrialDictationsUsed(_ count: Int) {
        DispatchQueue.main.async {
            self.config.trialDictationsUsed = count
            self.save()
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
        }
    }

    public func updateMode(_ mode: String) {
        config.mode = mode
        save()
    }

    public func updateHotkey(_ hotkey: String) {
        config.hotkey = hotkey
        save()
        NotificationCenter.default.post(name: NSNotification.Name("MinaFlowHotkeyChanged"), object: nil)
    }

    public func updateLlmModel(_ model: String) {
        config.llmModel = model
        save()
    }

    public func updateAutoFailover(_ enabled: Bool) {
        config.autoFailoverOnRateLimit = enabled
        save()
    }

    public func updateLanguageMode(_ mode: String) {
        config.languageMode = mode
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowLanguagesUpdated"), object: nil)
        }
    }

    public func updateSelectedLanguages(_ languages: [String]) {
        updateSpokenLanguage(languages.first ?? "English")
    }

    public func updateToneMode(_ mode: String) {
        config.toneMode = mode
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowToneUpdated"), object: nil)
        }
    }

    public func updatePersonalChatStyle(_ style: String) {
        config.personalChatStyle = style
        save()
    }

    public func updateWorkChatStyle(_ style: String) {
        config.workChatStyle = style
        save()
    }

    public func updateEmailStyle(_ style: String) {
        config.emailStyle = style
        save()
    }

    public func updateAiCleanupLevel(_ level: String) {
        config.aiCleanupLevel = level
        save()
    }

    public func setSnippet(trigger: String, expansion: String) {
        let key = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        config.snippets[key] = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func removeSnippet(trigger: String) {
        let key = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        config.snippets.removeValue(forKey: key)
        save()
    }

    public func updateSnippets(_ newSnippets: [String: String]) {
        config.snippets = newSnippets
        save()
    }


    public func updateBrowserURLExtraction(_ enabled: Bool) {
        config.isBrowserURLExtractionEnabled = enabled
        save()
    }

    public func updateHudStyle(_ style: String) {
        config.hudStyle = style
        save()
    }

    public func updateSoundEffects(_ enabled: Bool) {
        config.playSounds = enabled
        save()
    }

    public func updateCustomVocabulary(_ vocab: [String]) {
        config.customVocabulary = vocab
        save()
    }

    public func updatePlaySounds(_ enabled: Bool) {
        config.playSounds = enabled
        save()
    }

    public func updateSTTProvider(_ provider: STTProvider) {
        config.sttProvider = provider
        save()
    }

    public func updateGroqApiKey(_ key: String) {
        config.groqApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateOpenaiApiKey(_ key: String) {
        config.openaiApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateCustomApiUrl(_ url: String) {
        config.customApiUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateDeepgramApiKey(_ key: String) {
        config.deepgramApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateDeepgramModel(_ model: String) {
        config.deepgramModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func updateShowDockIcon(_ show: Bool) {
        config.showDockIcon = show
        save()
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(show ? .regular : .accessory)
            if show {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    public func updateLocalWhisperModel(_ model: String) {
        config.localWhisperModel = model
        save()
    }

    public func updateHinglishModel(_ model: String) {
        config.hinglishModel = model
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowHinglishModelUpdated"), object: nil)
        }
    }

    public func updateAIPolishEnabled(_ enabled: Bool) {
        config.isAIPolishEnabled = enabled
        if !enabled {
            config.toneMode = "veryCasual"
        }
        if enabled && config.isLicenseActivated {
            // Automatically turn on Highlight-to-Edit when AI Polish is on
            config.isEditModeEnabled = true
        }
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowAIPolishUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowToneUpdated"), object: nil)
        }
    }

    public func setVoiceMacro(trigger: String, snippet: String) {
        let key = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        config.voiceMacros[key] = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    public func removeVoiceMacro(trigger: String) {
        let key = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        config.voiceMacros.removeValue(forKey: key)
        save()
    }

    public func updateEditModeEnabled(_ enabled: Bool) {
        config.isEditModeEnabled = enabled
        save()
    }

    public func updateEditModeHotkey(_ hotkey: String) {
        config.editModeHotkey = hotkey
        save()
    }
}

