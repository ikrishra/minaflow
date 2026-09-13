import SwiftUI
import AppKit
import ServiceManagement
import CoreAudio
import UniformTypeIdentifiers

// MARK: - MinaFlow Dashboard View (Website-Grade Design System, Zero Emojis)
public struct DashboardView: View {
    @State public var selectedTab: Int
    @State private var isDarkMode: Bool = (ConfigManager.shared.config.appTheme == "dark")
    @State private var mode: String = ConfigManager.shared.config.mode
    @State private var hotkey: String = ConfigManager.shared.config.hotkey
    @State private var playSounds: Bool = ConfigManager.shared.config.playSounds
    @State private var toneMode: String = ConfigManager.shared.config.toneMode
    @State private var provider: AIProvider = ConfigManager.shared.config.provider == .cloudflare ? .groq : ConfigManager.shared.config.provider
    @State private var groqApiKey: String = ConfigManager.shared.config.groqApiKey
    @State private var openaiApiKey: String = ConfigManager.shared.config.openaiApiKey
    @State private var anthropicApiKey: String = ConfigManager.shared.config.anthropicApiKey
    @State private var openrouterApiKey: String = ConfigManager.shared.config.openrouterApiKey
    @State private var sttProvider: STTProvider = ConfigManager.shared.config.sttProvider
    @State private var deepgramApiKey: String = ConfigManager.shared.config.deepgramApiKey
    @State private var deepgramModel: String = ConfigManager.shared.config.deepgramModel
    @State private var customApiUrl: String = ConfigManager.shared.config.customApiUrl
    @State private var customApiKey: String = ConfigManager.shared.config.customApiKey
    @State private var customModel: String = ConfigManager.shared.config.customModel
    @State private var selectedModel: String = ConfigManager.shared.config.llmModel
    @State private var historyPage: Int = 1
    @State private var historyPageSize: Int = 10
    @State private var licenseKey: String = ConfigManager.shared.config.licenseKey
    @State private var licenseInstanceId: String = ConfigManager.shared.config.licenseInstanceId
    @State private var isLicenseActivated: Bool = ConfigManager.shared.config.isLicenseActivated
    @State private var isActivating: Bool = false
    @State private var isDeactivating: Bool = false
    @State private var copiedKey: Bool = false
    @State private var licenseMessage: String = ""
    @State private var isRevalidatingLicense: Bool = false
    @State private var apiKeySaved: Bool = false
    @State private var autoFailover: Bool = ConfigManager.shared.config.autoFailoverOnRateLimit
    @State private var isBrowserURLExtractionEnabled: Bool = ConfigManager.shared.config.isBrowserURLExtractionEnabled
    @State private var hudStyle: String = ConfigManager.shared.config.hudStyle
    @State private var languageMode: String = ConfigManager.shared.config.languageMode
    @State private var selectedLanguages: [String] = ConfigManager.shared.config.selectedLanguages
    @State private var showLanguagePickerModal: Bool = false
    @State private var languageSearchQuery: String = ""
    @State private var customVocabulary: [String] = ConfigManager.shared.config.customVocabulary
    @State private var newVocabWord: String = ""
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()
    @State private var showDockIcon: Bool = ConfigManager.shared.config.showDockIcon

    // App-Specific Persona & Style State
    @State private var personalChatStyle: String = ConfigManager.shared.config.personalChatStyle
    @State private var workChatStyle: String = ConfigManager.shared.config.workChatStyle
    @State private var emailStyle: String = ConfigManager.shared.config.emailStyle
    @State private var aiCleanupLevel: String = ConfigManager.shared.config.aiCleanupLevel
    @State private var showAppRules: Bool = false

    // Support & Feedback State
    @State private var feedbackCategory: String = "Bug Report"
    @State private var feedbackEmail: String = ""
    @State private var feedbackDescription: String = ""
    @State private var feedbackStatusMessage: String? = nil
    @State private var isSendingFeedback: Bool = false
    @State private var feedbackSentSuccess: Bool = false

    // Creator Challenge 100% OFF Claim State (Option A)
    @State private var showClaimForm: Bool = false
    @State private var claimEmail: String = ""
    @State private var claimMessageText: String = """
Hi Krishna,

I shared MinaFlow and would like to submit a Creator Bonus claim.

Post link(s): 
Platform(s): 
Total views or impressions: 
Purchase email (if already purchased): 
Proof screenshot(s) (logged-in account): [attach or link]

Thank you!
"""
    @State private var claimAttachedFiles: [(name: String, data: Data)] = []
    @State private var isSubmittingClaim: Bool = false
    @State private var claimStatusMessage: String? = nil
    @State private var claimSentSuccess: Bool = false

    // Voice Snippets & Local Whisper
    @ObservedObject private var whisperEngine = LocalWhisperEngine.shared
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var historySearchQuery: String = ""
    @State private var copiedRecordId: UUID? = nil
    @State private var sttSectionTab: Int = 0 // 0: Local Whisper, 1: Cloud STT, 2: Localhost
    @State private var snippets: [String: String] = ConfigManager.shared.config.snippets
    @State private var newTrigger: String = ""
    @State private var newExpansion: String = ""
    @State private var trialDictationsUsed: Int = ConfigManager.shared.config.trialDictationsUsed
    @State private var localWhisperModel: String = ConfigManager.shared.config.localWhisperModel
    @State private var hinglishModel: String = ConfigManager.shared.config.hinglishModel
    @State private var isAIPolishEnabled: Bool = ConfigManager.shared.config.isAIPolishEnabled
    @State private var isEditModeEnabled: Bool = ConfigManager.shared.config.isEditModeEnabled
    @State private var editModeHotkey: String = ConfigManager.shared.config.editModeHotkey
    @State private var isCopiedLicense: Bool = false
    @State private var highlightHinglishCard: Bool = false

    // Real-Time API Key Validation States
    @State private var groqValidationStatus: String? = nil
    @State private var groqIsValid: Bool? = nil
    @State private var isCheckingGroq: Bool = false

    @State private var deepgramValidationStatus: String? = nil
    @State private var deepgramIsValid: Bool? = nil
    @State private var isCheckingDeepgram: Bool = false

    @State private var customValidationStatus: String? = nil
    @State private var customIsValid: Bool? = nil
    @State private var isCheckingCustom: Bool = false

    @State private var openaiValidationStatus: String? = nil
    @State private var openaiIsValid: Bool? = nil
    @State private var isCheckingOpenAI: Bool = false

    @State private var anthropicValidationStatus: String? = nil
    @State private var anthropicIsValid: Bool? = nil
    @State private var isCheckingAnthropic: Bool = false

    @State private var openrouterValidationStatus: String? = nil
    @State private var openrouterIsValid: Bool? = nil
    @State private var isCheckingOpenRouter: Bool = false

    @State private var geminiApiKey: String = ConfigManager.shared.config.geminiApiKey
    @State private var geminiModel: String = ConfigManager.shared.config.geminiModel
    @State private var geminiValidationStatus: String? = nil
    @State private var geminiIsValid: Bool? = nil
    @State private var isCheckingGemini: Bool = false

    @State private var cohereApiKey: String = ConfigManager.shared.config.cohereApiKey
    @State private var cohereValidationStatus: String? = nil
    @State private var cohereIsValid: Bool? = nil
    @State private var isCheckingCohere: Bool = false

    @State private var sonioxApiKey: String = ConfigManager.shared.config.sonioxApiKey
    @State private var sonioxValidationStatus: String? = nil
    @State private var sonioxIsValid: Bool? = nil
    @State private var isCheckingSoniox: Bool = false

    @State private var showOpenAIModal: Bool = false

    public init(initialTab: Int = 0, initialSubTab: Int? = nil) {
        _selectedTab = State(initialValue: initialTab)
        if let subTab = initialSubTab {
            _sttSectionTab = State(initialValue: subTab)
        }
    }

    // Modern Website Design Tokens (minatype/website)
    private var brandOrange: Color { Color(red: 1.0, green: 0.333, blue: 0.0) } // #FF5500
    private var bg: Color {
        isDarkMode ? Color(red: 9/255, green: 9/255, blue: 11/255) : Color(red: 250/255, green: 250/255, blue: 252/255)
    }
    private var cardBg: Color {
        isDarkMode ? Color(red: 18/255, green: 18/255, blue: 21/255) : Color.white
    }
    private var cardBorder: Color {
        isDarkMode ? Color(red: 39/255, green: 39/255, blue: 42/255) : Color(red: 228/255, green: 228/255, blue: 231/255)
    }
    private var inputBg: Color {
        isDarkMode ? Color(red: 12/255, green: 12/255, blue: 15/255) : Color(red: 244/255, green: 244/255, blue: 246/255)
    }
    private var textPrimary: Color {
        isDarkMode ? Color.white : Color(red: 9/255, green: 9/255, blue: 11/255)
    }
    private var textMuted: Color {
        isDarkMode ? Color(red: 161/255, green: 161/255, blue: 170/255) : Color(red: 113/255, green: 113/255, blue: 122/255)
    }
    private var navContainerBg: Color {
        isDarkMode ? Color(red: 20/255, green: 20/255, blue: 24/255) : Color(red: 241/255, green: 241/255, blue: 244/255)
    }

    private var sidebarBg: Color {
        isDarkMode ? Color(red: 13/255, green: 13/255, blue: 16/255) : Color(red: 242/255, green: 242/255, blue: 245/255)
    }

