import SwiftUI
import AppKit
import ServiceManagement
import AVFoundation

// MARK: - MinaFlow Onboarding — Premium Two-Column Layout

public struct OnboardingView: View {

    @State private var step: Int = 0
    @State private var hotkey: String   = ConfigManager.shared.config.hotkey
    @State private var mode: String     = ConfigManager.shared.config.mode
    @State private var micGranted: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var axGranted: Bool  = AXIsProcessTrusted()
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }()
    @State private var showDockIcon: Bool = ConfigManager.shared.config.showDockIcon
    @State private var permTimer: Timer? = nil
    @State private var isDark: Bool = (ConfigManager.shared.config.appTheme == "dark")

    // Live Mic Test State (matching Screenshot 1)
    @State private var liveAudioLevel: Float = 0.0
    @State private var isTestingMic: Bool = false
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared

    // Dictation Languages State (matching Screenshots 2 & 3)
    @State private var languageMode: String = ConfigManager.shared.config.languageMode
    @State private var selectedLanguages: [String] = ConfigManager.shared.config.selectedLanguages
    @State private var searchLanguageQuery: String = ""
    @State private var showLanguagePickerModal: Bool = false

    private let availableLanguages: [String] = AppLanguages.all

    // Speech Engine Setup State
    @ObservedObject private var localWhisper = LocalWhisperEngine.shared
    @State private var engineSetupKind: String = "local" // "local" or "cloud"
    @State private var selectedLocalModel: String = ConfigManager.shared.config.localWhisperModel.isEmpty ? "base" : ConfigManager.shared.config.localWhisperModel
    @State private var selectedCloudProvider: String = "Groq" // "Groq", "Deepgram", "OpenAI", "Localhost (Ollama)"
    @State private var cloudApiKey: String = ""
    @State private var customOllamaUrl: String = ConfigManager.shared.config.customApiUrl
    @State private var isVerifyingCloud: Bool = false
    @State private var cloudVerificationMessage: String? = nil
    @State private var isCloudVerified: Bool = false

    private let steps: [(icon: String, label: String)] = [
        ("hand.wave.fill",      "Welcome"),
        ("lock.shield.fill",    "Permissions"),
        ("mic.badge.waveform",  "Test Mic"),
        ("cpu",                 "Speech Engine"),
        ("globe",               "Languages"),
        ("keyboard",            "Trigger Key"),
        ("hand.tap",            "Trigger Mode"),
        ("checkmark.seal.fill", "All Set"),
    ]

    // ── Design tokens ──────────────────────────────────────────────────────────
    private var orange: Color   { Color(red: 1.0, green: 0.333, blue: 0.0) }
    private var bg: Color       { isDark ? Color(red:9/255,  green:9/255,  blue:11/255)
                                          : Color(red:250/255,green:250/255,blue:252/255) }
    private var sidebar: Color  { isDark ? Color(red:13/255, green:13/255, blue:16/255)
                                          : Color(red:242/255,green:242/255,blue:245/255) }
    private var card: Color     { isDark ? Color(red:20/255, green:20/255, blue:24/255) : .white }
    private var border: Color   { isDark ? Color(red:39/255, green:39/255, blue:42/255)
                                          : Color(red:228/255,green:228/255,blue:231/255) }
    private var input: Color    { isDark ? Color(red:12/255, green:12/255, blue:15/255)
                                          : Color(red:244/255,green:244/255,blue:246/255) }
    private var text: Color     { isDark ? .white : Color(red:9/255,green:9/255,blue:11/255) }
    private var muted: Color    { isDark ? Color(red:120/255,green:120/255,blue:130/255)
                                          : Color(red:113/255,green:113/255,blue:122/255) }

    // ── Body ───────────────────────────────────────────────────────────────────
    public var body: some View {
        HStack(spacing: 0) {
            sidebarView
            contentView
        }
        .frame(width: 700, height: 520)
        .background(bg.ignoresSafeArea())
        .onDisappear { permTimer?.invalidate() }
    }

    // MARK: - Left Sidebar
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App logo + name
            VStack(alignment: .leading, spacing: 10) {
                if let img = Bundle.main.path(forResource: "AppLogo", ofType: "png")
                    .flatMap({ NSImage(contentsOfFile: $0) }) {
                    Image(nsImage: img)
                        .resizable().scaledToFit()
                        .frame(width: 48, height: 48)
                        .cornerRadius(12)
                        .shadow(color: orange.opacity(0.3), radius: 8, x: 0, y: 3)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(orange).frame(width: 48, height: 48)
                        Image(systemName: "waveform").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MinaFlow").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(text)
                    Text("for Mac").font(.system(size: 10, weight: .semibold)).foregroundColor(muted)
                }
            }
            .padding(.top, 28).padding(.horizontal, 20)

            Spacer().frame(height: 32)

            // Step list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<steps.count, id: \.self) { i in
                    sidebarStep(index: i)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Progress text
            Text("\(step + 1) of \(steps.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(muted)
                .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .frame(width: 190)
        .background(sidebar)
        .overlay(
            Rectangle().fill(border).frame(width: 1), alignment: .trailing
        )
    }

    private func sidebarStep(index: Int) -> some View {
        let done    = index < step
        let current = index == step
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(done ? orange : (current ? orange.opacity(0.15) : Color.clear))
                    .frame(width: 26, height: 26)
                Circle()
                    .strokeBorder(done ? orange : (current ? orange : border), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(current ? orange : muted)
                }
            }
            Text(steps[index].label)
                .font(.system(size: 12, weight: current ? .bold : .medium))
                .foregroundColor(current ? text : (done ? muted : muted))
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(current ? orange.opacity(0.07) : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Right Content
    private var contentView: some View {
        VStack(spacing: 0) {
            // Step content (perfect vertical & horizontal centering)
            ZStack {
                switch step {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: testMicStep
                case 3: speechEngineStep
                case 4: languagesStep
                case 5: triggerKeyStep
                case 6: triggerModeStep
                case 7: allSetStep
                default: welcomeStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32).padding(.vertical, 16)

            Divider().background(border)

            // Bottom nav
            HStack {
                if step > 0 {
                    Button(action: { withAnimation(.spring(response: 0.3)) { step -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                            Text("Back").font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(input).foregroundColor(text)
                        .cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(step == steps.count - 1 ? "Start Dictating" : "Continue")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: step == steps.count - 1 ? "waveform" : "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 9)
                    .background(canAdvance ? orange : border)
                    .foregroundColor(canAdvance ? .white : muted)
                    .cornerRadius(9)
                    .shadow(color: canAdvance ? orange.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain).disabled(!canAdvance)
                .animation(.easeInOut(duration: 0.2), value: canAdvance)
            }
            .padding(.horizontal, 28).padding(.vertical, 16)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1:
            return micGranted && axGranted
        case 3:
            if engineSetupKind == "local" {
                return localWhisper.isModelDownloaded(selectedLocalModel)
            } else {
                return isCloudVerified ||
                    (selectedCloudProvider == "Groq" && !ConfigManager.shared.config.groqApiKey.isEmpty) ||
                    (selectedCloudProvider == "Deepgram" && !ConfigManager.shared.config.deepgramApiKey.isEmpty) ||
                    (selectedCloudProvider == "OpenAI" && !ConfigManager.shared.config.openaiApiKey.isEmpty) ||
                    (selectedCloudProvider == "Localhost (Ollama)" && !ConfigManager.shared.config.customApiUrl.isEmpty)
            }
        default:
            return true
        }
    }

    private func advance() {
        if step == 3 {
            // Save Speech Engine choice
            if engineSetupKind == "local" {
                ConfigManager.shared.updateSTTProvider(.localWhisper)
                ConfigManager.shared.updateLocalWhisperModel(selectedLocalModel)
            } else {
                switch selectedCloudProvider {
                case "Groq":
                    ConfigManager.shared.updateSTTProvider(.groq)
                    if !cloudApiKey.isEmpty { ConfigManager.shared.updateGroqApiKey(cloudApiKey) }
                case "Deepgram":
                    ConfigManager.shared.updateSTTProvider(.deepgram)
                    if !cloudApiKey.isEmpty { ConfigManager.shared.updateDeepgramApiKey(cloudApiKey) }
                case "OpenAI":
                    ConfigManager.shared.updateSTTProvider(.openai)
                    if !cloudApiKey.isEmpty { ConfigManager.shared.updateOpenaiApiKey(cloudApiKey) }
                case "Localhost (Ollama)":
                    ConfigManager.shared.updateSTTProvider(.custom)
                    ConfigManager.shared.updateCustomApiUrl(customOllamaUrl)
                default:
                    break
                }
            }
        }
        if step == steps.count - 1 { finish(); return }
        withAnimation(.spring(response: 0.3)) { step += 1 }
        if step == 1 { startPolling() }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "MinaFlow_HasCompletedOnboarding")
        permTimer?.invalidate()
        ConfigManager.shared.updateShowDockIcon(showDockIcon)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        MinaMenuController.shared.showMenuBarIcon()
        OnboardingWindowController.shared.close()
    }

    // MARK: ── Step 1: Welcome ─────────────────────────────────────────────────
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                // Big logo
                Group {
                    if let img = Bundle.main.path(forResource: "AppLogo", ofType: "png")
                        .flatMap({ NSImage(contentsOfFile: $0) }) {
                        Image(nsImage: img).resizable().scaledToFit()
                            .frame(width: 88, height: 88).cornerRadius(20)
                            .shadow(color: orange.opacity(0.4), radius: 20, x: 0, y: 8)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(orange).frame(width: 88, height: 88)
                                .shadow(color: orange.opacity(0.4), radius: 20, x: 0, y: 8)
                            Image(systemName: "waveform").font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("Welcome to MinaFlow")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(text)
                    Text("Voice-type instantly in any app on your Mac.\nSet up takes less than a minute.")
                        .font(.system(size: 13)).foregroundColor(muted)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }

                HStack(spacing: 10) {
                    featurePill("waveform.circle.fill", "Instant Dictation")
                    featurePill("sparkles",             "AI Polish")
                    featurePill("globe",                "99+ Languages")
                }
            }
            Spacer()
        }
    }

    // MARK: ── Step 2: Permissions ─────────────────────────────────────────────
    private var permissionsStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("Permissions Required",
                            sub: "MinaFlow needs both permissions to work. Tap each button to grant access.")

                VStack(spacing: 12) {
                    // ── Microphone ──
                    permissionCard(
                        icon: "mic.fill", iconColor: .blue,
                        title: "Microphone",
                        detail: "Records your voice for transcription. A macOS dialog will appear.",
                        isGranted: micGranted,
                        grantLabel: "Allow Microphone",
                        onGrant: {
                            Task {
                                let ok = await AudioRecorder.shared.requestMicrophonePermission()
                                await MainActor.run {
                                    withAnimation { micGranted = ok }
                                    // If already denied, open Settings
                                    if !ok {
                                        NSWorkspace.shared.open(
                                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                                        )
                                    }
                                }
                            }
                        }
                    )

                    // ── Accessibility ──
                    permissionCard(
                        icon: "hand.raised.fill", iconColor: orange,
                        title: "Accessibility",
                        detail: "Types transcribed text at your cursor. Opens Privacy & Security settings.",
                        isGranted: axGranted,
                        grantLabel: "Open Privacy Settings",
                        onGrant: {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            )
                        }
                    )
                }

                if !micGranted || !axGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").font(.system(size: 11))
                        Text("Continue unlocks once both are granted — this page auto-detects changes.")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(muted)
                }
            }
            Spacer()
        }
        .onAppear { startPolling() }
    }

    // MARK: ── Step 3: Test Your Microphone (Matching Screenshot 1) ─────────────
    private var testMicStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Test your microphone")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(text)
                    Text("Speak normally to see the live audio meter react.\nBuilt-in or wired microphones are recommended.")
                        .font(.system(size: 12.5)).foregroundColor(muted)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }

                // Centered White/Dark Card with Orange Audio Bars
                VStack(spacing: 20) {
                    Text("Do you see orange bars while you speak?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(text)

                    // 14-bar live animated visualizer in MinaFlow orange
                    HStack(spacing: 6) {
                        ForEach(0..<14, id: \.self) { index in
                            let threshold = Float(index) / 14.0
                            let isActive = liveAudioLevel > threshold
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive ? orange : (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)))
                                .frame(width: 8, height: isActive ? CGFloat(24 + (index % 3) * 8) : 24)
                                .animation(.easeOut(duration: 0.1), value: liveAudioLevel)
                        }
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(input.opacity(0.6))
                    .cornerRadius(10)

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // In-place microphone picker menu (Wispr Flow style)
                            Menu {
                                ForEach(audioDeviceManager.inputDevices) { device in
                                    Button(action: {
                                        audioDeviceManager.setDefaultInputDevice(id: device.id)
                                        AudioRecorder.shared.startMeteringTest { level in
                                            DispatchQueue.main.async { self.liveAudioLevel = level }
                                        }
                                    }) {
                                        HStack {
                                            Text(device.name)
                                            if device.id == audioDeviceManager.currentInputDeviceID {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Divider()
                                Button("Open System Sound Settings...") {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound?input")!)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 10))
                                    Text("Change microphone")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(input).foregroundColor(text)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                            }
                            .menuStyle(.borderlessButton)

                            Button(action: { advance() }) {
                                Text("Yes, looks good")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 16).padding(.vertical, 7)
                                    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        // Subtle feedback of currently selected mic
                        Text("Active: \(audioDeviceManager.currentDeviceName)")
                            .font(.system(size: 10.5))
                            .foregroundColor(muted)
                    }
                }
                .padding(24)
                .background(card)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            }
            Spacer()
        }
        .onAppear {
            audioDeviceManager.refreshDevices()
            AudioRecorder.shared.startMeteringTest { level in
                DispatchQueue.main.async {
                    self.liveAudioLevel = level
                }
            }
        }
        .onDisappear {
            AudioRecorder.shared.stopMeteringTest()
        }
    }

    // MARK: ── Step 4: Speech Engine Setup ───────────────────
    private var speechEngineStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("Choose your speech engine")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(text)
                    Text("Select 100% offline Metal GPU Whisper or connect your cloud API key.")
                        .font(.system(size: 12)).foregroundColor(muted)
                }

                // 2-Way Switcher (Local vs Cloud)
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            engineSetupKind = "local"
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("On-Device Whisper (Offline)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(engineSetupKind == "local" ? .white : muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(engineSetupKind == "local" ? orange : input)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            engineSetupKind = "cloud"
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Cloud API / BYOK")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(engineSetupKind == "cloud" ? .white : muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(engineSetupKind == "cloud" ? orange : input)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(input)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))

                // Engine Card Content
                if engineSetupKind == "local" {
                    localWhisperOnboardingCard
                } else {
                    cloudEngineOnboardingCard
                }
            }
            Spacer()
        }
    }

    private var localWhisperOnboardingCard: some View {
        let opt = LocalWhisperEngine.availableModels.first(where: { $0.id == selectedLocalModel }) ?? LocalWhisperEngine.availableModels[1]
        let isDownloaded = localWhisper.isModelDownloaded(selectedLocalModel)
        let isDownloading = localWhisper.isDownloading[selectedLocalModel] ?? false
        let progress = localWhisper.downloadProgress[selectedLocalModel] ?? 0.0

        return VStack(alignment: .leading, spacing: 12) {
            whisperPrivacyBanner
            whisperModelSelector(opt: opt)
            Divider().background(border)
            whisperStatusAction(opt: opt, isDownloaded: isDownloaded, isDownloading: isDownloading, progress: progress)
        }
        .padding(14)
        .background(card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
    }

    private var whisperPrivacyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(orange)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("100% Offline • Apple Metal GPU Acceleration")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(text)
                Text("Audio is processed directly on Apple Silicon GPU/Neural Engine. Zero audio leaves your Mac, works on airplanes, and 100% free forever.")
                    .font(.system(size: 10.5))
                    .foregroundColor(muted)
            }
        }
        .padding(10)
        .background(orange.opacity(0.08))
        .cornerRadius(8)
    }

    private func whisperModelSelector(opt: WhisperModelOption) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Whisper Model Variant:")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(text)
                Spacer()
                Menu {
                    ForEach(LocalWhisperEngine.availableModels) { m in
                        Button(action: {
                            selectedLocalModel = m.id
                            ConfigManager.shared.updateLocalWhisperModel(m.id)
                        }) {
                            HStack {
                                Text("\(m.displayName) (\(m.sizeDescription))")
                                if m.id == selectedLocalModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(opt.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(input).foregroundColor(text)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
            }

            HStack(spacing: 6) {
                specPill(label: opt.parameters)
                specPill(label: opt.sizeDescription)
                specPill(label: opt.ramDescription)
                specPill(label: opt.speedDescription)
            }
        }
    }

    @ViewBuilder
    private func whisperStatusAction(opt: WhisperModelOption, isDownloaded: Bool, isDownloading: Bool, progress: Double) -> some View {
        if isDownloaded {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(opt.displayName) is Ready")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(text)
                    Text("Model downloaded on your Mac. You are ready to dictate offline.")
                        .font(.system(size: 10.5))
                        .foregroundColor(muted)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)
        } else if isDownloading {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading \(opt.displayName)...")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(text)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(orange)
                }
                ProgressView(value: progress, total: 1.0)
                    .accentColor(orange)
                HStack {
                    Text("One-time download. Safe to wait 10–30s on broadband.")
                        .font(.system(size: 10))
                        .foregroundColor(muted)
                    Spacer()
                    Button("Cancel") {
                        localWhisper.cancelDownload(for: selectedLocalModel)
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(muted)
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(input)
            .cornerRadius(8)
        } else {
            VStack(spacing: 6) {
                Button(action: {
                    localWhisper.startDownload(for: selectedLocalModel)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Download \(opt.displayName) (\(opt.sizeDescription))")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: orange.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)

                Text("Click to download once. Required before first dictation.")
                    .font(.system(size: 10.5))
                    .foregroundColor(muted)
            }
        }
    }

    private var cloudEngineOnboardingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Picker
            HStack(spacing: 6) {
                ForEach(["Groq", "Deepgram", "OpenAI", "Localhost (Ollama)"], id: \.self) { p in
                    Button(action: {
                        selectedCloudProvider = p
                        cloudVerificationMessage = nil
                        isCloudVerified = false
                    }) {
                        Text(p)
                            .font(.system(size: 11, weight: selectedCloudProvider == p ? .bold : .medium))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(selectedCloudProvider == p ? orange.opacity(0.15) : input)
                            .foregroundColor(selectedCloudProvider == p ? orange : text)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedCloudProvider == p ? orange : border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if selectedCloudProvider == "Localhost (Ollama)" {
                    Text("Ollama API URL:")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(text)
                    TextField("http://localhost:11434/v1", text: $customOllamaUrl)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(input)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                } else {
                    HStack {
                        Text("\(selectedCloudProvider) API Key:")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(text)
                        Spacer()
                        if selectedCloudProvider == "Groq" {
                            Button("Get Free Key →") {
                                NSWorkspace.shared.open(URL(string: "https://console.groq.com/keys")!)
                            }.font(.system(size: 10.5)).foregroundColor(orange).buttonStyle(.plain)
                        } else if selectedCloudProvider == "Deepgram" {
                            Button("Get Free Key →") {
                                NSWorkspace.shared.open(URL(string: "https://console.deepgram.com")!)
                            }.font(.system(size: 10.5)).foregroundColor(orange).buttonStyle(.plain)
                        }
                    }

                    SecureField("Paste your \(selectedCloudProvider) API key", text: $cloudApiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(input)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                }
            }

            // Test / Verify connection
            HStack {
                if let msg = cloudVerificationMessage {
                    HStack(spacing: 5) {
                        Image(systemName: isCloudVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isCloudVerified ? .green : .red)
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(isCloudVerified ? .green : .red)
                    }
                }
                Spacer()
                Button(action: verifyCloudKey) {
                    HStack(spacing: 5) {
                        if isVerifyingCloud {
                            ProgressView().controlSize(.small)
                        }
                        Text(isVerifyingCloud ? "Testing..." : (isCloudVerified ? "Verified ✓" : "Test Connection"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isCloudVerified ? Color.green : orange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isVerifyingCloud || (selectedCloudProvider != "Localhost (Ollama)" && cloudApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(14)
        .background(card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
    }

    private func verifyCloudKey() {
        let key = cloudApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedCloudProvider == "Localhost (Ollama)" {
            ConfigManager.shared.updateCustomApiUrl(customOllamaUrl)
            ConfigManager.shared.updateSTTProvider(.custom)
            isCloudVerified = true
            cloudVerificationMessage = "Ollama endpoint configured"
            return
        }
        guard !key.isEmpty else { return }
        isVerifyingCloud = true
        cloudVerificationMessage = nil

        Task {
            if selectedCloudProvider == "Groq" {
                var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
                req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 6
                do {
                    let (_, res) = try await URLSession.shared.data(for: req)
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                            self.isCloudVerified = true
                            self.cloudVerificationMessage = "Groq connection verified!"
                            ConfigManager.shared.updateGroqApiKey(key)
                            ConfigManager.shared.updateSTTProvider(.groq)
                        } else {
                            self.isCloudVerified = false
                            self.cloudVerificationMessage = "Invalid Groq API key"
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        self.isCloudVerified = false
                        self.cloudVerificationMessage = "Connection failed: \(error.localizedDescription)"
                    }
                }
            } else if selectedCloudProvider == "Deepgram" {
                var req = URLRequest(url: URL(string: "https://api.deepgram.com/v1/projects")!)
                req.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 6
                do {
                    let (_, res) = try await URLSession.shared.data(for: req)
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                            self.isCloudVerified = true
                            self.cloudVerificationMessage = "Deepgram connection verified!"
                            ConfigManager.shared.updateDeepgramApiKey(key)
                            ConfigManager.shared.updateSTTProvider(.deepgram)
                        } else {
                            self.isCloudVerified = false
                            self.cloudVerificationMessage = "Invalid Deepgram API key"
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        self.isCloudVerified = false
                        self.cloudVerificationMessage = "Connection failed: \(error.localizedDescription)"
                    }
                }
            } else if selectedCloudProvider == "OpenAI" {
                var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 6
                do {
                    let (_, res) = try await URLSession.shared.data(for: req)
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                            self.isCloudVerified = true
                            self.cloudVerificationMessage = "OpenAI connection verified!"
                            ConfigManager.shared.updateOpenaiApiKey(key)
                            ConfigManager.shared.updateSTTProvider(.openai)
                        } else {
                            self.isCloudVerified = false
                            self.cloudVerificationMessage = "Invalid OpenAI API key"
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isVerifyingCloud = false
                        self.isCloudVerified = false
                        self.cloudVerificationMessage = "Connection failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func specPill(label: String) -> some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(muted)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(input)
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 1))
    }

    // MARK: ── Step 5: Languages Selection ────────────────────────────────────
    private var languagesStep: some View {
        let isEnglishOnly = ConfigManager.shared.config.localWhisperModel.lowercased().contains(".en") || ConfigManager.shared.config.localWhisperModel.lowercased().contains("parakeet")
        let activeLang = selectedLanguages.first ?? "English"

        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("Select your spoken language")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(text)
                    Text("Single-language mode runs 2x faster with zero hallucinations.")
                        .font(.system(size: 12)).foregroundColor(muted)
                }

                VStack(alignment: .leading, spacing: 14) {
                    if isEnglishOnly {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18))
                                .foregroundColor(orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Locked to English")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(text)
                                Text("Your active speech model (\(ConfigManager.shared.config.localWhisperModel)) is English-only optimized. To speak Hindi, Spanish, etc., select a Multilingual model.")
                                    .font(.system(size: 11))
                                    .foregroundColor(muted)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(orange.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(orange.opacity(0.25), lineWidth: 1))
                    } else {
                        // Current Active Language Display
                        HStack {
                            Text("Active Spoken Language:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(text)
                            Spacer()
                            Text(activeLang)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(orange.opacity(0.15))
                                .cornerRadius(6)
                        }

                        Divider().background(border)

                        // Popular Languages Quick Grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Popular Languages:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(muted)

                            let quick = ["English", "Hinglish", "Hindi", "Spanish", "French", "German", "Japanese", "Chinese", "Italian", "Portuguese", "Korean", "Russian"]
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(quick, id: \.self) { l in
                                    let isSel = (activeLang == l)
                                    Button(action: {
                                        selectedLanguages = [l]
                                        ConfigManager.shared.updateSpokenLanguage(l)
                                    }) {
                                        HStack(spacing: 4) {
                                            if isSel {
                                                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                                            }
                                            Text(l)
                                                .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(isSel ? orange : input)
                                        .foregroundColor(isSel ? .white : text)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSel ? orange : border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Searchable All 99+ Languages
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation { showLanguagePickerModal.toggle() }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: showLanguagePickerModal ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(showLanguagePickerModal ? "Hide All 99+ Languages" : "Browse All 99+ Languages...")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                .foregroundColor(orange)
                            }
                            .buttonStyle(.plain)

                            if showLanguagePickerModal {
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(muted)
                                        TextField("Search 99+ languages...", text: $searchLanguageQuery)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12))
                                        if !searchLanguageQuery.isEmpty {
                                            Button(action: { searchLanguageQuery = "" }) {
                                                Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundColor(muted)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(8)
                                    .background(input)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))

                                    let filtered = availableLanguages.filter {
                                        searchLanguageQuery.isEmpty || $0.localizedCaseInsensitiveContains(searchLanguageQuery)
                                    }

                                    ScrollView {
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                            ForEach(filtered, id: \.self) { l in
                                                let isSel = (activeLang == l)
                                                Button(action: {
                                                    selectedLanguages = [l]
                                                    ConfigManager.shared.updateSpokenLanguage(l)
                                                }) {
                                                    HStack(spacing: 4) {
                                                        if isSel {
                                                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                                                        }
                                                        Text(l)
                                                            .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                                            .lineLimit(1)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.horizontal, 6).padding(.vertical, 5)
                                                    .background(isSel ? orange.opacity(0.15) : input)
                                                    .foregroundColor(isSel ? orange : text)
                                                    .cornerRadius(6)
                                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSel ? orange : border, lineWidth: 1))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .frame(maxHeight: 140)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .background(card)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
            }
            Spacer()
        }
    }

    // MARK: ── Step 5: Trigger Key ─────────────────────────────────────────────
    private var triggerKeyStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("Choose Your Trigger Key",
                            sub: "Hold or press this key anywhere on your Mac to start dictating.")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    keyOption("⌥ Space",  "Option + Space",  "option+space")
                    keyOption("Right ⌥",  "Right Option",    "rightOption")
                    keyOption("🌐 Fn",    "Fn (Globe Key)",  "fn")
                    keyOption("Right ⌘",  "Right Command",   "rightCommand")
                }

                if hotkey == "fn" {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(orange).font(.system(size: 11))
                        Text("If Fn opens the Emoji picker, go to System Settings → Keyboard and set 'Press 🌐 key to' → 'Do Nothing'.")
                            .font(.system(size: 10.5)).foregroundColor(muted).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10).background(orange.opacity(0.07)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(orange.opacity(0.2), lineWidth: 1))
                }
            }
            Spacer()
        }
    }

    // MARK: ── Step 6: Trigger Mode ────────────────────────────────────────────
    private var triggerModeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("Choose Dictation Mode",
                            sub: "Select how you prefer to trigger dictation.")

                modeCard("toggle",
                    icon: "record.circle", badge: "Default",
                    title: "Press to Start & Stop",
                    detail: "Press once to start dictating, press again to stop and paste. Ideal for natural hands-free speech.")

                modeCard("pushToTalk",
                    icon: "waveform.badge.mic", badge: "Push-to-Talk",
                    title: "Hold to Speak",
                    detail: "Hold the key down while speaking. Release to instantly paste. Best for quick replies.")
            }
            Spacer()
        }
    }

    // MARK: ── Step 5: All Set ─────────────────────────────────────────────────
    private var allSetStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 70, height: 70)
                    Circle().fill(Color.green.opacity(0.07)).frame(width: 54, height: 54)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold)).foregroundColor(.green)
                }
                .shadow(color: Color.green.opacity(0.2), radius: 10, x: 0, y: 3)

                VStack(spacing: 4) {
                    Text("You're all set!")
                        .font(.system(size: 21, weight: .bold, design: .rounded)).foregroundColor(text)
                    Text("MinaFlow is ready. Your shortcut and menu bar\nicon will activate when you tap Continue.")
                        .font(.system(size: 12)).foregroundColor(muted)
                        .multilineTextAlignment(.center).lineSpacing(2.5)
                }

                // Recap chips
                HStack(spacing: 8) {
                    recapChip(icon: "keyboard",       label: hotkeyName(hotkey))
                    recapChip(icon: mode == "pushToTalk" ? "hand.tap" : "record.circle",
                              label: mode == "pushToTalk" ? "Hold to Speak" : "Press to Start / Stop")
                }

                VStack(spacing: 8) {
                    // Launch at login toggle
                    HStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.system(size: 13)).foregroundColor(muted).frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Launch at Login").font(.system(size: 12, weight: .semibold)).foregroundColor(text)
                            Text("Start MinaFlow automatically on login")
                                .font(.system(size: 10.5)).foregroundColor(muted)
                        }
                        Spacer()
                        pillToggle(isOn: $launchAtLogin) {
                            if #available(macOS 13.0, *) {
                                try? launchAtLogin ? SMAppService.mainApp.register()
                                                   : SMAppService.mainApp.unregister()
                            }
                        }
                    }
                    .padding(11).background(card).cornerRadius(11)
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 1))

                    // Show app icon in Dock toggle
                    HStack(spacing: 12) {
                        Image(systemName: "dock.rectangle")
                            .font(.system(size: 13)).foregroundColor(muted).frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Show App Icon in Dock").font(.system(size: 12, weight: .semibold)).foregroundColor(text)
                            Text("Keep MinaFlow in your macOS Dock & ⌘Tab switcher")
                                .font(.system(size: 10.5)).foregroundColor(muted)
                        }
                        Spacer()
                        pillToggle(isOn: $showDockIcon) {
                            ConfigManager.shared.updateShowDockIcon(showDockIcon)
                            NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
                        }
                    }
                    .padding(11).background(card).cornerRadius(11)
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 1))
                }
            }
            Spacer()
        }
    }

    // MARK: - Reusable Components ───────────────────────────────────────────────

    private func stepHeading(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(text)
            Text(sub).font(.system(size: 12)).foregroundColor(muted).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featurePill(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(orange)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(text)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(card).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
    }

    private func permissionCard(icon: String, iconColor: Color, title: String, detail: String,
                                isGranted: Bool, grantLabel: String, onGrant: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(isGranted ? Color.green.opacity(0.12) : iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isGranted ? .green : iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(text)
                Text(detail).font(.system(size: 11)).foregroundColor(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isGranted {
                Text("Granted").font(.system(size: 11, weight: .bold)).foregroundColor(.green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.1)).cornerRadius(7)
            } else {
                Button(action: onGrant) {
                    Text(grantLabel).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(orange).foregroundColor(.white).cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).background(card).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isGranted ? Color.green.opacity(0.35) : border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: isGranted)
    }

    private func keyOption(_ badge: String, _ title: String, _ value: String) -> some View {
        let sel = hotkey == value
        return Button(action: { hotkey = value; ConfigManager.shared.updateHotkey(value) }) {
            HStack {
                Text(badge)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(sel ? orange : text)
                    .lineLimit(1)
                    .fixedSize()
                Text(title).font(.system(size: 12, weight: sel ? .bold : .medium)).foregroundColor(sel ? text : muted)
                Spacer()
                if sel { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(orange) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(sel ? orange.opacity(0.08) : input).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? orange.opacity(0.5) : border, lineWidth: 1))
        }
        .buttonStyle(.plain).animation(.easeInOut(duration: 0.12), value: sel)
    }

    private func modeCard(_ value: String, icon: String, badge: String, title: String, detail: String) -> some View {
        let sel = mode == value
        return Button(action: { mode = value; ConfigManager.shared.updateMode(value) }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(sel ? orange.opacity(0.12) : input).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                        .foregroundColor(sel ? orange : muted)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(sel ? text : muted)
                        Text(badge).font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(sel ? orange.opacity(0.15) : border.opacity(0.5))
                            .foregroundColor(sel ? orange : muted).cornerRadius(4)
                    }
                    Text(detail).font(.system(size: 11)).foregroundColor(muted)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if sel {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(orange)
                        .padding(.top, 10)
                }
            }
            .padding(16).background(sel ? orange.opacity(0.05) : card).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? orange.opacity(0.5) : border, lineWidth: 1))
        }
        .buttonStyle(.plain).animation(.easeInOut(duration: 0.15), value: sel)
    }

    private func recapChip(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(orange)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(text)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(card).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    private func pillToggle(isOn: Binding<Bool>, onChange: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isOn.wrappedValue.toggle()
                onChange()
            }
        }) {
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Capsule()
                    .fill(isOn.wrappedValue ? orange
                          : (isDark ? Color(red:45/255,green:45/255,blue:50/255)
                                    : Color(red:220/255,green:220/255,blue:225/255)))
                    .frame(width: 38, height: 22)
                Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
        }.buttonStyle(.plain)
    }

    // MARK: - Helpers
    private func startPolling() {
        permTimer?.invalidate()
        permTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            let ax  = AXIsProcessTrusted()
            if mic != micGranted || ax != axGranted {
                withAnimation(.easeInOut(duration: 0.25)) { micGranted = mic; axGranted = ax }
            }
        }
    }

    private func hotkeyName(_ k: String) -> String {
        switch k {
        case "rightOption":  return "Right ⌥"
        case "fn":           return "🌐 Fn"
        case "rightCommand": return "Right ⌘"
        default:             return "⌥ Space"
        }
    }
}

// MARK: - Dev Reset Helper
public enum OnboardingResetHelper {
    public static func resetAll() {
        UserDefaults.standard.removeObject(forKey: "MinaFlow_HasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "MinaFlow_LastLicenseValidation")
        print("[Debug] Flags cleared. Quit & relaunch to see onboarding.")
    }
}
