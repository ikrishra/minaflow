import SwiftUI
import AppKit
import ServiceManagement

private let brandOrange = Color(red: 1.0, green: 0.333, blue: 0.0) // #FF5500

public struct MenuBarPopoverView: View {
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @State private var selectedLanguages: [String] = ConfigManager.shared.config.selectedLanguages
    @State private var isRecording: Bool = AudioRecorder.shared.isRecording
    @State private var toneMode: String = ConfigManager.shared.config.toneMode
    @State private var languageMode: String = ConfigManager.shared.config.languageMode
    @State private var triggerMode: String = ConfigManager.shared.config.mode
    @State private var hotkey: String = ConfigManager.shared.config.hotkey
    @State private var isLicenseActivated: Bool = ConfigManager.shared.config.isLicenseActivated
    @State private var isAIPolishEnabled: Bool = ConfigManager.shared.config.isAIPolishEnabled
    @State private var hasAIProvider: Bool = ConfigManager.shared.config.hasConfiguredAIProvider
    @State private var trialUsed: Int = ConfigManager.shared.config.trialDictationsUsed
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }()
    @Environment(\.colorScheme) var colorScheme

    private var shortcutBadgeText: String {
        switch hotkey {
        case "rightOption": return "Right ⌥"
        case "fn": return "🌐 Fn"
        case "rightCommand": return "Right ⌘"
        default: return "⌥ Space"
        }
    }

    private var triggerSubtitle: String {
        let isHold = triggerMode == "pushToTalk"
        if isRecording {
            return isHold ? "Release \(shortcutBadgeText) to paste" : "Press \(shortcutBadgeText) again to stop & paste"
        } else {
            return isHold ? "Hold \(shortcutBadgeText) anywhere to speak" : "Press \(shortcutBadgeText) to start dictating"
        }
    }

    private var isDark: Bool {
        let theme = ConfigManager.shared.config.appTheme
        if theme == "light" { return false }
        if theme == "dark" { return true }
        return colorScheme == .dark
    }

    private var cardBg: Color {
        isDark ? Color(red: 22/255, green: 22/255, blue: 26/255) : Color(red: 244/255, green: 244/255, blue: 247/255)
    }

    private var cardBorder: Color {
        isDark ? Color(red: 44/255, green: 44/255, blue: 50/255) : Color(red: 228/255, green: 228/255, blue: 233/255)
    }

    private var textPrimary: Color {
        isDark ? Color.white : Color(red: 9/255, green: 9/255, blue: 11/255)
    }

    private var textMuted: Color {
        isDark ? Color(red: 161/255, green: 161/255, blue: 170/255) : Color(red: 113/255, green: 113/255, blue: 122/255)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // 1. Header (Website style branding)
            HStack(spacing: 8) {
                if let img = NSImage(contentsOfFile: Bundle.main.resourcePath.map { "\($0)/AppLogo.png" } ?? "") ?? Bundle.main.path(forResource: "AppLogo", ofType: "png").flatMap({ NSImage(contentsOfFile: $0) }) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(brandOrange)
                            .frame(width: 22, height: 22)
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text("MinaFlow")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)

                Text("for Mac")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(brandOrange.opacity(0.12))
                    .foregroundColor(brandOrange)
                    .cornerRadius(8)

                Spacer()

                if isLicenseActivated {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                } else {
                    Text("FREE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(brandOrange.opacity(0.15))
                        .foregroundColor(brandOrange)
                        .cornerRadius(5)
                }

                Button(action: {
                    MinaMenuController.shared.closePopover()
                    DashboardWindowController.shared.show(tab: 0)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textMuted)
                        .padding(5)
                        .background(cardBg)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Open Dashboard (⌘,)")
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)

            // 2. Primary Dictation Action Button
            Button(action: {
                MinaMenuController.shared.toggleDictationFromUI()
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRecording ? "Stop Dictation & Paste" : "Start Dictation")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(triggerSubtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Text(shortcutBadgeText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isRecording ? Color.red : brandOrange)
                        .shadow(color: brandOrange.opacity(0.25), radius: 5, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            // 3. Trigger Mode Quick Switcher (Compact Island)
            HStack(spacing: 4) {
                triggerModePill(id: "toggle", title: "Press to Start / Stop", icon: "record.circle")
                triggerModePill(id: "pushToTalk", title: "Hold to Speak", icon: "hand.tap")
            }
            .padding(2)
            .background(cardBg)
            .cornerRadius(7)
            .padding(.horizontal, 14)

            // Double-tap hint
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(brandOrange)
                Text("Double-tap \(shortcutBadgeText) to copy & re-paste")
                    .font(.system(size: 10))
                    .foregroundColor(textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
            }
            .padding(.horizontal, 16)

            Divider()
                .background(cardBorder.opacity(0.7))

            // Microphone Quick Selector (Wispr Flow style)
            microphoneSection

            // Languages Quick Selector & Manager (Wispr Flow style)
            languagesSection

            Divider()
                .background(cardBorder.opacity(0.7))

            // 3.5 AI Polish Master Toggle
            if isLicenseActivated {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isAIPolishEnabled ? brandOrange : textMuted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AI Polish")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text(isAIPolishEnabled ? "Auto filler removal & tones active" : (hasAIProvider ? "Turn ON to adapt tone & clean speech" : "Requires AI key in Settings"))
                            .font(.system(size: 9))
                            .foregroundColor(textMuted)
                    }
                    Spacer()
                    Button(action: {
                        if !hasAIProvider && !isAIPolishEnabled {
                            MinaMenuController.shared.closePopover()
                            DashboardWindowController.shared.show(tab: 3)
                            FloatingHUDWindow.shared.setMode(.error(message: "Add AI Key in Settings to enable Polish"))
                            FloatingHUDWindow.shared.hide(after: 3.0)
                            return
                        }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isAIPolishEnabled.toggle()
                            if !isAIPolishEnabled {
                                toneMode = "veryCasual"
                            }
                            ConfigManager.shared.updateAIPolishEnabled(isAIPolishEnabled)
                        }
                        FloatingHUDWindow.shared.setMode(.listening)
                        FloatingHUDWindow.shared.hide(after: 2.0)
                    }) {
                        ZStack(alignment: isAIPolishEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(isAIPolishEnabled ? brandOrange : (isDark ? Color(red: 45/255, green: 45/255, blue: 50/255) : Color(red: 220/255, green: 220/255, blue: 225/255)))
                                .frame(width: 32, height: 18)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .padding(2)
                                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            }

            // 4. Writing Tone Quick Select (Pro Only) / Raw Dictation Mode (Free)
            if isLicenseActivated {
                let isAIReady = isAIPolishEnabled && hasAIProvider
                let needsToggleOn = hasAIProvider && !isAIPolishEnabled

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Writing Tone")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(textMuted)
                        Spacer()
                        if needsToggleOn {
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    isAIPolishEnabled = true
                                    ConfigManager.shared.updateAIPolishEnabled(true)
                                }
                                FloatingHUDWindow.shared.setMode(.listening)
                                FloatingHUDWindow.shared.hide(after: 2.0)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "power")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("Turn ON AI Polish")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color.orange.opacity(0.18))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else if !hasAIProvider {
                            Button(action: {
                                MinaMenuController.shared.closePopover()
                                DashboardWindowController.shared.show(tab: 3)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8))
                                    Text("Requires AI Key")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 5) {
                        toneChip(id: "auto", label: "Auto", isAIReady: isAIReady)
                        toneChip(id: "formal", label: "Formal", isAIReady: isAIReady)
                        toneChip(id: "casual", label: "Casual", isAIReady: isAIReady)
                        toneChip(id: "veryCasual", label: "Direct", isAIReady: isAIReady)
                    }

                    if needsToggleOn {
                        HStack(spacing: 4) {
                            Text("API key configured. Turn ON AI Polish to use tones.")
                                .font(.system(size: 9))
                                .foregroundColor(textMuted)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    isAIPolishEnabled = true
                                    ConfigManager.shared.updateAIPolishEnabled(true)
                                }
                                FloatingHUDWindow.shared.setMode(.listening)
                                FloatingHUDWindow.shared.hide(after: 2.0)
                            }) {
                                Text("Turn ON →")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(brandOrange)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 1)
                    } else if !hasAIProvider {
                        HStack(spacing: 4) {
                            Text("AI key required to rewrite tone.")
                                .font(.system(size: 9))
                                .foregroundColor(textMuted)
                            Spacer()
                            Button(action: {
                                MinaMenuController.shared.closePopover()
                                DashboardWindowController.shared.show(tab: 3)
                            }) {
                                Text("Set up →")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(brandOrange)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 14)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(brandOrange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Raw Whisper Dictation")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Writing Tones & AI Polish require Pro")
                            .font(.system(size: 9.5))
                            .foregroundColor(textMuted)
                    }
                    Spacer()
                    Button(action: {
                        MinaMenuController.shared.closePopover()
                        DashboardWindowController.shared.show(tab: 6)
                    }) {
                        Text("Upgrade ($1.99)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(brandOrange)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(9)
                .background(brandOrange.opacity(0.08))
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(brandOrange.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 14)
            }

            Divider()
                .background(cardBorder.opacity(0.7))

            // 5. Quick Actions (Clean, focused macOS utility design)
            VStack(spacing: 2) {
                menuActionButton(title: "Open Dashboard...", icon: "square.grid.2x2", shortcut: "⌘,") {
                    MinaMenuController.shared.closePopover()
                    DashboardWindowController.shared.show(tab: 0)
                }

                menuActionButton(title: "Dictation History...", icon: "clock.arrow.circlepath") {
                    MinaMenuController.shared.closePopover()
                    DashboardWindowController.shared.show(tab: 1)
                }

                menuActionButton(title: "Support & Feedback...", icon: "lifepreserver.fill") {
                    MinaMenuController.shared.closePopover()
                    DashboardWindowController.shared.show(tab: 7)
                }

                menuActionButton(title: "Check for Updates...", icon: "arrow.triangle.2.circlepath") {
                    MinaMenuController.shared.closePopover()
                    UpdaterService.shared.checkForUpdates()
                }

                Divider()
                    .background(cardBorder.opacity(0.7))
                    .padding(.vertical, 2)

                // Launch at Login inline toggle
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                        .frame(width: 14)
                    Text("Launch at Login")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary)
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(brandOrange)
                        .scaleEffect(0.75)
                        .onChange(of: launchAtLogin) { newVal in
                            if #available(macOS 13.0, *) {
                                try? newVal ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Divider()
                    .background(cardBorder.opacity(0.7))
                    .padding(.vertical, 2)

                menuActionButton(title: "Quit MinaFlow", icon: "power", shortcut: "⌘Q", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 290)
        .background(isDark ? Color(red: 13/255, green: 13/255, blue: 16/255) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
        .onAppear {
            refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowTrialUpdated"))) { _ in
            refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowLanguagesUpdated"))) { _ in
            refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowToneUpdated"))) { _ in
            refreshState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MinaFlowAIPolishUpdated"))) { _ in
            refreshState()
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private var microphoneSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11))
                .foregroundColor(textMuted)
                .frame(width: 14)

            Text("Microphone")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textPrimary)

            Spacer()

            Menu {
                Button(action: {
                    if let first = audioDeviceManager.inputDevices.first(where: {
                        $0.name.lowercased().contains("built-in") || $0.name.lowercased().contains("macbook")
                    }) ?? audioDeviceManager.inputDevices.first {
                        audioDeviceManager.setDefaultInputDevice(id: first.id)
                    }
                }) {
                    HStack {
                        Text("Auto-detect (\(audioDeviceManager.currentDeviceName))")
                        if audioDeviceManager.inputDevices.first(where: {
                            $0.name.lowercased().contains("built-in") || $0.name.lowercased().contains("macbook")
                        })?.id == audioDeviceManager.currentInputDeviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

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
                HStack(spacing: 4) {
                    Text(audioDeviceManager.currentDeviceName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 130, alignment: .trailing)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(cardBg)
                .foregroundColor(textPrimary)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cardBorder, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
    }

      private var languagesSection: some View {
        let isEnglishOnly = LocalWhisperEngine.shared.isEnglishOnlyModel(ConfigManager.shared.config.localWhisperModel)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(textMuted)
                    .frame(width: 14)
                Text("Spoken Language")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textPrimary)

                Spacer()

                if isEnglishOnly {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        Text("Locked to English")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(brandOrange.opacity(0.12))
                    .foregroundColor(brandOrange)
                    .cornerRadius(5)
                } else {
                    Menu {
                        let popular = ["English", "Hinglish", "Hindi", "Spanish", "French", "German", "Japanese", "Chinese", "Italian", "Portuguese", "Korean", "Russian"]
                        ForEach(popular, id: \.self) { l in
                            Button(action: {
                                if l.lowercased() == "hinglish" {
                                    let isHinglishReady = LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                                                          LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
                                    if !isHinglishReady {
                                        MinaMenuController.shared.closePopover()
                                        LocalWhisperEngine.promptForHinglishDownloadIfNeeded()
                                        return
                                    }
                                }
                                selectedLanguages = [l]
                                ConfigManager.shared.updateSpokenLanguage(l)
                            }) {
                                if selectedLanguages.first == l {
                                    Text("✓ \(l)")
                                } else {
                                    Text(l)
                                }
                            }
                        }
                        Divider()
                        Menu("More Languages (99+)...") {
                            ForEach(AppLanguages.all.filter { !popular.contains($0) }, id: \.self) { l in
                                Button(action: {
                                    if l.lowercased() == "hinglish" {
                                        let isHinglishReady = LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                                                              LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
                                        if !isHinglishReady {
                                            MinaMenuController.shared.closePopover()
                                            LocalWhisperEngine.promptForHinglishDownloadIfNeeded()
                                            return
                                        }
                                    }
                                    selectedLanguages = [l]
                                    ConfigManager.shared.updateSpokenLanguage(l)
                                }) {
                                    if selectedLanguages.first == l {
                                        Text("✓ \(l)")
                                    } else {
                                        Text(l)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedLanguages.first ?? "English")
                                .font(.system(size: 9.5, weight: .bold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(cardBg)
                        .foregroundColor(brandOrange)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(brandOrange.opacity(0.3), lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private func refreshState() {
        let config = ConfigManager.shared.config
        triggerMode       = config.mode
        isLicenseActivated = config.isLicenseActivated
        isAIPolishEnabled  = config.isAIPolishEnabled
        toneMode          = config.isAIPolishEnabled ? config.toneMode : "veryCasual"
        languageMode      = config.languageMode
        selectedLanguages = config.selectedLanguages
        hotkey            = config.hotkey
        hasAIProvider      = config.hasConfiguredAIProvider
        trialUsed          = config.trialDictationsUsed
        audioDeviceManager.refreshDevices()
        // Silently revalidate license on every menu bar open (throttled to once every 4 hours)
        revalidateLicenseIfNeeded()
    }

    private func revalidateLicenseIfNeeded() {
        let config = ConfigManager.shared.config
        if config.isLicenseActivated && !config.licenseKey.isEmpty {
            let key = config.licenseKey
            let instanceId = config.licenseInstanceId

            Task {
                let isValid = await DodoPaymentsService.shared.validate(
                    licenseKey: key,
                    instanceId: instanceId.isEmpty ? nil : instanceId
                )
                await MainActor.run {
                    if isValid == true {
                        UserDefaults.standard.set(Date(), forKey: "MinaFlow_LastLicenseValidation")
                    } else if isValid == false {
                        ConfigManager.shared.deactivateLicenseLocally()
                        withAnimation { isLicenseActivated = false }
                        MinaMenuController.shared.updateMenu()
                        NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
                    }
                }
            }
        } else {
            Task {
                await AIService.shared.syncTrialStatusWithServer()
                await MainActor.run {
                    trialUsed = ConfigManager.shared.config.trialDictationsUsed
                }
            }
        }
    }

    private func triggerModePill(id: String, title: String, icon: String) -> some View {
        let isSelected = triggerMode == id
        return Button(action: {
            triggerMode = id
            ConfigManager.shared.updateMode(id)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isSelected ? (isDark ? Color(white: 0.22) : Color.white) : Color.clear)
            .foregroundColor(isSelected ? textPrimary : textMuted)
            .cornerRadius(5)
            .shadow(color: isSelected ? Color.black.opacity(0.1) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func toneChip(id: String, label: String, isAIReady: Bool) -> some View {
        let isSelected = toneMode == id
        let isDirect = (id == "veryCasual")
        let isAvailable = isDirect || isAIReady
        let canAutoEnable = hasAIProvider && !isAIPolishEnabled

        return Button(action: {
            if !isAvailable {
                if canAutoEnable {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isAIPolishEnabled = true
                        ConfigManager.shared.updateAIPolishEnabled(true)
                        toneMode = id
                        ConfigManager.shared.updateToneMode(id)
                    }
                    FloatingHUDWindow.shared.setMode(.listening)
                    FloatingHUDWindow.shared.hide(after: 2.0)
                    return
                }
                MinaMenuController.shared.closePopover()
                DashboardWindowController.shared.show(tab: 3)
                FloatingHUDWindow.shared.setMode(.error(message: "Add AI Key in Settings to enable tones"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                return
            }
            toneMode = id
            ConfigManager.shared.updateToneMode(id)
        }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                if !isAvailable {
                    if canAutoEnable {
                        Image(systemName: "power")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7.5))
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(isSelected ? brandOrange : cardBg)
            .foregroundColor(isSelected ? .white : (isAvailable ? textMuted : (canAutoEnable ? textPrimary : textMuted.opacity(0.4))))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? brandOrange : cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sendBugReport() {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let logSnippet = (try? String(contentsOfFile: "/tmp/minatype.log"))?
            .components(separatedBy: "\n")
            .suffix(25)
            .joined(separator: "\n") ?? "No logs available"

        let subject = "MinaFlow Bug Report / Feedback"
        let body = """
        Describe the issue or feature request:
        [Write here]

        --- Diagnostic Info ---
        App: MinaFlow v\(appVersion)
        macOS: \(osVersion)
        Date: \(Date())

        Recent Logs:
        \(logSnippet)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mailURL = URL(string: "mailto:minaflow@krishra.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(mailURL)
        }
    }

    private func menuActionButton(title: String, icon: String, shortcut: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isDestructive ? .red : textMuted)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isDestructive ? .red : textPrimary)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textMuted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