    private var hotkeyDisplayString: String {
        switch hotkey {
        case "rightOption": return "Right Option"
        case "fn": return "Fn (Globe)"
        case "rightCommand": return "Right Command"
        case "leftOption": return "Left Option"
        case "option+space": return "⌥ Space"
        default: return hotkey.capitalized
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar Navigation List
            sidebarView
                .frame(width: 220)
                .background(sidebarBg)

            Rectangle()
                .fill(cardBorder)
                .frame(width: 1)

            // Right Main Content Area
            VStack(spacing: 0) {
                topHeaderBar

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 16) {
                            ZStack {
                                ScrollResetHelper(trigger: selectedTab)
                                    .frame(width: 0, height: 0)
                                    .opacity(0.001)

                                Color.clear
                                    .frame(width: 0, height: 0)
                                    .id("scrollTopTarget")
                            }
                            .frame(height: 0)

                            switch selectedTab {
                            case 0:
                                overviewTab
                            case 1:
                                historyTab
                            case 2:
                                modelsTab
                            case 3:
                                aiPolishTab
                            case 4:
                                shortcutsTab
                            case 5:
                                settingsTab
                            case 6:
                                accountTab
                            case 7:
                                supportFeedbackTab
                            default:
                                overviewTab
                            }
                        }
                        .id("tab_content_\(selectedTab)")
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .onChange(of: selectedTab) { _ in
                        DispatchQueue.main.async {
                            proxy.scrollTo("scrollTopTarget", anchor: .top)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowScrollToHinglishModels"))) { _ in
                        self.selectedTab = 2
                        self.sttSectionTab = 0
                        self.highlightHinglishCard = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo("hinglishModelsCard", anchor: .center)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                self.highlightHinglishCard = false
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg)
        }
        .frame(width: 960, height: 700)
        .background(bg.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowTrialUpdated"))) { _ in
            let cfg = ConfigManager.shared.config
            self.trialDictationsUsed = cfg.trialDictationsUsed
            self.isLicenseActivated  = cfg.isLicenseActivated
            if !cfg.isLicenseActivated {
                self.isAIPolishEnabled = false
                self.isEditModeEnabled = false
            }
            if !cfg.licenseKey.isEmpty && self.licenseKey.isEmpty {
                self.licenseKey = cfg.licenseKey
            }
            self.licenseInstanceId   = cfg.licenseInstanceId
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowLanguagesUpdated"))) { _ in
            let cfg = ConfigManager.shared.config
            self.selectedLanguages = cfg.selectedLanguages
            self.languageMode = cfg.languageMode
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowToneUpdated"))) { _ in
            self.toneMode = ConfigManager.shared.config.toneMode
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowHinglishModelUpdated"))) { _ in
            self.hinglishModel = ConfigManager.shared.config.hinglishModel
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowSwitchSpeechSubTab"))) { notif in
            if let sub = notif.object as? Int {
                self.selectedTab = 2
                self.sttSectionTab = sub
            }
        }
        .onAppear {
            let cfg = ConfigManager.shared.config
            self.languageMode = cfg.languageMode
            self.selectedLanguages = cfg.selectedLanguages
            self.showDockIcon = cfg.showDockIcon
            self.localWhisperModel = cfg.localWhisperModel
            self.hinglishModel = cfg.hinglishModel
            self.isAIPolishEnabled = cfg.isAIPolishEnabled
            self.isEditModeEnabled = cfg.isEditModeEnabled
            self.editModeHotkey = cfg.editModeHotkey
            self.customVocabulary = cfg.customVocabulary
            self.snippets = cfg.snippets
            self.playSounds = cfg.playSounds
            self.hudStyle = cfg.hudStyle
            self.toneMode = cfg.toneMode
            self.anthropicApiKey = cfg.anthropicApiKey
            self.openrouterApiKey = cfg.openrouterApiKey
            self.geminiApiKey = cfg.geminiApiKey
            self.geminiModel = cfg.geminiModel
            self.openaiApiKey = cfg.openaiApiKey
            self.groqApiKey = cfg.groqApiKey
            self.cohereApiKey = cfg.cohereApiKey
            self.sonioxApiKey = cfg.sonioxApiKey

            // Recheck license with Dodo when dashboard opens
            DodoPaymentsService.shared.recheckLicenseInBackground()
        }
        .overlay(
            Group {
                if showOpenAIModal {
                    OpenAICompatibleConfigModal(
                        isPresented: $showOpenAIModal,
                        apiUrl: $customApiUrl,
                        modelId: $customModel,
                        apiKey: $customApiKey,
                        isDarkMode: isDarkMode
                    ) { newUrl, newModel, newKey in
                        ConfigManager.shared.updateCustomApiUrl(newUrl)
                        ConfigManager.shared.updateCustomModel(newModel)
                        ConfigManager.shared.updateCustomApiKey(newKey)
                        apiKeySaved = true
                    }
                    .transition(.opacity)
                }
            }
        )
    }

    // MARK: - Left Sidebar Navigation View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Header
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let img = NSImage(contentsOfFile: Bundle.main.resourcePath.map { "\($0)/AppLogo.png" } ?? "") ?? Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap({ NSImage(contentsOfFile: $0) }) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .cornerRadius(8)
                            .shadow(color: brandOrange.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(brandOrange)
                                .frame(width: 34, height: 34)
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("MinaFlow")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)
                        Text("Mac Dashboard")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(textMuted)
                    }
                }

                // License Status Chip
                if isLicenseActivated {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9.5))
                        Text("PRO UNLOCKED")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(brandOrange)
                            .frame(width: 5, height: 5)
                        Text("FREE TIER (GPU)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(brandOrange.opacity(0.1))
                    .foregroundColor(brandOrange)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(brandOrange.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle()
                .fill(cardBorder.opacity(0.7))
                .frame(height: 1)
                .padding(.bottom, 8)

            // Vertical List of Navigation Tabs
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    sidebarTabItem(tag: 0, title: "Overview", icon: "chart.bar.fill")
                    sidebarTabItem(tag: 1, title: "History", icon: "clock.arrow.circlepath", badge: historyManager.records.count > 0 ? "\(historyManager.records.count)" : nil)
                    sidebarTabItem(tag: 2, title: "Speech Models", icon: "waveform")
                    sidebarTabItem(tag: 3, title: "AI Polish", icon: "sparkles", badge: isLicenseActivated ? nil : "PRO")
                    sidebarTabItem(tag: 4, title: "Shortcuts", icon: "text.badge.plus")
                    sidebarTabItem(tag: 5, title: "Preferences", icon: "slider.horizontal.3")
                    sidebarTabItem(tag: 6, title: "Account & Pro", icon: "key.fill")
                    sidebarTabItem(tag: 7, title: "Support & Feedback", icon: "lifepreserver.fill")
                }
                .padding(.horizontal, 10)
            }

            Spacer()

            Rectangle()
                .fill(cardBorder.opacity(0.7))
                .frame(height: 1)

            // Bottom Actions: Replay Onboarding + Theme Toggle + Version
            VStack(spacing: 8) {
                Button(action: {
                    OnboardingWindowController.shared.show()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 12))
                            .foregroundColor(brandOrange)
                        Text("Replay Onboarding Guide")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(inputBg)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(cardBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Replay the interactive onboarding setup and tutorial guide")

                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDarkMode.toggle()
                            ConfigManager.shared.updateTheme(isDarkMode ? "dark" : "light")
                            DashboardWindowController.shared.applyTheme(isDark: isDarkMode)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 11))
                                .foregroundColor(isDarkMode ? Color(white: 0.9) : Color(red: 82/255, green: 82/255, blue: 91/255))
                            Text(isDarkMode ? "Light Mode" : "Dark Mode")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(textMuted)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(inputBg)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
                    Text("v\(appVer)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(textMuted.opacity(0.7))
                }
            }
            .padding(12)
        }
    }

    private func sidebarTabItem(tag: Int, title: String, icon: String, badge: String? = nil) -> some View {
        let isSelected = selectedTab == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tag
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? brandOrange : textMuted)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? textPrimary : textMuted)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(b == "PRO" ? brandOrange.opacity(0.15) : cardBorder)
                        .foregroundColor(b == "PRO" ? brandOrange : textMuted)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(brandOrange.opacity(isDarkMode ? 0.14 : 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(brandOrange.opacity(0.25), lineWidth: 1)
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            Text(currentTabTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(textPrimary)

            Spacer()

            // Trigger Hotkey chip
            HStack(spacing: 5) {
                Image(systemName: "keyboard")
                    .font(.system(size: 10))
                    .foregroundColor(brandOrange)
                Text(hotkeyDisplayString)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cardBg)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))

            if !isLicenseActivated {
                Button(action: { openCheckoutPage() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("Get Lifetime Pro ($1.99)")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(brandOrange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(cardBg.opacity(0.7))
        .overlay(Rectangle().frame(height: 1).foregroundColor(cardBorder), alignment: .bottom)
    }

    private var currentTabTitle: String {
        switch selectedTab {
        case 0: return "Dashboard Overview"
        case 1: return "Dictation History"
        case 2: return "Speech Recognition Models"
        case 3: return "AI Polish & Verbal De-clutter"
        case 4: return "Shortcuts & Voice Macros"
        case 5: return "App Preferences"
        case 6: return "Account & Lifetime Pro"
        case 7: return "Support & Feedback"
        default: return "Dashboard"
        }
    }

    // MARK: - Tab 0: Overview (Dashboard)
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card 1: Active Setup & Status
            websiteCard(title: "Active Setup & Status", icon: "bolt.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Ready to Voice Type")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: "command")
                                .font(.system(size: 10))
                                .foregroundColor(brandOrange)
                            Text(mode == "pushToTalk" ? "Hold \(hotkeyDisplayString)" : "Press \(hotkeyDisplayString)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(inputBg)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    // 4-Card Status Grid (2x2)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        overviewStatusCell(
                            title: "Shortcut Trigger",
                            value: hotkeyDisplayString,
                            subtitle: mode == "pushToTalk" ? "Hold to Speak" : "Press to Start / Stop",
                            icon: "command"
                        ) {
                            selectedTab = 0
                        }

                        overviewStatusCell(
                            title: "Speech Engine",
                            value: sttProvider == .localWhisper ? "Whisper \(localWhisperModel.capitalized)" : sttProvider.displayName,
                            subtitle: "100% Offline & Private",
                            icon: "cpu"
                        ) {
                            selectedTab = 2
                        }

                        let isEnglishModel = LocalWhisperEngine.shared.isEnglishOnlyModel(localWhisperModel) && (sttProvider == .localWhisper)
                        overviewStatusCell(
                            title: "Spoken Language",
                            value: isEnglishModel ? "English (Locked)" : (selectedLanguages.first ?? "English"),
                            subtitle: isEnglishModel ? "English-Only Model Active" : "1 Language Active",
                            icon: "globe"
                        ) {
                            selectedTab = 5
                        }

                        overviewStatusCell(
                            title: "Accessibility Access",
                            value: PasteInjector.shared.isAccessibilityGranted() ? "Ready to Type" : "Permission Needed",
                            subtitle: "Direct in-app text injection",
                            icon: "checkmark.shield.fill"
                        ) {
                            PasteInjector.shared.openAccessibilitySettings()
                        }
                    }
                }
            }

            // Productivity Metrics
            websiteCard(title: "Productivity", icon: "chart.line.uptrend.xyaxis") {
                HStack(spacing: 12) {
                    metricCard(
                        title: "Dictations",
                        value: "\(historyManager.totalTranscriptions)",
                        subtitle: "Voice sessions",
                        icon: "waveform"
                    )
                    metricCard(
                        title: "Words Spoken",
                        value: "\(historyManager.totalWords)",
                        subtitle: "Words voice-typed",
                        icon: "text.quote"
                    )
                    metricCard(
                        title: "Time Saved",
                        value: historyManager.timeSavedFormatted,
                        subtitle: "Estimated typing time saved",
                        icon: "clock.badge.checkmark"
                    )
                }
            }

            // Recent Dictations Preview
            websiteCard(title: "Recent Activity", icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    if historyManager.records.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "mic.slash")
                                    .font(.system(size: 20))
                                    .foregroundColor(textMuted)
                                Text("No dictations recorded yet.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textMuted)
                                Text("Hold \(hotkeyDisplayString) anywhere to start voice-typing.")
                                    .font(.system(size: 11))
                                    .foregroundColor(textMuted.opacity(0.8))
                            }
                            .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        ForEach(Array(historyManager.records.prefix(3))) { record in
                            recentRecordRow(record: record)
                            if record.id != historyManager.records.prefix(3).last?.id {
                                Divider().background(cardBorder.opacity(0.7))
                            }
                        }

                        HStack {
                            Spacer()
                            Button(action: { selectedTab = 1 }) {
                                Text("View All Dictations in History (\(historyManager.totalTranscriptions)) ->")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(brandOrange)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Compact Quick Actions Row (Side-by-side cards)
            HStack(spacing: 12) {
                // Card A: Setup Guide Tour
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(brandOrange)
                        Text("Interactive Setup")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(textPrimary)
                        Spacer()
                    }
                    Text("Replay the step-by-step walkthrough for microphone, permissions & hotkeys.")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Button(action: {
                        OnboardingWindowController.shared.show()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Replay Tour")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(brandOrange)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBg)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                // Card B: Free Pro Challenge or Pro Status
                VStack(alignment: .leading, spacing: 8) {
                    if !isLicenseActivated {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Get Pro 100% Free")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(textPrimary)
                            Spacer()
                            Text("FREE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.14))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        Text("Share MinaFlow on social media. 1,000+ views unlocks a free lifetime license key.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Button(action: {
                            selectedTab = 6
                        }) {
                            HStack(spacing: 4) {
                                Text("Learn More")
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(brandOrange)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("MinaFlow Pro Active")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(textPrimary)
                            Spacer()
                        }
                        Text("AI Polish, Highlight-to-Edit, and unlimited voice-typing are unlocked.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Button(action: {
                            selectedTab = 6
                        }) {
                            Text("Manage Account")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(brandOrange.opacity(0.12))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBg)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
            }
        }
    }

    private func overviewStatusCell(title: String, value: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(brandOrange)
                    Text(title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(textMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(textMuted.opacity(0.5))
                }
                Text(value)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(inputBg)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(cardBorder.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textMuted)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(brandOrange)
            }
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(textPrimary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(inputBg)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
    }

    private func recentRecordRow(record: HistoryRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 11))
                .foregroundColor(brandOrange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.text)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if !record.appName.isEmpty {
                        Text(record.appName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textMuted)
                    }
                    Text("\(record.wordCount) words")
                        .font(.system(size: 10))
                        .foregroundColor(textMuted)
                    Text(record.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(textMuted)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tab 1: History
    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(textMuted)
                    TextField("Search history by text or app...", text: $historySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !historySearchQuery.isEmpty {
                        Button(action: { historySearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(inputBg)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                Spacer()

                if !historyManager.records.isEmpty {
                    Button(action: {
                        let text = historyManager.records.map { "[\($0.timestamp)] (\($0.appName)): \($0.text)" }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("Export All")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        historyManager.clearAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear All")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(inputBg)
                        .foregroundColor(.red.opacity(0.8))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            let filtered = historyManager.records.filter { r in
                historySearchQuery.isEmpty ||
                r.text.localizedCaseInsensitiveContains(historySearchQuery) ||
                r.appName.localizedCaseInsensitiveContains(historySearchQuery)
            }

            let totalRecords = filtered.count
            let totalPages = max(1, Int(ceil(Double(totalRecords) / Double(historyPageSize))))
            let currentPage = min(max(1, historyPage), totalPages)
            let startIndex = (currentPage - 1) * historyPageSize
            let endIndex = min(startIndex + historyPageSize, totalRecords)
            let pagedRecords = totalRecords > 0 ? Array(filtered[startIndex..<endIndex]) : []

            if filtered.isEmpty {
                websiteCard(title: "Transcription History", icon: "clock.arrow.circlepath") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 24))
                                .foregroundColor(textMuted)
                            Text(historySearchQuery.isEmpty ? "No dictation history yet" : "No results matching '\(historySearchQuery)'")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("Audio transcribed via MinaFlow will be stored locally here.")
                                .font(.system(size: 11.5))
                                .foregroundColor(textMuted)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                }
            } else {
                ForEach(pagedRecords) { record in
                    historyRecordCard(record: record)
                }

                // Pagination Toolbar
                if totalPages > 1 {
                    HStack {
                        Text("Showing \(startIndex + 1)–\(endIndex) of \(totalRecords) dictations")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textMuted)

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                if historyPage > 1 {
                                    historyPage -= 1
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Previous")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(inputBg)
                                .foregroundColor(historyPage > 1 ? textPrimary : textMuted.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(historyPage <= 1)

                            Text("Page \(currentPage) of \(totalPages)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(brandOrange.opacity(0.12))
                                .foregroundColor(brandOrange)
                                .cornerRadius(6)

                            Button(action: {
                                if historyPage < totalPages {
                                    historyPage += 1
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.system(size: 11, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(inputBg)
                                .foregroundColor(historyPage < totalPages ? textPrimary : textMuted.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(historyPage >= totalPages)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onChange(of: historySearchQuery) { _ in
            historyPage = 1
        }
    }

    private func historyRecordCard(record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    if !record.appName.isEmpty {
                        Text(record.appName)
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(brandOrange.opacity(0.12))
                            .foregroundColor(brandOrange)
                            .cornerRadius(4)
                    }
                    Text(record.model)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(textMuted)
                    if record.wasPolished {
                        Text("AI Polished")
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(brandOrange.opacity(0.12))
                            .foregroundColor(brandOrange)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                Text(record.timestamp, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(textMuted)
                Text(record.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(textMuted)
                Text("• \(record.wordCount) words")
                    .font(.system(size: 10))
                    .foregroundColor(textMuted)
            }

            Text(record.text)
                .font(.system(size: 12.5))
                .foregroundColor(textPrimary)
                .textSelection(.enabled)
                .lineSpacing(2)

            HStack {
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.text, forType: .string)
                    copiedRecordId = record.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedRecordId == record.id { copiedRecordId = nil }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedRecordId == record.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copiedRecordId == record.id ? "Copied" : "Copy")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(copiedRecordId == record.id ? Color.green.opacity(0.12) : inputBg)
                    .foregroundColor(copiedRecordId == record.id ? .green : textPrimary)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(copiedRecordId == record.id ? Color.green.opacity(0.3) : cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    historyManager.deleteRecord(id: record.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .padding(6)
                        .background(inputBg)
                        .foregroundColor(textMuted)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(cardBg)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: - Tab 2: Speech-to-Text Models
    private var modelsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sub-Navigation Island
            HStack(spacing: 4) {
                subTabButton(title: "Local Whisper", isSelected: sttSectionTab == 0) {
                    sttSectionTab = 0
                    sttProvider = .localWhisper
                    ConfigManager.shared.updateSTTProvider(.localWhisper)
                }
                subTabButton(title: "Cloud Speech", isSelected: sttSectionTab == 1) {
                    sttSectionTab = 1
                    if sttProvider == .localWhisper || sttProvider == .custom {
                        sttProvider = .groq
                        ConfigManager.shared.updateSTTProvider(.groq)
                    }
                }
                subTabButton(title: "Local Server", isSelected: sttSectionTab == 2) {
                    sttSectionTab = 2
                    sttProvider = .custom
                    ConfigManager.shared.updateSTTProvider(.custom)
                }
            }
            .padding(3)
            .background(navContainerBg)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))

            if sttSectionTab == 0 {
                // Local Whisper Engine
                websiteCard(title: "Local Whisper Transcription", icon: "cpu") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("100% Offline On-Device Dictation")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(textPrimary)
                                Text("Audio is processed natively on your Mac with Apple Silicon Metal acceleration. Zero internet required.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(textMuted)
                            }
                            Spacer()
                            if sttProvider == .localWhisper {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                    Text("ACTIVE ENGINE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                            } else {
                                Button(action: {
                                    sttProvider = .localWhisper
                                    ConfigManager.shared.updateSTTProvider(.localWhisper)
                                }) {
                                    Text("Switch to Local Engine")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(brandOrange)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Primary Speech Models (General)
                websiteCard(title: "Primary Speech Models (General)", icon: "waveform") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Active model for English, Spanish, French, German, Japanese, and standard multilingual speech:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        VStack(spacing: 12) {
                            ForEach(LocalWhisperEngine.generalModels) { model in
                                modelRow(model: model)
                                if model.id != LocalWhisperEngine.generalModels.last?.id {
                                    Divider().background(cardBorder.opacity(0.7))
                                }
                            }
                        }
                    }
                }

                // Dedicated Hinglish Speech Model
                websiteCard(title: "Dedicated Hinglish Speech Model (Hindi + English)", icon: "character.bubble") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                                Text("Independent Model for Hinglish Dictation")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textPrimary)
                            }
                            Text("Acoustic model fine-tuned on code-switched Indian speech to transcribe Hindi & English directly into Roman Latin script. Automatically used whenever your language is set to Hinglish, leaving your primary model intact for all other languages.")
                                .font(.system(size: 11.5))
                                .foregroundColor(textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(brandOrange.opacity(0.06))
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(brandOrange.opacity(0.2), lineWidth: 1))

                        VStack(spacing: 12) {
                            ForEach(LocalWhisperEngine.hinglishModels) { model in
                                modelRow(model: model)
                                if model.id != LocalWhisperEngine.hinglishModels.last?.id {
                                    Divider().background(cardBorder.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .id("hinglishModelsCard")
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(brandOrange, lineWidth: highlightHinglishCard ? 3 : 0)
                        .animation(.easeInOut(duration: 0.3), value: highlightHinglishCard)
                )

                // Model directory info
                websiteCard(title: "Model Storage Location", icon: "folder") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("~/Library/Application Support/MinaFlow/models/")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(textPrimary)
                            Text("Models are downloaded directly to your local Application Support folder.")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }
                        Spacer()
                        Button(action: {
                            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            let modelsDir = appSupport.appendingPathComponent("MinaFlow/models", isDirectory: true)
                            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(modelsDir)
                        }) {
                            Text("Reveal in Finder")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(inputBg)
                                .foregroundColor(textPrimary)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if sttSectionTab == 1 {
                // Cloud STT
                websiteCard(title: "Cloud Speech-to-Text Providers", icon: "cloud.fill") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Select a cloud transcription provider for instant sub-200ms processing:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        HStack(spacing: 8) {
                            ForEach(STTProvider.allCases.filter { $0 != .localWhisper && $0 != .custom }, id: \.self) { p in
                                sttChip(p: p)
                            }
                        }

                        Divider().background(cardBorder.opacity(0.7))

                        let activeCloud: STTProvider = (sttProvider == .deepgram || sttProvider == .openai || sttProvider == .cohere || sttProvider == .soniox) ? sttProvider : .groq

                        if activeCloud == .groq {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Groq Cloud Whisper:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                Text("Uses Groq's LPU hardware with whisper-large-v3-turbo for instantaneous dictation.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(textMuted)

                                HStack {
                                    websiteTextField(placeholder: "gsk_...", text: $groqApiKey, isSecure: true)
                                    websiteButton(title: isCheckingGroq ? "Testing..." : "Save Key") {
                                        testAndSaveGroqKey()
                                    }
                                }

                                apiKeyValidationBadge(status: groqValidationStatus, isValid: groqIsValid, isChecking: isCheckingGroq)

                                Link("Get your free Groq API key at console.groq.com ->", destination: URL(string: "https://console.groq.com/keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if activeCloud == .deepgram {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Deepgram Nova-3 API Key:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "Token ...", text: $deepgramApiKey, isSecure: true)
                                    websiteButton(title: isCheckingDeepgram ? "Testing..." : "Save Key") {
                                        testAndSaveDeepgramKey()
                                    }
                                }

                                apiKeyValidationBadge(status: deepgramValidationStatus, isValid: deepgramIsValid, isChecking: isCheckingDeepgram)

                                Text("Deepgram Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack(spacing: 8) {
                                    deepgramModelChip(id: "nova-3", name: "Nova-3")
                                    deepgramModelChip(id: "nova-2", name: "Nova-2")
                                }

                                Link("Get $200 free credit at deepgram.com/pricing ->", destination: URL(string: "https://deepgram.com/pricing")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if activeCloud == .openai {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OpenAI Whisper-1 API Key:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "sk-...", text: $openaiApiKey, isSecure: true)
                                    websiteButton(title: "Save Key") {
                                        ConfigManager.shared.updateOpenaiApiKey(openaiApiKey)
                                        apiKeySaved = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { apiKeySaved = false }
                                    }
                                }

                                Link("Get your OpenAI API key at platform.openai.com ->", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if activeCloud == .cohere {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Cohere Transcribe API Key:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "Cohere API key...", text: $cohereApiKey, isSecure: true)
                                    websiteButton(title: isCheckingCohere ? "Testing..." : "Save Key") {
                                        testAndSaveCohereKey()
                                    }
                                }

                                apiKeyValidationBadge(status: cohereValidationStatus, isValid: cohereIsValid, isChecking: isCheckingCohere)

                                Link("Get your Cohere API key at dashboard.cohere.com ->", destination: URL(string: "https://dashboard.cohere.com/api-keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if activeCloud == .soniox {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Soniox STT:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                Text("High-accuracy cloud transcription via Soniox APIs.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(textMuted)

                                HStack {
                                    websiteTextField(placeholder: "Soniox API key...", text: $sonioxApiKey, isSecure: true)
                                    websiteButton(title: isCheckingSoniox ? "Testing..." : "Save Key") {
                                        testAndSaveSonioxKey()
                                    }
                                }

                                apiKeyValidationBadge(status: sonioxValidationStatus, isValid: sonioxIsValid, isChecking: isCheckingSoniox)

                                Link("Get your Soniox API key at soniox.com ->", destination: URL(string: "https://soniox.com")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        }
                    }
                }
            } else {
                // Localhost STT
                websiteCard(title: "Local Server Endpoint", icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect an OpenAI-compatible /v1/audio/transcriptions endpoint (e.g. local whisper.cpp server):")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        Text("Endpoint Base URL:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textPrimary)
                        websiteTextField(placeholder: "http://localhost:8080/v1", text: $customApiUrl)

                        Text("Model Identifier:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textPrimary)
                        websiteTextField(placeholder: "whisper-1", text: $customModel)

                        Text("Authorization Token (Optional):")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textPrimary)
                        websiteTextField(placeholder: "Bearer Token ...", text: $customApiKey, isSecure: true)

                        HStack {
                            Spacer()
                            websiteButton(title: "Activate Localhost STT") {
                                ConfigManager.shared.updateCustomApiUrl(customApiUrl)
                                ConfigManager.shared.updateCustomModel(customModel)
                                ConfigManager.shared.updateCustomApiKey(customApiKey)
                                sttProvider = .custom
                                ConfigManager.shared.updateSTTProvider(.custom)
                                apiKeySaved = true
                            }
                        }
                    }
                }
            }
        }
    }

    private func subTabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? cardBg : Color.clear)
                .foregroundColor(isSelected ? brandOrange : textMuted)
                .cornerRadius(7)
                .shadow(color: isSelected ? Color.black.opacity(isDarkMode ? 0.3 : 0.05) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func modelRow(model: WhisperModelOption) -> some View {
        let isHinglish = LocalWhisperEngine.shared.isHinglishModel(model.id)
        let isDownloaded = whisperEngine.isModelDownloaded(model.id)
        let isDownloading = whisperEngine.isDownloading[model.id] ?? false
        let progress = whisperEngine.downloadProgress[model.id] ?? 0.0
        let isSelected = isHinglish ? (hinglishModel == model.id) : ((localWhisperModel == model.id) && (sttProvider == .localWhisper))

        return HStack(alignment: .center, spacing: 14) {
            // Left Content: Title, metadata chips, description
            VStack(alignment: .leading, spacing: 5) {
                // Row 1: Model Title + Clean badges (no purple, no teal, no rainbow badge soup)
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(textPrimary)

                    if model.isRecommended {
                        Text("RECOMMENDED")
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(brandOrange.opacity(0.12))
                            .foregroundColor(brandOrange)
                            .cornerRadius(4)
                    }

                    if LocalWhisperEngine.shared.isHinglishModel(model.id) {
                        Text("Hinglish (Latin)")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(brandOrange.opacity(0.15))
                            .foregroundColor(brandOrange)
                            .cornerRadius(4)
                    } else {
                        Text(model.isEnglishOnly ? "English Only" : "99+ Languages")
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(cardBorder.opacity(0.45))
                            .foregroundColor(textMuted)
                            .cornerRadius(4)
                    }
                }

                // Row 2: Performance Specs (Clean, calm, unified typography)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Text("Speed")
                            .foregroundColor(textMuted)
                        Text("\(model.speedScore)/10")
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)
                    }
                    Text("•")
                        .foregroundColor(textMuted.opacity(0.3))
                    HStack(spacing: 3) {
                        Text("Accuracy")
                            .foregroundColor(textMuted)
                        Text("\(model.accuracyScore)/10")
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)
                    }
                    Text("•")
                        .foregroundColor(textMuted.opacity(0.3))
                    HStack(spacing: 3) {
                        Text("Size")
                            .foregroundColor(textMuted)
                        Text(model.sizeDescription)
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)
                    }
                }
                .font(.system(size: 11))

                // Row 3: Description
                Text(model.description)
                    .font(.system(size: 11))
                    .foregroundColor(textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Right Actions
            if isDownloading {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(isDarkMode ? Color(white: 0.2) : Color(white: 0.88))
                                .frame(width: 72, height: 5)
                            Capsule()
                                .fill(brandOrange)
                                .frame(width: max(4, 72 * CGFloat(progress)), height: 5)
                        }

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(brandOrange)

                        Button(action: {
                            whisperEngine.cancelDownload(id: model.id)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Downloading...")
                        .font(.system(size: 9.5))
                        .foregroundColor(textMuted)
                }
            } else if isDownloaded {
                HStack(spacing: 6) {
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(isHinglish ? "Active for Hinglish" : "Active")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(brandOrange.opacity(0.12))
                        .foregroundColor(brandOrange)
                        .cornerRadius(6)
                    } else {
                        Button(action: {
                            selectModel(model)
                        }) {
                            Text(isHinglish ? "Use for Hinglish" : "Use Model")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(brandOrange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Repair Button (Icon button with subtle tooltip)
                    Button(action: {
                        whisperEngine.repairModel(id: model.id)
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(textMuted)
                            .padding(6)
                            .background(inputBg)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Re-download model fresh if corrupt or encountered errors")

                    // Remove Button
                    Button(action: {
                        whisperEngine.deleteModel(id: model.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(textMuted)
                            .padding(6)
                            .background(inputBg)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Delete model file to free up disk space")
                }
            } else {
                Button(action: {
                    whisperEngine.downloadModel(id: model.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10.5))
                        Text("Download")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(brandOrange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(isSelected ? brandOrange.opacity(isDarkMode ? 0.07 : 0.035) : inputBg.opacity(0.45))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? brandOrange.opacity(0.45) : cardBorder.opacity(0.6), lineWidth: isSelected ? 1.2 : 1)
        )
    }

    private func selectModel(_ model: WhisperModelOption) {
        if LocalWhisperEngine.shared.isHinglishModel(model.id) {
            hinglishModel = model.id
            ConfigManager.shared.updateHinglishModel(model.id)
        } else {
            localWhisperModel = model.id
            ConfigManager.shared.updateLocalWhisperModel(model.id)
            sttProvider = .localWhisper
            ConfigManager.shared.updateSTTProvider(.localWhisper)

            if model.isEnglishOnly {
                selectedLanguages = ["English"]
                ConfigManager.shared.updateSpokenLanguage("English")
            }
        }
    }

    // MARK: - Tab 3: AI Polish & LLMs (Pro Gated)
    private var aiPolishTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            websiteCard(title: "AI Polish & Verbal De-clutter", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Enable AI Polish")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                if !isLicenseActivated {
                                    Text("PRO ONLY")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(brandOrange.opacity(0.15))
                                        .foregroundColor(brandOrange)
                                        .cornerRadius(4)
                                }
                            }
                            Text("Removes verbal filler words ('um', 'uh', stuttering), formats punctuation and grammar, and adapts tone.")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }
                        Spacer()
                        Button(action: {
                            if !isLicenseActivated {
                                selectedTab = 6
                                return
                            }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isAIPolishEnabled.toggle()
                                ConfigManager.shared.updateAIPolishEnabled(isAIPolishEnabled)
                            }
                        }) {
                            ZStack(alignment: isAIPolishEnabled ? .trailing : .leading) {
                                Capsule()
                                    .fill(isAIPolishEnabled ? brandOrange : (isDarkMode ? Color(red: 45/255, green: 45/255, blue: 50/255) : Color(red: 220/255, green: 220/255, blue: 225/255)))
                                    .frame(width: 38, height: 22)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                                    .padding(2)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(isLicenseActivated ? 1.0 : 0.6)
                    }

                    if !isLicenseActivated {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(brandOrange)
                            Text("Free tier provides unlimited raw dictation. Upgrade to Lifetime Pro ($1.99 promo / $5) to unlock AI Polish and custom LLMs.")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                            Spacer()
                            Button(action: { openCheckoutPage() }) {
                                Text("Upgrade ($1.99)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(brandOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(brandOrange.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }

            if isLicenseActivated {
                // Multi-Provider Language Model Engine
                websiteCard(title: "Language Model Engine", icon: "cpu") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select your preferred AI engine:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        HStack(spacing: 6) {
                            ForEach(AIProvider.userProviders, id: \.self) { p in
                                providerChip(p: p)
                            }
                        }

                        Divider().background(cardBorder.opacity(0.7))

                        if provider == .groq {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Groq API Key:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "gsk_...", text: $groqApiKey, isSecure: true)
                                    websiteButton(title: isCheckingGroq ? "Testing..." : "Save & Test Key") {
                                        testAndSaveGroqKey()
                                    }
                                }

                                apiKeyValidationBadge(status: groqValidationStatus, isValid: groqIsValid, isChecking: isCheckingGroq)

                                Text("Language Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    ForEach(AIProvider.groq.availableModels) { m in
                                        modelChip(m: m)
                                    }
                                }

                                Link("Get your free API key at console.groq.com/keys ->", destination: URL(string: "https://console.groq.com/keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if provider == .openai {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OpenAI API Key:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "sk-...", text: $openaiApiKey, isSecure: true)
                                    websiteButton(title: isCheckingOpenAI ? "Testing..." : "Save & Test Key") {
                                        testAndSaveOpenAIKey()
                                    }
                                }

                                apiKeyValidationBadge(status: openaiValidationStatus, isValid: openaiIsValid, isChecking: isCheckingOpenAI)

                                Text("Language Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    ForEach(AIProvider.openai.availableModels) { m in
                                        modelChip(m: m)
                                    }
                                }

                                Link("Get your OpenAI API key at platform.openai.com/api-keys ->", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if provider == .anthropic {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Anthropic API Key:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "sk-ant-...", text: $anthropicApiKey, isSecure: true)
                                    websiteButton(title: isCheckingAnthropic ? "Testing..." : "Save & Test Key") {
                                        testAndSaveAnthropicKey()
                                    }
                                }

                                apiKeyValidationBadge(status: anthropicValidationStatus, isValid: anthropicIsValid, isChecking: isCheckingAnthropic)

                                Text("Language Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    ForEach(AIProvider.anthropic.availableModels) { m in
                                        modelChip(m: m)
                                    }
                                }

                                Link("Get your Anthropic API key at console.anthropic.com/settings/keys ->", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if provider == .openrouter {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OpenRouter API Key:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "sk-or-...", text: $openrouterApiKey, isSecure: true)
                                    websiteButton(title: isCheckingOpenRouter ? "Testing..." : "Save & Test Key") {
                                        testAndSaveOpenRouterKey()
                                    }
                                }

                                apiKeyValidationBadge(status: openrouterValidationStatus, isValid: openrouterIsValid, isChecking: isCheckingOpenRouter)

                                Text("Language Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    ForEach(AIProvider.openrouter.availableModels) { m in
                                        modelChip(m: m)
                                    }
                                }

                                Link("Get your OpenRouter API key at openrouter.ai/keys ->", destination: URL(string: "https://openrouter.ai/keys")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if provider == .gemini {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Google Gemini API Key:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                HStack {
                                    websiteTextField(placeholder: "AIzaSy...", text: $geminiApiKey, isSecure: true)
                                    websiteButton(title: isCheckingGemini ? "Testing..." : "Save & Test Key") {
                                        testAndSaveGeminiKey()
                                    }
                                }

                                apiKeyValidationBadge(status: geminiValidationStatus, isValid: geminiIsValid, isChecking: isCheckingGemini)

                                Text("Language Model:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    ForEach(AIProvider.gemini.availableModels) { m in
                                        modelChip(m: m)
                                    }
                                }

                                Link("Get your free Gemini API key at aistudio.google.com/apikey ->", destination: URL(string: "https://aistudio.google.com/apikey")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)
                            }
                        } else if provider == .custom {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "server.rack")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(brandOrange)
                                        Text("OpenAI-Compatible Custom Endpoint")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(textPrimary)
                                    }
                                    Text("Connect Ollama, vLLM, LMStudio, LocalAI, or custom OpenAI-compatible server.")
                                        .font(.system(size: 11))
                                        .foregroundColor(textMuted)
                                }

                                VStack(alignment: .leading, spacing: 9) {
                                    HStack(alignment: .center) {
                                        Text("API Base URL:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textMuted)
                                            .frame(width: 95, alignment: .leading)
                                        Text(customApiUrl.isEmpty ? "http://localhost:11434/v1" : customApiUrl)
                                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                            .foregroundColor(textPrimary)
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                    Divider().background(cardBorder.opacity(0.4))
                                    HStack(alignment: .center) {
                                        Text("Model ID:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textMuted)
                                            .frame(width: 95, alignment: .leading)
                                        Text(customModel.isEmpty ? "llama3.1" : customModel)
                                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                            .foregroundColor(brandOrange)
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                    Divider().background(cardBorder.opacity(0.4))
                                    HStack(alignment: .center) {
                                        Text("API Key:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textMuted)
                                            .frame(width: 95, alignment: .leading)
                                        Text(customApiKey.isEmpty ? "None (Authentication Optional)" : "••••••••••••")
                                            .font(.system(size: 11))
                                            .foregroundColor(textMuted)
                                        Spacer()
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(inputBg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                                HStack(spacing: 10) {
                                    Button(action: {
                                        showOpenAIModal = true
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("Configure Endpoint")
                                                .font(.system(size: 11.5, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(brandOrange)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        testAndSaveCustomConfig()
                                    }) {
                                        HStack(spacing: 5) {
                                            if isCheckingCustom {
                                                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                                                Text("Testing...")
                                            } else {
                                                Image(systemName: "waveform")
                                                    .font(.system(size: 11, weight: .semibold))
                                                Text("Test Connection")
                                            }
                                        }
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(inputBg)
                                        .foregroundColor(textPrimary)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isCheckingCustom)

                                    apiKeyValidationBadge(status: customValidationStatus, isValid: customIsValid, isChecking: isCheckingCustom)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider().background(cardBorder.opacity(0.7))

                        websitePillToggle(
                            title: "Auto-Failover on Rate Limits",
                            subtitle: "Automatically switch to an alternative free model if the active provider hits its rate limit",
                            isOn: $autoFailover
                        ) {
                            ConfigManager.shared.updateAutoFailover(autoFailover)
                        }
                    }
                }

                // Writing Tone & Adaptation
                websiteCard(title: "Writing Tone & Style Adaptation", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Select how MinaFlow shapes your spoken thoughts into polished text:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        if !ConfigManager.shared.config.hasConfiguredAIProvider {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 13))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LLM API Key Required for Writing Tones")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(textPrimary)
                                    Text("Whisper models only transcribe literal speech. Add an AI API Key (Groq, OpenAI, Gemini, etc.) above to enable writing tones.")
                                        .font(.system(size: 10))
                                        .foregroundColor(textMuted)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        } else if !isAIPolishEnabled {
                            HStack(spacing: 10) {
                                Image(systemName: "power")
                                    .foregroundColor(brandOrange)
                                    .font(.system(size: 14, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI Polish is Turned Off")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(textPrimary)
                                    Text("You have configured an AI Key (\(ConfigManager.shared.config.configuredAIProviderName)), but AI Polish is currently OFF. Turn it ON to enable Auto, Formal, and Casual tones.")
                                        .font(.system(size: 10))
                                        .foregroundColor(textMuted)
                                }
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        isAIPolishEnabled = true
                                        ConfigManager.shared.updateAIPolishEnabled(true)
                                    }
                                    FloatingHUDWindow.shared.setMode(.listening)
                                    FloatingHUDWindow.shared.hide(after: 2.0)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "power")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Turn ON AI Polish")
                                            .font(.system(size: 10.5, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(brandOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(brandOrange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(brandOrange.opacity(0.3), lineWidth: 1))
                        }

                        VStack(spacing: 8) {
                            toneOptionCard(
                                title: "Direct Speech (Raw Whisper)",
                                description: "Outputs literal transcribed speech with zero cloud/LLM alterations (100% Free & Fast)",
                                icon: "waveform",
                                isSelected: toneMode == "veryCasual",
                                isProOnly: false
                            ) {
                                toneMode = "veryCasual"
                                ConfigManager.shared.updateToneMode("veryCasual")
                            }

                            toneOptionCard(
                                title: "Auto Context (Smart App Detection)",
                                description: "Automatically adapts tone to the active app (Slack, WhatsApp, Mail, Terminal, Docs)",
                                icon: "brain.head.profile",
                                isSelected: toneMode == "auto" && isLicenseActivated,
                                isProOnly: true
                            ) {
                                if !ConfigManager.shared.config.hasConfiguredAIProvider {
                                    FloatingHUDWindow.shared.setMode(.error(message: "Add an AI Key above to enable Auto tone"))
                                    FloatingHUDWindow.shared.hide(after: 3.0)
                                } else if !isAIPolishEnabled {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        isAIPolishEnabled = true
                                        ConfigManager.shared.updateAIPolishEnabled(true)
                                    }
                                }
                                toneMode = "auto"
                                ConfigManager.shared.updateToneMode("auto")
                            }

                            toneOptionCard(
                                title: "Professional & Formal",
                                description: "Perfect for executive emails, client proposals, documents, and formal reports",
                                icon: "doc.text.fill",
                                isSelected: toneMode == "formal" && isLicenseActivated,
                                isProOnly: true
                            ) {
                                if !ConfigManager.shared.config.hasConfiguredAIProvider {
                                    FloatingHUDWindow.shared.setMode(.error(message: "Add an AI Key above to enable Formal tone"))
                                    FloatingHUDWindow.shared.hide(after: 3.0)
                                } else if !isAIPolishEnabled {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        isAIPolishEnabled = true
                                        ConfigManager.shared.updateAIPolishEnabled(true)
                                    }
                                }
                                toneMode = "formal"
                                ConfigManager.shared.updateToneMode("formal")
                            }

                            toneOptionCard(
                                title: "Conversational & Natural",
                                description: "Relaxed, natural, and friendly for internal Slack discussions and team chats",
                                icon: "bubble.left.and.bubble.right.fill",
                                isSelected: toneMode == "casual" && isLicenseActivated,
                                isProOnly: true
                            ) {
                                if !ConfigManager.shared.config.hasConfiguredAIProvider {
                                    FloatingHUDWindow.shared.setMode(.error(message: "Add an AI Key above to enable Casual tone"))
                                    FloatingHUDWindow.shared.hide(after: 3.0)
                                } else if !isAIPolishEnabled {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        isAIPolishEnabled = true
                                        ConfigManager.shared.updateAIPolishEnabled(true)
                                    }
                                }
                                toneMode = "casual"
                                ConfigManager.shared.updateToneMode("casual")
                            }
                        }
                    }
                }
            } else {
                // Locked Pro Banner
                websiteCard(title: "Custom LLM & Writing Tone Configuration", icon: "lock.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Language Model polishing, verbal de-cluttering, and custom OpenAI/Ollama endpoints are Pro features.")
                            .font(.system(size: 12))
                            .foregroundColor(textMuted)

                        HStack {
                            Spacer()
                            Button(action: { openCheckoutPage() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                    Text("Unlock Lifetime Pro ($1.99)")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(brandOrange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: Shortcuts & Productivity
    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card 1: Global Trigger Key & Mode
            websiteCard(title: "Global Trigger Key & Dictation Mode", icon: "command") {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your preferred global shortcut to start & stop voice dictation:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            compactOptionButton(
                                title: "Option + Space",
                                icon: "keyboard",
                                badge: "⌥ Space",
                                isSelected: hotkey == "option+space"
                            ) {
                                hotkey = "option+space"
                                ConfigManager.shared.updateHotkey("option+space")
                            }

                            compactOptionButton(
                                title: "Right Option",
                                icon: "option",
                                badge: "Right ⌥",
                                isSelected: hotkey == "rightOption"
                            ) {
                                hotkey = "rightOption"
                                ConfigManager.shared.updateHotkey("rightOption")
                            }

                            compactOptionButton(
                                title: "Fn (Globe)",
                                icon: "globe",
                                badge: "🌐 Fn",
                                isSelected: hotkey == "fn"
                            ) {
                                hotkey = "fn"
                                ConfigManager.shared.updateHotkey("fn")
                            }

                            compactOptionButton(
                                title: "Right Command",
                                icon: "command",
                                badge: "Right ⌘",
                                isSelected: hotkey == "rightCommand"
                            ) {
                                hotkey = "rightCommand"
                                ConfigManager.shared.updateHotkey("rightCommand")
                            }
                        }
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dictation Trigger Mode")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)

                        HStack(spacing: 10) {
                            compactOptionButton(
                                title: "Press to Start / Stop",
                                icon: "record.circle",
                                badge: "Press once to talk, press again to finish",
                                isSelected: mode == "toggle"
                            ) {
                                mode = "toggle"
                                ConfigManager.shared.updateMode("toggle")
                            }

                            compactOptionButton(
                                title: "Hold to Speak",
                                icon: "hand.tap",
                                badge: "Hold key while speaking, release to finish",
                                isSelected: mode == "pushToTalk"
                            ) {
                                mode = "pushToTalk"
                                ConfigManager.shared.updateMode("pushToTalk")
                            }
                        }
                    }
                }
            }

            // Card 2: Highlight-to-Edit (Pro Feature)
            websiteCard(title: "Highlight-to-Edit", icon: "pencil.and.outline") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Highlight-to-Edit Mode")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                if !isLicenseActivated {
                                    Text("PRO ONLY")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(brandOrange.opacity(0.15))
                                        .foregroundColor(brandOrange)
                                        .cornerRadius(4)
                                } else {
                                    Text("ACTIVE")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                            Text("Select text in any macOS app, press your shortcut, and speak commands like 'Make this formal' to rewrite in-place.")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }

                        Spacer()
                        Button(action: {
                            if !isLicenseActivated {
                                selectedTab = 6
                                return
                            }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isEditModeEnabled.toggle()
                                ConfigManager.shared.updateEditModeEnabled(isEditModeEnabled)
                            }
                        }) {
                            ZStack(alignment: isEditModeEnabled ? .trailing : .leading) {
                                Capsule()
                                    .fill(isEditModeEnabled ? brandOrange : (isDarkMode ? Color(red: 45/255, green: 45/255, blue: 50/255) : Color(red: 220/255, green: 220/255, blue: 225/255)))
                                    .frame(width: 38, height: 22)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                                    .padding(2)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(isLicenseActivated ? 1.0 : 0.6)
                    }

                    if !isLicenseActivated {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(brandOrange)
                            Text("Highlight-to-Edit is a Lifetime Pro feature ($1.99 promo). Highlight text and command AI to fix, polish, or rewrite it instantly.")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                            Spacer()
                            Button(action: { openCheckoutPage() }) {
                                Text("Unlock ($1.99)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .background(brandOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(brandOrange.opacity(0.08))
                        .cornerRadius(8)
                    } else {
                        if !ConfigManager.shared.config.hasConfiguredAIProvider {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text("Requires an AI model to rewrite text. Add an API key or enable Local Ollama in the AI Polish tab.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(textMuted)
                                Spacer()
                                Button(action: { selectedTab = 3 }) {
                                    Text("Configure AI →")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(brandOrange)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(6)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "cpu")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                                Text("AI Engine Ready: \(ConfigManager.shared.config.configuredAIProviderName)")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(textMuted)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example voice commands:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textMuted)

                        HStack(spacing: 6) {
                            ForEach(["'Make this formal'", "'Fix grammar & typos'", "'Condense into bullets'", "'Translate to Spanish'"], id: \.self) { ex in
                                Text(ex)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(inputBg)
                                    .foregroundColor(textPrimary)
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(cardBorder, lineWidth: 1))
                            }
                        }
                    }
                }
            }

            // Card 3: Voice Macros & Snippets for Links
            websiteCard(title: "Voice Macros & Spoken Shortcuts", icon: "link") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Speak a short phrase during dictation to instantly expand into URLs, email addresses, or canned text:")
                        .font(.system(size: 11.5))
                        .foregroundColor(textMuted)

                    // Quick Presets
                    HStack(spacing: 6) {
                        Text("Quick Presets:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textMuted)

                        Button(action: {
                            addSnippetPreset(trigger: "my meeting link", expansion: "https://meet.google.com/new")
                        }) {
                            Text("+ Google Meet")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(brandOrange.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            addSnippetPreset(trigger: "my linkedin", expansion: "https://linkedin.com/in/me")
                        }) {
                            Text("+ LinkedIn")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(brandOrange.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            addSnippetPreset(trigger: "my email", expansion: "me@example.com")
                        }) {
                            Text("+ Email")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(brandOrange.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            addSnippetPreset(trigger: "my zoom", expansion: "https://zoom.us/my/meeting")
                        }) {
                            Text("+ Zoom")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(brandOrange.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        websiteTextField(placeholder: "Spoken trigger (e.g. 'my meeting link')", text: $newTrigger)
                        websiteTextField(placeholder: "Expansion text or URL (e.g. 'https://meet.google.com/xyz')", text: $newExpansion)
                        websiteButton(title: "Add Macro", icon: "plus") {
                            addSnippet()
                        }
                        .disabled(newTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newExpansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    if snippets.isEmpty {
                        Text("No voice macros added yet. Add links or shortcuts above to expand them by voice.")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(snippets.keys.sorted()), id: \.self) { trigger in
                                HStack {
                                    Text(trigger)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(brandOrange)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(textMuted)
                                    Text(snippets[trigger] ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        removeSnippet(trigger: trigger)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(textMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(inputBg)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }

            // Card 4: Custom Vocabulary & Acronyms
            websiteCard(title: "Custom Vocabulary & Technical Acronyms", icon: "character.book.closed") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text("Teach Whisper and AI Polish uncommon names, proprietary jargon, or technical acronyms:")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)

                        Spacer()

                        // Live Budget Counter Badge
                        HStack(spacing: 4) {
                            Text("\(customVocabulary.count)/50")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(customVocabulary.count >= 50 ? brandOrange : (customVocabulary.isEmpty ? textMuted : textPrimary))
                            Text("terms")
                                .font(.system(size: 10.5))
                                .foregroundColor(textMuted)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(inputBg)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(customVocabulary.count >= 50 ? brandOrange.opacity(0.5) : cardBorder, lineWidth: 1))

                        if !customVocabulary.isEmpty {
                            Button(action: {
                                clearAllCustomVocab()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                    Text("Clear All")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.red.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Quick Presets
                    HStack(spacing: 6) {
                        Text("Quick Presets:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textMuted)

                        ForEach(["SaaS", "ARR", "CAC", "GPU", "LLM", "MinaFlow"], id: \.self) { preset in
                            Button(action: {
                                addCustomVocab(word: preset)
                            }) {
                                Text("+ \(preset)")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(customVocabulary.count >= 50 ? textMuted : brandOrange)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(brandOrange.opacity(customVocabulary.count >= 50 ? 0.04 : 0.1))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .disabled(customVocabulary.count >= 50)
                        }
                    }

                    HStack(spacing: 8) {
                        websiteTextField(placeholder: customVocabulary.count >= 50 ? "Vocabulary limit reached (50/50 terms)" : "Enter term or acronym (e.g. 'Bunty', 'PyTorch', 'SaaS')", text: $newVocabWord)
                            .disabled(customVocabulary.count >= 50)

                        websiteButton(title: "Add Term", icon: "plus") {
                            addCustomVocab()
                        }
                        .disabled(customVocabulary.count >= 50 || newVocabWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    if customVocabulary.isEmpty {
                        Text("No custom vocabulary or acronyms added yet.")
                            .font(.system(size: 11.5))
                            .foregroundColor(textMuted)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 200), spacing: 6)], spacing: 6) {
                                ForEach(customVocabulary, id: \.self) { word in
                                    HStack(spacing: 6) {
                                        Text(word)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer(minLength: 4)
                                        Button(action: {
                                            removeCustomVocab(word)
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(textMuted)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(inputBg)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 180)
                    }
                }
            }

            // Card 5: Subtitle HUD & Audio Feedback
            websiteCard(title: "Subtitle Overlay & Audio Feedback", icon: "speaker.wave.2") {
                VStack(alignment: .leading, spacing: 14) {
                    websitePillToggle(
                        title: "Sound Effects & Audio Feedback",
                        subtitle: "Play subtle audio chimes when speech recording starts, stops, and pastes",
                        isOn: $playSounds
                    ) {
                        ConfigManager.shared.updateSoundEffects(playSounds)
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HUD Subtitle Overlay Style")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Choose where the dictation subtitle status displays while you speak:")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)

                        HStack(spacing: 10) {
                            modeOptionCard(
                                title: "MacBook Notch",
                                subtitle: "Animates flush beneath your camera notch",
                                icon: "inset.filled.topthird.rectangle",
                                isSelected: hudStyle == "notch"
                            ) {
                                hudStyle = "notch"
                                ConfigManager.shared.updateHudStyle("notch")
                            }

                            modeOptionCard(
                                title: "Floating Pill",
                                subtitle: "Classic ergonomic capsule centered at bottom",
                                icon: "capsule",
                                isSelected: hudStyle == "pill"
                            ) {
                                hudStyle = "pill"
                                ConfigManager.shared.updateHudStyle("pill")
                            }
                        }
                    }
                }
            }
        }
    }

    private var spokenLanguageCard: some View {
        let isEnglishOnly = LocalWhisperEngine.shared.isEnglishOnlyModel(localWhisperModel) && (sttProvider == .localWhisper)
        return websiteCard(title: "Spoken Language", icon: "globe") {
            VStack(alignment: .leading, spacing: 14) {
                if isEnglishOnly {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(brandOrange)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Language Locked to English")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(textPrimary)
                            Text("The active model '\(localWhisperModel)' is an English-only optimized model for maximum speed and accuracy. To use other languages (Hindi, Hinglish, Spanish, etc.), select a Multilingual model in the Models tab.")
                                .font(.system(size: 11.5))
                                .foregroundColor(textMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(brandOrange.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(brandOrange.opacity(0.2), lineWidth: 1))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Active Spoken Language:")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text(selectedLanguages.first ?? "English")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(brandOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(brandOrange.opacity(0.12))
                                .cornerRadius(6)
                        }
                        Text("Whisper runs in single-language mode to skip the detection delay, resulting in 2x faster transcription with zero foreign hallucinations.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    popularLanguagesGrid

                    allLanguagesPicker
                }
            }
        }
    }

    private var popularLanguagesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Popular Languages:")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(textPrimary)

            let quickLanguages = ["English", "Hinglish", "Hindi", "Spanish", "French", "German", "Japanese", "Chinese", "Italian", "Portuguese", "Korean", "Russian"]

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(quickLanguages, id: \.self) { lang in
                    let isSelected = (selectedLanguages.first == lang)
                    Button(action: {
                        if lang.lowercased() == "hinglish" {
                            let isHinglishReady = LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                                                  LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
                            if !isHinglishReady {
                                LocalWhisperEngine.promptForHinglishDownloadIfNeeded()
                                return
                            }
                        }
                        selectedLanguages = [lang]
                        ConfigManager.shared.updateSpokenLanguage(lang)
                    }) {
                        HStack(spacing: 5) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(lang)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        .background(isSelected ? brandOrange : inputBg)
                        .foregroundColor(isSelected ? .white : textPrimary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredAppLanguages: [String] {
        if languageSearchQuery.isEmpty {
            return AppLanguages.all
        }
        return AppLanguages.all.filter { $0.localizedCaseInsensitiveContains(languageSearchQuery) }
    }

    private func languageGridButton(_ l: String) -> some View {
        let isSel = (selectedLanguages.first == l)
        return Button(action: {
            if l.lowercased() == "hinglish" {
                let isHinglishReady = LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                                      LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
                if !isHinglishReady {
                    LocalWhisperEngine.promptForHinglishDownloadIfNeeded()
                    return
                }
            }
            selectedLanguages = [l]
            ConfigManager.shared.updateSpokenLanguage(l)
        }) {
            HStack(spacing: 4) {
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(l)
                    .font(.system(size: 11, weight: isSel ? .bold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(isSel ? brandOrange.opacity(0.15) : inputBg)
            .foregroundColor(isSel ? brandOrange : textPrimary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSel ? brandOrange : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var allLanguagesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation { showLanguagePickerModal.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showLanguagePickerModal ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(showLanguagePickerModal ? "Hide All 99+ Languages" : "Browse All 99+ Supported Languages...")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundColor(brandOrange)
            }
            .buttonStyle(.plain)

            if showLanguagePickerModal {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search 99+ languages...", text: $languageSearchQuery)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                            ForEach(filteredAppLanguages, id: \.self) { l in
                                languageGridButton(l)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }

    // MARK: - Tab 5: Settings (General, Audio & System)
    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            spokenLanguageCard

            // Microphone Audio Device Selector (Custom Dropdown - No native blue arrows)
            websiteCard(title: "Audio Input Microphone", icon: "mic.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active Microphone")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("Choose which microphone MinaFlow listens to for speech recognition")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }
                        Spacer()

                        Menu {
                            ForEach(audioDeviceManager.inputDevices) { dev in
                                Button(action: {
                                    audioDeviceManager.setDefaultInputDevice(id: dev.id)
                                }) {
                                    HStack {
                                        Text(dev.displayLabel)
                                        if dev.id == audioDeviceManager.currentInputDeviceID {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: audioDeviceManager.currentDeviceName.lowercased().contains("bluetooth") || audioDeviceManager.currentDeviceName.lowercased().contains("airpod") || audioDeviceManager.currentDeviceName.lowercased().contains("buds") ? "headphones" : "mic.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(brandOrange)

                                Text(audioDeviceManager.currentDeviceName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(inputBg)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .frame(minWidth: 240, maxWidth: 340)

                        Button(action: {
                            audioDeviceManager.refreshDevices()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                                .padding(7)
                                .background(inputBg)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh audio inputs")
                    }
                }
            }

            // HUD Style
            websiteCard(title: "Recording HUD Style", icon: "macbook.and.iphone") {
                HStack(spacing: 10) {
                    modeOptionCard(
                        title: "MacBook Notch",
                        subtitle: "Animates flush beneath your camera notch",
                        icon: "inset.filled.topthird.rectangle",
                        isSelected: hudStyle == "notch"
                    ) {
                        hudStyle = "notch"
                        ConfigManager.shared.updateHudStyle("notch")
                        FloatingHUDWindow.shared.reposition()
                    }

                    modeOptionCard(
                        title: "Floating Pill",
                        subtitle: "Classic ergonomic capsule centered at bottom",
                        icon: "capsule.portrait",
                        isSelected: hudStyle == "pill"
                    ) {
                        hudStyle = "pill"
                        ConfigManager.shared.updateHudStyle("pill")
                        FloatingHUDWindow.shared.reposition()
                    }
                }
            }

            // System Permissions
            websiteCard(title: "System Permissions", icon: "shield.checkerboard") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Microphone Capture")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("Required for speech recording and transcription")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Granted")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Text Injection")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("Required to type transcribed text directly at your cursor")
                                .font(.system(size: 11))
                                .foregroundColor(textMuted)
                        }
                        Spacer()
                        if PasteInjector.shared.isAccessibilityGranted() {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("Granted")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(6)
                        } else {
                            Button(action: {
                                PasteInjector.shared.openAccessibilitySettings()
                            }) {
                                Text("Grant Permission")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(brandOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // App Startup & Dock Icon
            websiteCard(title: "Startup & App Visibility", icon: "power") {
                VStack(spacing: 12) {
                    websitePillToggle(
                        title: "Launch at Login",
                        subtitle: "Start MinaFlow automatically when you log into your Mac",
                        isOn: $launchAtLogin
                    ) {
                        if #available(macOS 13.0, *) {
                            try? SMAppService.mainApp.register()
                        }
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    websitePillToggle(
                        title: "Show Dock Icon",
                        subtitle: "Keep MinaFlow visible in the macOS Dock alongside menu bar",
                        isOn: $showDockIcon
                    ) {
                        ConfigManager.shared.updateShowDockIcon(showDockIcon)
                        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
                    }
                }
            }

            // Interactive Onboarding & Walkthrough Guide
            websiteCard(title: "Interactive Setup & Onboarding", icon: "book.fill") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replay Onboarding Guide")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Rerun the interactive setup, microphone test, and hotkey walkthrough.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                    }
                    Spacer()
                    Button(action: {
                        OnboardingWindowController.shared.show()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .font(.system(size: 11))
                            Text("Launch Guide")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Software Updates (Sparkle)
            websiteCard(title: "Software Updates & Sparkle", icon: "arrow.triangle.2.circlepath") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
                        Text("MinaFlow v\(appVer)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Checks minaflow.krishra.com/appcast.xml for the latest signed DMG builds.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                    }
                    Spacer()
                    Button(action: {
                        UpdaterService.shared.checkForUpdates()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Check for Updates...")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(brandOrange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tab 6: Account & Pro
    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            websiteCard(title: "MinaFlow License Status", icon: "key.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    if isLicenseActivated {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                        Text("Lifetime Pro Activated")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(textPrimary)
                                    }
                                    Text("All Pro features are fully unlocked permanently.")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(textMuted)
                                }
                                Spacer()
                                Button(action: { deactivateLicense() }) {
                                    HStack(spacing: 5) {
                                        if isDeactivating { ProgressView().scaleEffect(0.6) }
                                        Text(isDeactivating ? "Deactivating..." : "Deactivate License")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(isDeactivating)
                            }

                            Divider().background(cardBorder.opacity(0.7))

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("ACTIVATED LICENSE KEY")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(textMuted)
                                    let activeKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ConfigManager.shared.config.licenseKey : licenseKey
                                    Text(activeKey.isEmpty ? "Active Lifetime License" : activeKey)
                                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(textPrimary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Button(action: {
                                    let activeKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ConfigManager.shared.config.licenseKey : licenseKey
                                    if !activeKey.isEmpty {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(activeKey, forType: .string)
                                        isCopiedLicense = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            isCopiedLicense = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: isCopiedLicense ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 11))
                                        Text(isCopiedLicense ? "Copied" : "Copy Key")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(inputBg)
                                    .foregroundColor(isCopiedLicense ? .green : textPrimary)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(inputBg.opacity(0.4))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder.opacity(0.6), lineWidth: 1))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Free Forever Plan ($0)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(textPrimary)
                                    Text("Unlimited offline local dictation with Whisper (Tiny, Base, Small, Turbo).")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(textMuted)
                                }
                                Spacer()
                                Text("UNLIMITED")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(brandOrange.opacity(0.12))
                                    .foregroundColor(brandOrange)
                                    .cornerRadius(6)
                            }

                            Divider().background(cardBorder.opacity(0.7))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Upgrade to Lifetime Pro ($1.99 promo / $5 regular)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textPrimary)
                                Text("Unlocks AI Polish, custom OpenAI/Ollama LLM formatting, and Highlight-to-Edit.")
                                    .font(.system(size: 11))
                                    .foregroundColor(textMuted)

                                HStack(spacing: 8) {
                                     HStack(spacing: 6) {
                                         Image(systemName: "key.fill")
                                             .font(.system(size: 11))
                                             .foregroundColor(textMuted)
                                         TextField("Enter or paste Pro License Key", text: $licenseKey)
                                             .textFieldStyle(.plain)
                                             .font(.system(size: 12, design: .monospaced))
                                             .foregroundColor(textPrimary)
                                             .onSubmit {
                                                 activateLicense()
                                             }

                                         Button(action: {
                                             if let clipboard = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clipboard.isEmpty {
                                                 licenseKey = clipboard
                                             }
                                         }) {
                                             HStack(spacing: 3) {
                                                 Image(systemName: "doc.on.clipboard")
                                                     .font(.system(size: 10))
                                                 Text("Paste")
                                                     .font(.system(size: 11, weight: .medium))
                                             }
                                             .padding(.horizontal, 6)
                                             .padding(.vertical, 3)
                                             .background(cardBorder.opacity(0.6))
                                             .foregroundColor(textPrimary)
                                             .cornerRadius(5)
                                         }
                                         .buttonStyle(.plain)
                                         .help("Paste key from clipboard")
                                     }
                                     .padding(.horizontal, 10)
                                     .padding(.vertical, 7)
                                     .background(inputBg)
                                     .cornerRadius(8)
                                     .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                                     websiteButton(title: isActivating ? "Activating..." : "Activate Pro", icon: isActivating ? "arrow.triangle.2.circlepath" : "checkmark.seal") {
                                         activateLicense()
                                     }
                                     .disabled(isActivating)

                                     Button(action: { openCheckoutPage() }) {
                                         HStack(spacing: 4) {
                                             Image(systemName: "bag.badge.plus")
                                                 .font(.system(size: 11))
                                             Text("Buy ($1.99)")
                                                 .font(.system(size: 12, weight: .semibold))
                                         }
                                         .padding(.horizontal, 10)
                                         .padding(.vertical, 8)
                                         .background(inputBg)
                                         .foregroundColor(textPrimary)
                                         .cornerRadius(8)
                                         .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                                     }
                                     .buttonStyle(.plain)
                                 }

                                if !licenseMessage.isEmpty {
                                    HStack(spacing: 5) {
                                        Image(systemName: isLicenseActivated ? "checkmark.circle.fill" : "info.circle.fill")
                                            .font(.system(size: 12))
                                        Text(licenseMessage)
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .foregroundColor(isLicenseActivated ? .green : .red)
                                }
                            }
                        }
                    }
                }
            }

            // 100% Free Offer: The 1,000 Views Challenge (from minaflow.krishra.com/creator-bonus)
            websiteCard(title: "100% Free Offer: The 1,000 Views Challenge", icon: "gift.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    // Header Banner Row
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text("Share MinaFlow. Get 100% OFF.")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(textPrimary)

                                Text("100% OFF / FREE")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(brandOrange.opacity(0.12))
                                    .foregroundColor(brandOrange)
                                    .cornerRadius(5)
                            }

                            Text("Post a quick clip or write-up showing your workflow. Reach 1,000+ total views and get 100% OFF with a free lifetime license key (or a 100% full refund if you already bought).")
                                .font(.system(size: 11.5))
                                .foregroundColor(textMuted)
                                .lineSpacing(2)

                            // Social Platform Pills
                            HStack(spacing: 6) {
                                Text("Eligible platforms:")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(textMuted)

                                ForEach(["𝕏 / Twitter", "TikTok", "LinkedIn", "Shorts", "Reddit"], id: \.self) { platform in
                                    Text(platform)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(inputBg)
                                        .foregroundColor(textPrimary)
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                                }
                            }
                            .padding(.top, 2)
                        }
                    }

                    // 3 Step Sequential Milestone Pipeline
                    HStack(alignment: .top, spacing: 10) {
                        // Step 1
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 5) {
                                Text("STEP 1")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(brandOrange)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(textMuted)
                            }
                            Text("Post on Social")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(textPrimary)
                            Text("Record a 15-second clip showing how you dictate with Right ⌘ into any Mac app.")
                                .font(.system(size: 10.5))
                                .foregroundColor(textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(inputBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                        // Step 2
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 5) {
                                Text("STEP 2")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(brandOrange)
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(textMuted)
                            }
                            Text("Hit 1,000 Views")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(textPrimary)
                            Text("Reach 1,000+ views or impressions across your posts (can combine multiple platforms).")
                                .font(.system(size: 10.5))
                                .foregroundColor(textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(inputBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))

                        // Step 3
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 5) {
                                Text("STEP 3")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(brandOrange)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(brandOrange)
                            }
                            Text("Claim 100% OFF")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(textPrimary)
                            Text("Submit your post links & proof right here. We'll send your lifetime key or refund within 24h!")
                                .font(.system(size: 10.5))
                                .foregroundColor(textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(inputBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                    }

                    // Action Buttons
                    HStack(spacing: 10) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showClaimForm.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showClaimForm ? "chevron.up" : "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                Text(showClaimForm ? "Close Claim Form" : "Submit Claim (100% Free)")
                                    .font(.system(size: 11.5, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(brandOrange)
                            .foregroundColor(.white)
                            .cornerRadius(7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            let mailString = "mailto:minaflow@krishra.com?subject=MinaFlow%20100%25%20Creator%20Bonus%20Claim&body=Hi%20Krishna%2C%0A%0AI%20shared%20MinaFlow%20and%20would%20like%20to%20claim%20my%20100%25%20refund%20%2F%20free%20license.%0A%0APost%20Link%28s%29%3A%20%0APlatform%28s%29%3A%20%0ATotal%20Views%20%2F%20Impressions%3A%20%0APurchase%20Email%20%28if%20already%20purchased%29%3A%20%0AProof%20Screenshot%28s%29%3A%20%5Battached%20or%20linked%5D%0A%0AThank%20you!"
                            if let url = URL(string: mailString) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 11))
                                Text("Claim via Email")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(inputBg)
                            .foregroundColor(textPrimary)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(cardBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            if let url = URL(string: "https://minaflow.krishra.com/creator-bonus") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                Text("Full Guidelines on Website")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(inputBg)
                            .foregroundColor(textPrimary)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(cardBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // In-App Claim Form (Option A)
                    if showClaimForm {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Submit Your 1,000 Views Claim")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(textPrimary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Email (for license key delivery or refund):")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                websiteTextField(placeholder: "you@example.com", text: $claimEmail)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Claim Details:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(textPrimary)

                                ZStack(alignment: .topLeading) {
                                    if claimMessageText.isEmpty {
                                        Text("Paste your claim details here...")
                                            .font(.system(size: 11))
                                            .foregroundColor(textMuted)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                    }
                                    TextEditor(text: $claimMessageText)
                                        .font(.system(size: 11, design: .monospaced))
                                        .scrollContentBackground(.hidden)
                                        .foregroundColor(textPrimary)
                                        .frame(height: 140)
                                        .padding(6)
                                        .background(inputBg)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                                }
                            }

                            // File Attachment Button & Chips
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        let panel = NSOpenPanel()
                                        panel.allowsMultipleSelection = true
                                        panel.canChooseDirectories = false
                                        panel.canChooseFiles = true
                                        panel.allowedContentTypes = [.png, .jpeg, .image, .pdf]
                                        if panel.runModal() == .OK {
                                            for url in panel.urls {
                                                if let data = try? Data(contentsOf: url), data.count < 10 * 1024 * 1024 {
                                                    if !claimAttachedFiles.contains(where: { $0.name == url.lastPathComponent }) {
                                                        claimAttachedFiles.append((name: url.lastPathComponent, data: data))
                                                    }
                                                }
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "paperclip")
                                                .font(.system(size: 11))
                                            Text("Attach Screenshot Proof...")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(cardBg)
                                        .foregroundColor(textPrimary)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    if !claimAttachedFiles.isEmpty {
                                        Text("\(claimAttachedFiles.count) attached")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(textMuted)
                                    }
                                }

                                if !claimAttachedFiles.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(claimAttachedFiles.indices, id: \.self) { idx in
                                                HStack(spacing: 4) {
                                                    Image(systemName: "doc.text.image")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(brandOrange)
                                                    Text(claimAttachedFiles[idx].name)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .lineLimit(1)
                                                    Button(action: {
                                                        claimAttachedFiles.remove(at: idx)
                                                    }) {
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundColor(textMuted)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(cardBg)
                                                .cornerRadius(5)
                                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(cardBorder, lineWidth: 1))
                                            }
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                Button(action: { submitClaim() }) {
                                    HStack(spacing: 6) {
                                        if isSubmittingClaim {
                                            ProgressView()
                                                .controlSize(.small)
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 11))
                                        }
                                        Text(isSubmittingClaim ? "Submitting..." : "Submit Claim")
                                            .font(.system(size: 11.5, weight: .bold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(brandOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(7)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSubmittingClaim || claimEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || claimMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                if let msg = claimStatusMessage {
                                    HStack(spacing: 5) {
                                        if claimSentSuccess {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 11))
                                        }
                                        Text(msg)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(claimSentSuccess ? .green : brandOrange)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(inputBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Helper Views & Actions
    private func addSnippet() {
        let trig = newTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let exp = newExpansion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trig.isEmpty, !exp.isEmpty else { return }
        snippets[trig] = exp
        ConfigManager.shared.updateSnippets(snippets)
        newTrigger = ""
        newExpansion = ""
    }

    private func removeSnippet(trigger: String) {
        snippets.removeValue(forKey: trigger)
        ConfigManager.shared.updateSnippets(snippets)
    }

    private func addCustomVocab(word: String? = nil) {
        let rawTerm = (word ?? newVocabWord).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTerm.isEmpty else { return }
        guard customVocabulary.count < 50 else { return }
        let term = String(rawTerm.prefix(35))
        if !customVocabulary.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) {
            customVocabulary.append(term)
            ConfigManager.shared.updateCustomVocabulary(customVocabulary)
        }
        newVocabWord = ""
    }

    private func removeCustomVocab(_ word: String) {
        customVocabulary.removeAll { $0 == word }
        ConfigManager.shared.updateCustomVocabulary(customVocabulary)
    }

    private func clearAllCustomVocab() {
        customVocabulary.removeAll()
        ConfigManager.shared.updateCustomVocabulary(customVocabulary)
    }

    private func addSnippetPreset(trigger: String, expansion: String) {
        snippets[trigger] = expansion
        ConfigManager.shared.updateSnippets(snippets)
    }

    private func activateLicense() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            licenseMessage = "Please enter or paste your license key."
            return
        }
        isActivating = true
        licenseMessage = ""

        Task {
            let result = await DodoPaymentsService.shared.activate(licenseKey: key)
            await MainActor.run {
                isActivating = false
                if result.success {
                    isLicenseActivated = true
                    ConfigManager.shared.activateLicenseLocally(licenseKey: key, instanceId: result.instanceId ?? "")
                    licenseInstanceId = result.instanceId ?? ""
                    licenseMessage = "License activated successfully! Pro unlocked."
                    MinaMenuController.shared.updateMenu()
                } else {
                    licenseMessage = result.message
                }
            }
        }
    }

    private func deactivateLicense() {
        guard !licenseKey.isEmpty else { return }
        isDeactivating = true
        licenseMessage = ""

        Task {
            let _ = await DodoPaymentsService.shared.deactivate(licenseKey: licenseKey, instanceId: licenseInstanceId)
            await MainActor.run {
                isDeactivating = false
                isLicenseActivated = false
                isAIPolishEnabled = false
                isEditModeEnabled = false
                ConfigManager.shared.deactivateLicenseLocally()
                licenseKey = ""
                licenseInstanceId = ""
                licenseMessage = "License deactivated on this Mac."
                MinaMenuController.shared.updateMenu()
            }
        }
    }

    private func openCheckoutPage() {
        if let url = URL(string: "https://minaflow.krishra.com/#pricing") {
            NSWorkspace.shared.open(url)
        }
    }

    private func testAndSaveGroqKey() {
        let key = groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingGroq = true
        groqValidationStatus = "Testing key with Groq..."
        groqIsValid = nil

        Task {
            let result = await AIService.shared.validateGroqKey(key)
            await MainActor.run {
                isCheckingGroq = false
                groqIsValid = result.isValid
                groqValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateGroqApiKey(key)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveDeepgramKey() {
        let key = deepgramApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingDeepgram = true
        deepgramValidationStatus = "Testing key with Deepgram..."
        deepgramIsValid = nil

        Task {
            let result = await AIService.shared.validateDeepgramKey(key)
            await MainActor.run {
                isCheckingDeepgram = false
                deepgramIsValid = result.isValid
                deepgramValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateDeepgramApiKey(key)
                    apiKeySaved = true
                }
            }
        }
    }

    private func testAndSaveCustomConfig() {
        let urlStr = customApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlStr.isEmpty else { return }
        isCheckingCustom = true
        customValidationStatus = "Connecting to endpoint..."
        customIsValid = nil

        Task {
            let result = await AIService.shared.validateCustomEndpoint(baseUrl: urlStr, apiKey: customApiKey, model: customModel)
            await MainActor.run {
                isCheckingCustom = false
                customIsValid = result.isValid
                customValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateCustomApiUrl(urlStr)
                    ConfigManager.shared.updateCustomApiKey(customApiKey)
                    ConfigManager.shared.updateCustomModel(customModel)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveOpenAIKey() {
        let key = openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingOpenAI = true
        openaiValidationStatus = "Testing key with OpenAI..."
        openaiIsValid = nil

        Task {
            let result = await AIService.shared.validateOpenAIKey(key)
            await MainActor.run {
                isCheckingOpenAI = false
                openaiIsValid = result.isValid
                openaiValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateOpenAIApiKey(key)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveAnthropicKey() {
        let key = anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingAnthropic = true
        anthropicValidationStatus = "Testing key with Anthropic..."
        anthropicIsValid = nil

        Task {
            let result = await AIService.shared.validateAnthropicKey(key)
            await MainActor.run {
                isCheckingAnthropic = false
                anthropicIsValid = result.isValid
                anthropicValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateAnthropicApiKey(key)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveOpenRouterKey() {
        let key = openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingOpenRouter = true
        openrouterValidationStatus = "Testing key with OpenRouter..."
        openrouterIsValid = nil

        Task {
            let result = await AIService.shared.validateOpenRouterKey(key)
            await MainActor.run {
                isCheckingOpenRouter = false
                openrouterIsValid = result.isValid
                openrouterValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateOpenRouterApiKey(key)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveGeminiKey() {
        let key = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingGemini = true
        geminiValidationStatus = "Testing key with Google Gemini..."
        geminiIsValid = nil

        Task {
            let result = await AIService.shared.validateGeminiKey(key)
            await MainActor.run {
                isCheckingGemini = false
                geminiIsValid = result.isValid
                geminiValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateGeminiApiKey(key)
                    apiKeySaved = true
                    if !self.isAIPolishEnabled {
                        self.isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                    }
                }
            }
        }
    }

    private func testAndSaveCohereKey() {
        let key = cohereApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingCohere = true
        cohereValidationStatus = "Testing key with Cohere..."
        cohereIsValid = nil

        Task {
            let result = await AIService.shared.validateCohereKey(key)
            await MainActor.run {
                isCheckingCohere = false
                cohereIsValid = result.isValid
                cohereValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateCohereApiKey(key)
                    apiKeySaved = true
                }
            }
        }
    }

    private func testAndSaveSonioxKey() {
        let key = sonioxApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingSoniox = true
        sonioxValidationStatus = "Testing key with Soniox..."
        sonioxIsValid = nil

        Task {
            let result = await AIService.shared.validateSonioxKey(key)
            await MainActor.run {
                isCheckingSoniox = false
                sonioxIsValid = result.isValid
                sonioxValidationStatus = result.message
                if result.isValid {
                    ConfigManager.shared.updateSonioxApiKey(key)
                    apiKeySaved = true
                }
            }
        }
    }


    private func websiteCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(brandOrange.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(brandOrange)
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(textPrimary)

                Spacer()
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.02), radius: 4, x: 0, y: 1)
    }

    private func websitePillToggle(title: String, subtitle: String?, isOn: Binding<Bool>, onToggle: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }
            }
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isOn.wrappedValue.toggle()
                    onToggle()
                }
            }) {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn.wrappedValue ? brandOrange : (isDarkMode ? Color(red: 45/255, green: 45/255, blue: 50/255) : Color(red: 220/255, green: 220/255, blue: 225/255)))
                        .frame(width: 38, height: 22)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func websiteTextField(placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textFieldStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(inputBg)
        .foregroundColor(textPrimary)
        .font(.system(size: 12, design: .monospaced))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorder, lineWidth: 1)
        )
    }

    private func websiteButton(title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(brandOrange)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: brandOrange.opacity(0.2), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func compactOptionButton(title: String, icon: String, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? brandOrange : textMuted)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? textPrimary : textMuted)

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? brandOrange.opacity(0.18) : cardBg)
                        .foregroundColor(isSelected ? brandOrange : textMuted)
                        .cornerRadius(4)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(brandOrange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? brandOrange.opacity(0.08) : inputBg)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? brandOrange.opacity(0.5) : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeOptionCard(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? brandOrange : textMuted)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? textPrimary : textMuted)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(textMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(brandOrange)
                }
            }
            .padding(10)
            .background(isSelected ? brandOrange.opacity(0.08) : inputBg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? brandOrange.opacity(0.5) : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toneOptionCard(title: String, description: String, icon: String, isSelected: Bool, isProOnly: Bool, action: @escaping () -> Void) -> some View {
        let isLocked = isProOnly && !isLicenseActivated
        return Button(action: {
            if isLocked {
                openCheckoutPage()
            } else {
                action()
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(brandOrange)
                        .padding(.top, 3)
                } else {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? brandOrange : Color(white: 0.5), lineWidth: 1.5)
                            .frame(width: 15, height: 15)
                        if isSelected {
                            Circle()
                                .fill(brandOrange)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected && !isLocked ? brandOrange : textMuted)
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected && !isLocked ? textPrimary : (isLocked ? textMuted : textPrimary))
                        if isLocked {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(brandOrange.opacity(0.15))
                                .foregroundColor(brandOrange)
                                .cornerRadius(4)
                        }
                    }
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }
                Spacer()
                if isLocked {
                    Text("Unlock ($1.99)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(brandOrange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(brandOrange.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(isSelected && !isLocked ? brandOrange.opacity(0.08) : inputBg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected && !isLocked ? brandOrange.opacity(0.6) : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func providerChip(p: AIProvider) -> some View {
        let isSelected = provider == p
        return Button(action: {
            provider = p
            ConfigManager.shared.updateProvider(p)
            selectedModel = ConfigManager.shared.config.llmModel
        }) {
            Text(p.displayName.components(separatedBy: " (").first ?? p.rawValue.capitalized)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? brandOrange : inputBg)
                .foregroundColor(isSelected ? .white : textMuted)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func modelChip(m: AIModelOption) -> some View {
        let isSelected = selectedModel == m.id
        return Button(action: {
            selectedModel = m.id
            ConfigManager.shared.updateLlmModel(m.id)
        }) {
            Text(m.displayName)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? brandOrange : inputBg)
                .foregroundColor(isSelected ? .white : textMuted)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func sttChip(p: STTProvider) -> some View {
        let isSelected = (sttProvider == p) || (p == .groq && (sttProvider == .localWhisper || sttProvider == .custom))
        return Button(action: {
            sttProvider = p
            ConfigManager.shared.updateSTTProvider(p)
        }) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(p.displayName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? brandOrange : inputBg)
            .foregroundColor(isSelected ? .white : textMuted)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func deepgramModelChip(id: String, name: String) -> some View {
        let isSelected = deepgramModel == id
        return Button(action: {
            deepgramModel = id
            ConfigManager.shared.updateDeepgramModel(id)
        }) {
            Text(name)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? brandOrange : inputBg)
                .foregroundColor(isSelected ? .white : textMuted)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func apiKeyValidationBadge(status: String?, isValid: Bool?, isChecking: Bool) -> some View {
        Group {
            if isChecking {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text(status ?? "Validating...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textMuted)
                }
            } else if let valid = isValid, let text = status {
                HStack(spacing: 6) {
                    Image(systemName: valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                    Text(text)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(valid ? .green : .red)
            }
        }
    }

    // MARK: - Tab 7: Support & Feedback
    private var supportFeedbackTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card 1: Submit Feedback & Bug Report
            websiteCard(title: "Submit Feedback or Report an Issue", icon: "bubble.left.and.exclamationmark.bubble.right.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Encountered a speech recognition error, language bug, or have a suggestion? Let us know directly so we can resolve it.")
                        .font(.system(size: 12))
                        .foregroundColor(textMuted)

                    // Issue Category Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)

                        HStack(spacing: 8) {
                            ForEach(["Bug Report", "Language / Accuracy", "Feature Request", "General Feedback"], id: \.self) { cat in
                                let isSel = feedbackCategory == cat
                                Button(action: { feedbackCategory = cat }) {
                                    Text(cat)
                                        .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isSel ? brandOrange.opacity(0.15) : inputBg)
                                        .foregroundColor(isSel ? brandOrange : textPrimary)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSel ? brandOrange : cardBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Contact Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Email (Optional, for developer reply):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)

                        websiteTextField(placeholder: "you@example.com", text: $feedbackEmail)
                    }

                    // Description Field with Fixed CSS & Inset Padding
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description & Steps to Reproduce:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)

                        ZStack(alignment: .topLeading) {
                            if feedbackDescription.isEmpty {
                                Text("Tell us what happened, report a bug, or request a feature...")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(textMuted.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $feedbackDescription)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 11.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .frame(minHeight: 95, maxHeight: 130)
                                .foregroundColor(textPrimary)
                        }
                        .background(inputBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardBorder, lineWidth: 1))
                    }

                    Divider().background(cardBorder.opacity(0.7))

                    // Action Button & Status
                    HStack(spacing: 12) {
                        Button(action: { submitFeedbackToTelegram() }) {
                            HStack(spacing: 6) {
                                if isSendingFeedback {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 11))
                                }
                                Text(isSendingFeedback ? "Sending..." : "Send Feedback")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(brandOrange)
                            .foregroundColor(.white)
                            .cornerRadius(7)
                            .shadow(color: brandOrange.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSendingFeedback || feedbackDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let msg = feedbackStatusMessage {
                            HStack(spacing: 6) {
                                if feedbackSentSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 12))
                                }
                                Text(msg)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(feedbackSentSuccess ? .green : brandOrange)
                            }
                            .padding(.vertical, 2)
                        }

                        Spacer()
                    }
                }
            }

            // Card 2: System & Diagnostic Information
            websiteCard(title: "System Diagnostics & Environment", icon: "terminal.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    let osVer = ProcessInfo.processInfo.operatingSystemVersionString
                    let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
                    #if arch(arm64)
                    let chipArch = "Apple Silicon"
                    #else
                    let chipArch = "Intel x86_64"
                    #endif

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        systemInfoPill(label: "App Version", value: "MinaFlow v\(appVer)")
                        systemInfoPill(label: "Operating System", value: "macOS \(osVer)")
                        systemInfoPill(label: "Chip Architecture", value: chipArch)
                        systemInfoPill(label: "STT Engine", value: ConfigManager.shared.config.sttProvider.displayName + " (" + ConfigManager.shared.config.localWhisperModel + ")")
                        systemInfoPill(label: "Language Mode", value: selectedLanguages.first ?? "English")
                        systemInfoPill(label: "AI Polish", value: isAIPolishEnabled ? "Enabled" : "Raw Whisper (Free)")
                    }

                }
            }

            // Card 3: Help & Community Links
            websiteCard(title: "Help, Community & Updates", icon: "lifepreserver.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: "https://krishra.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.system(size: 11))
                                Text("Website & Documentation")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(inputBg)
                            .foregroundColor(textPrimary)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            UpdaterService.shared.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text("Check for App Updates")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(inputBg)
                            .foregroundColor(textPrimary)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
            }
        }
    }

    private func systemInfoPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textMuted)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textPrimary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inputBg)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
    }

    private func generateDiagnosticsReport() -> String {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #if arch(arm64)
        let chipArch = "Apple Silicon"
        #else
        let chipArch = "Intel (x86_64)"
        #endif
        let cfg = ConfigManager.shared.config
        let logs = (try? String(contentsOfFile: "/tmp/minatype.log", encoding: .utf8)) ?? ""
        let lastLogs = logs.components(separatedBy: "\n").suffix(50).joined(separator: "\n")

        return """
        ### MinaFlow Diagnostic Report
        - App Version: \(appVer) (\(build))
        - Operating System: macOS \(osVer)
        - Hardware: \(chipArch)
        - STT Provider: \(cfg.sttProvider.displayName)
        - Local Whisper Model: \(cfg.localWhisperModel)
        - Language Mode: \(cfg.languageMode)
        - Selected Languages: \(cfg.selectedLanguages.joined(separator: ", "))
        - AI Polish Enabled: \(cfg.isAIPolishEnabled)
        - License Activated: \(cfg.isLicenseActivated)

        #### Recent Log Output:
        ```
        \(lastLogs)
        ```
        """
    }

    private func submitFeedbackToTelegram() {
        let category = feedbackCategory
        let contact = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = feedbackDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            feedbackStatusMessage = "Please describe the issue or suggestion before sending."
            return
        }

        isSendingFeedback = true
        feedbackSentSuccess = false
        feedbackStatusMessage = "Sending..."

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let diagnostics = generateDiagnosticsReport()

        let payload: [String: Any] = [
            "category": category,
            "contact": contact.isEmpty ? "Not provided" : contact,
            "description": description,
            "diagnostics": diagnostics,
            "appVersion": appVersion
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            isSendingFeedback = false
            feedbackStatusMessage = "Failed to encode feedback data."
            return
        }

        // Primary: krishra.com/api/minaflow/feedback, fallback to workers.dev
        let primaryUrl = URL(string: "https://krishra.com/api/minaflow/feedback")!
        let fallbackUrl = URL(string: "https://minaflow-ai-gateway.boltscraper.workers.dev/api/feedback")!

        func executePost(url: URL, isFallback: Bool = false) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 12

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                        self.isSendingFeedback = false
                        self.feedbackSentSuccess = true
                        self.feedbackStatusMessage = "✓ Thank you! Your feedback has been sent."
                        self.feedbackDescription = ""
                    } else if !isFallback {
                        executePost(url: fallbackUrl, isFallback: true)
                    } else {
                        self.isSendingFeedback = false
                        self.feedbackStatusMessage = "Could not send feedback. Please check your internet connection."
                    }
                }
            }.resume()
        }

        executePost(url: primaryUrl)
    }

    private func submitClaim() {
        let email = claimEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = claimMessageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty else {
            claimStatusMessage = "Please enter your email to receive the license key."
            return
        }
        guard !message.isEmpty else {
            claimStatusMessage = "Please provide your claim details."
            return
        }

        isSubmittingClaim = true
        claimSentSuccess = false
        claimStatusMessage = "Submitting claim..."

        var payload: [String: Any] = [
            "contactEmail": email,
            "claimText": message,
            "notes": "Submitted in-app via MinaFlow macOS App"
        ]

        if !claimAttachedFiles.isEmpty {
            let attachmentsPayload: [[String: String]] = claimAttachedFiles.map { file in
                return [
                    "filename": file.name,
                    "mimeType": "image/png",
                    "base64": file.data.base64EncodedString()
                ]
            }
            payload["attachments"] = attachmentsPayload
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            isSubmittingClaim = false
            claimStatusMessage = "Failed to encode claim data."
            return
        }

        let primaryUrl = URL(string: "https://krishra.com/api/minaflow/claim")!
        let fallbackUrl = URL(string: "https://minaflow-ai-gateway.boltscraper.workers.dev/api/claim")!

        func executeClaimPost(url: URL, isFallback: Bool = false) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 15

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                        self.isSubmittingClaim = false
                        self.claimSentSuccess = true
                        self.claimStatusMessage = "✓ Claim submitted! Krishna will review your claim and send your license key / refund within 24 hours."
                        self.claimAttachedFiles.removeAll()
                    } else if !isFallback {
                        executeClaimPost(url: fallbackUrl, isFallback: true)
                    } else {
                        self.isSubmittingClaim = false
                        self.claimSentSuccess = false
                        self.claimStatusMessage = "Could not submit claim. Please check your internet connection or email minaflow@krishra.com."
                    }
                }
            }.resume()
        }

        executeClaimPost(url: primaryUrl)
    }

    private func openLogDirectory() {
        let logURL = URL(fileURLWithPath: "/tmp/minatype.log")
        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logURL])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp"))
        }
    }
}

// MARK: - AppKit Scroll Reset Helper
struct ScrollResetHelper: NSViewRepresentable {
    let trigger: Int

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resetScroll(nsView)
    }

    private func resetScroll(_ nsView: NSView) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            let targetY: CGFloat = (scrollView.documentView?.isFlipped ?? true) ? 0 : max(0, (scrollView.documentView?.frame.height ?? 0) - clipView.frame.height)
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let scrollView = nsView.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            let targetY: CGFloat = (scrollView.documentView?.isFlipped ?? true) ? 0 : max(0, (scrollView.documentView?.frame.height ?? 0) - clipView.frame.height)
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }
    }
}

// MARK: - OpenAI-Compatible Provider Modal (Exact UI Match to media_1789149127090.png)
struct OpenAICompatibleConfigModal: View {
    @Binding var isPresented: Bool
    @Binding var apiUrl: String
    @Binding var modelId: String
    @Binding var apiKey: String
    let isDarkMode: Bool
    let onSave: (String, String, String) -> Void

    @State private var tempApiUrl: String = ""
    @State private var tempModelId: String = ""
    @State private var tempApiKey: String = ""
    @State private var testStatus: String? = nil
    @State private var testSuccess: Bool? = nil
    @State private var isTesting: Bool = false

    private var brandOrange: Color { Color(red: 1.0, green: 0.333, blue: 0.0) }
    private var modalBg: Color { isDarkMode ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color.white }
    private var modalBorder: Color { isDarkMode ? Color(red: 45/255, green: 45/255, blue: 50/255) : Color(red: 220/255, green: 220/255, blue: 225/255) }
    private var inputBg: Color { isDarkMode ? Color(red: 16/255, green: 16/255, blue: 18/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var textPrimary: Color { isDarkMode ? Color.white : Color(red: 15/255, green: 15/255, blue: 17/255) }
    private var textMuted: Color { isDarkMode ? Color(red: 156/255, green: 163/255, blue: 175/255) : Color(red: 107/255, green: 114/255, blue: 128/255) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configure OpenAI-Compatible Provider")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(textPrimary)
                    Text("Set the API base URL, model ID, and optional API key for any OpenAI-compatible endpoint.")
                        .font(.system(size: 12))
                        .foregroundColor(textMuted)
                }

                Divider().background(modalBorder)

                // Field 1: API Base URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Base URL")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                    TextField("https://api.openai.com/v1", text: $tempApiUrl)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(modalBorder, lineWidth: 1))
                    Text("Examples: https://api.openai.com/v1, http://localhost:11434/v1")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }

                // Field 2: Model ID
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model ID")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                    TextField("e.g. gpt-4o-mini, llama3.2, mistral", text: $tempModelId)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(modalBorder, lineWidth: 1))
                }

                // Field 3: API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                    SecureField("Leave empty for no authentication", text: $tempApiKey)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(inputBg)
                        .foregroundColor(textPrimary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(modalBorder, lineWidth: 1))
                }

                Divider().background(modalBorder)

                // Footer Buttons & Test status
                HStack(spacing: 10) {
                    if isTesting {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Testing connection...")
                                .font(.system(size: 11.5))
                                .foregroundColor(textMuted)
                        }
                    } else if let status = testStatus, let ok = testSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(ok ? .green : .red)
                            Text(status)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(ok ? .green : .red)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(inputBg)
                    .foregroundColor(textPrimary)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(modalBorder, lineWidth: 1))
                    .buttonStyle(.plain)

                    Button(action: runTest) {
                        Text(isTesting ? "Testing..." : "Test")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(inputBg)
                            .foregroundColor(textPrimary)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(modalBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting || tempApiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(brandOrange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(width: 490)
            .background(modalBg)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(modalBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.45), radius: 24, y: 12)
        }
        .onAppear {
            tempApiUrl = apiUrl.isEmpty ? "https://api.openai.com/v1" : apiUrl
            tempModelId = modelId.isEmpty ? "gpt-4o-mini" : modelId
            tempApiKey = apiKey
        }
    }

    private func runTest() {
        let base = tempApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return }
        isTesting = true
        testStatus = nil
        testSuccess = nil

        Task {
            let res = await AIService.shared.testOpenAICompatibleConnection(
                baseUrl: base,
                modelId: tempModelId,
                apiKey: tempApiKey
            )
            await MainActor.run {
                isTesting = false
                testSuccess = res.success
                testStatus = res.message
            }
        }
    }

    private func save() {
        let base = tempApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = tempModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        apiUrl = base
        modelId = model
        apiKey = key

        onSave(base, model, key)
        isPresented = false
    }
}

public typealias SettingsView = DashboardView



