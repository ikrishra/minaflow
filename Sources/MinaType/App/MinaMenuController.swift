import Foundation
import AppKit
import SwiftUI
import CoreAudio

public class MinaMenuController: NSObject, AudioRecorderDelegate, HotkeyManagerDelegate {
    public static let shared = MinaMenuController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var lastTranscript: String = ""
    private var isBusy = false
    private var maxRecordingTimer: Timer?

    private override init() {
        super.init()
    }

    /// Called on every launch — wires up delegates and starts hotkey monitoring.
    /// Does NOT create the menu bar status item (see showMenuBarIcon).
    public func setupCore() {
        AudioRecorder.shared.delegate = self
        HotkeyManager.shared.delegate = self
        // NOTE: HotkeyManager.startMonitoring() is called in showMenuBarIcon(),
        // so the trigger key stays inert during first-run onboarding.

        // Disable macOS default Emoji palette trigger on Globe/Fn key
        _ = Process.launchedProcess(launchPath: "/usr/bin/defaults",
                                    arguments: ["write", "com.apple.HIToolbox", "AppleFnUsageType", "-int", "0"])

        logMessage("MinaFlow delegates wired. Hotkey monitoring deferred until onboarding completes.")
    }

    /// Creates the menu bar status item AND starts hotkey monitoring.
    /// Call this only after onboarding completes.
    public func showMenuBarIcon() {
        guard statusItem == nil else { return } // already visible
        setupStatusItem()
        HotkeyManager.shared.startMonitoring()
        logMessage("MinaFlow fully active. Hotkey monitoring started.")
    }

    /// Convenience: full setup for returning users (onboarding already done).
    public func setup() {
        setupCore()
        showMenuBarIcon()
    }

    private func setupStatusItem() {
        // Default preferred position right next to Control Center / Siri (like Wispr Flow)
        let prefKey = "NSStatusItem Preferred Position com.krishna.minaflow.statusItem"
        if UserDefaults.standard.object(forKey: prefKey) == nil {
            UserDefaults.standard.set(40, forKey: prefKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Persist the user's manually chosen position (Cmd+drag to reorder in menu bar)
        statusItem.autosaveName = "com.krishna.minaflow.statusItem"
        if let button = statusItem.button {
            // Load logo from app bundle for the menu bar icon
            if let bundleIcon = loadMenuBarIcon() {
                button.image = bundleIcon
            } else {
                // Fallback to SF Symbol if logo not found
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MinaFlow")
                button.image?.isTemplate = true
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setupPopover()
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 300, height: 430)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = FirstMouseHostingController(rootView: MenuBarPopoverView())
        self.popover = pop

        NotificationCenter.default.addObserver(self, selector: #selector(closePopoverNotification), name: NSNotification.Name("MinaFlowCloseMenuPopover"), object: nil)
    }

    @objc private func closePopoverNotification() {
        closePopover()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false) {
            let menu = buildCleanMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            togglePopover()
        }
    }

    public func togglePopover() {
        guard let pop = popover, let button = statusItem.button else { return }
        if pop.isShown {
            pop.performClose(nil)
        } else {
            // Fresh state on each open with first-mouse click-through enabled
            pop.contentViewController = FirstMouseHostingController(rootView: MenuBarPopoverView())
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }

    public func closePopover() {
        popover?.performClose(nil)
    }

    public func toggleDictationFromUI() {
        if AudioRecorder.shared.isRecording {
            hotkeyDidFinish()
        } else {
            HotkeyManager.shared.notifyUIToggledRecording()
            hotkeyDidStart()
        }
    }

    public func updateMenu() {
        // Popover refreshes dynamically on click
    }

    public func buildCleanMenu() -> NSMenu {
        let menu = NSMenu()

        // App Name
        let titleItem = NSMenuItem(title: "MinaFlow", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Dictation Action
        let isRecording = AudioRecorder.shared.isRecording
        let recordTitle = isRecording ? "Stop Dictation and Paste" : "Start Dictation"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(toggleDictation), keyEquivalent: "")
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // Last Transcript
        if !lastTranscript.isEmpty {
            let truncated = lastTranscript.count > 35 ? "\(lastTranscript.prefix(35))..." : lastTranscript
            let pasteAgainItem = NSMenuItem(title: "Paste Again: \"\(truncated)\"", action: #selector(pasteAgainAction), keyEquivalent: "")
            pasteAgainItem.target = self
            menu.addItem(pasteAgainItem)

            let lastItem = NSMenuItem(title: "Copy to Clipboard", action: #selector(copyLastTranscript), keyEquivalent: "")
            lastItem.target = self
            menu.addItem(lastItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Microphone Submenu (Wispr Flow style)
        AudioDeviceManager.shared.refreshDevices()
        let micSubmenu = NSMenu()
        let devices = AudioDeviceManager.shared.inputDevices
        let currentID = AudioDeviceManager.shared.currentInputDeviceID

        let autoDetectItem = NSMenuItem(title: "Auto-detect (\(AudioDeviceManager.shared.currentDeviceName))", action: #selector(selectDefaultMic), keyEquivalent: "")
        autoDetectItem.target = self
        let isBuiltIn = AudioDeviceManager.shared.currentDeviceName.lowercased().contains("built-in") || AudioDeviceManager.shared.currentDeviceName.lowercased().contains("macbook")
        autoDetectItem.state = isBuiltIn ? .on : .off
        micSubmenu.addItem(autoDetectItem)

        if !devices.isEmpty {
            micSubmenu.addItem(NSMenuItem.separator())
            for dev in devices {
                let devItem = NSMenuItem(title: dev.displayLabel, action: #selector(selectAudioDeviceItem(_:)), keyEquivalent: "")
                devItem.target = self
                devItem.representedObject = dev.id
                devItem.state = (dev.id == currentID) ? .on : .off
                micSubmenu.addItem(devItem)
            }
        }

        let micMenuItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        micMenuItem.submenu = micSubmenu
        menu.addItem(micMenuItem)

        // Languages Submenu (Single choice & English-only lock)
        let langSubmenu = NSMenu()
        let isEnglishModel = LocalWhisperEngine.shared.isEnglishOnlyModel(ConfigManager.shared.config.localWhisperModel)
        if isEnglishModel {
            let lockItem = NSMenuItem(title: "🔒 Locked to English (English-Only Model Active)", action: nil, keyEquivalent: "")
            lockItem.isEnabled = false
            langSubmenu.addItem(lockItem)
        } else {
            let currentLang = ConfigManager.shared.config.selectedLanguages.first ?? "English"
            let popular = ["English", "Hinglish", "Hindi", "Spanish", "French", "German", "Japanese", "Chinese", "Italian", "Portuguese", "Korean", "Russian"]
            for lang in popular {
                let item = NSMenuItem(title: lang, action: #selector(selectSingleLanguageItem(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = lang
                item.state = (lang == currentLang) ? .on : .off
                langSubmenu.addItem(item)
            }
            langSubmenu.addItem(NSMenuItem.separator())
            let moreSubmenu = NSMenu()
            for lang in AppLanguages.all.filter({ !popular.contains($0) }) {
                let mItem = NSMenuItem(title: lang, action: #selector(selectSingleLanguageItem(_:)), keyEquivalent: "")
                mItem.target = self
                mItem.representedObject = lang
                mItem.state = (lang == currentLang) ? .on : .off
                moreSubmenu.addItem(mItem)
            }
            let moreMenuItem = NSMenuItem(title: "More Languages (99+)...", action: nil, keyEquivalent: "")
            moreMenuItem.submenu = moreSubmenu
            langSubmenu.addItem(moreMenuItem)
        }

        let langMenuItem = NSMenuItem(title: "Spoken Language", action: nil, keyEquivalent: "")
        langMenuItem.submenu = langSubmenu
        menu.addItem(langMenuItem)

        // Tone Mode Submenu
        let toneSubmenu = NSMenu()
        let config = ConfigManager.shared.config
        let currentTone = config.toneMode
        let isAIReady = config.canUseAIPolish && config.isAIPolishEnabled && config.hasConfiguredAIProvider

        let toneOptions: [(id: String, title: String)] = [
            ("auto", "Auto (Context-Aware)"),
            ("formal", "Professional & Formal"),
            ("casual", "Conversational & Natural"),
            ("veryCasual", "Direct Speech (Raw Whisper)")
        ]

        for opt in toneOptions {
            let item = NSMenuItem(title: opt.title, action: #selector(setToneMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = opt.id
            item.state = (opt.id == currentTone) ? .on : .off
            toneSubmenu.addItem(item)
        }

        if !isAIReady {
            toneSubmenu.addItem(NSMenuItem.separator())
            if !config.canUseAIPolish {
                let warningItem = NSMenuItem(title: "⚠️ Writing Tones require Pro", action: #selector(openProAccountSettings), keyEquivalent: "")
                warningItem.target = self
                toneSubmenu.addItem(warningItem)
            } else if !config.hasConfiguredAIProvider {
                let warningItem = NSMenuItem(title: "⚠️ Configure AI Key to enable tones", action: #selector(openAIPolishSettings), keyEquivalent: "")
                warningItem.target = self
                toneSubmenu.addItem(warningItem)
            } else if !config.isAIPolishEnabled {
                let turnOnItem = NSMenuItem(title: "⚡️ Turn ON AI Polish (Key Ready)", action: #selector(enableAIPolishFromMenu), keyEquivalent: "")
                turnOnItem.target = self
                toneSubmenu.addItem(turnOnItem)
            }
        }

        let toneTitle: String
        if !config.canUseAIPolish {
            toneTitle = "Tone & Style (Requires Pro)"
        } else if !config.hasConfiguredAIProvider {
            toneTitle = "Tone & Style (Requires AI Key)"
        } else if !config.isAIPolishEnabled {
            toneTitle = "Tone & Style (Turn ON AI Polish)"
        } else {
            toneTitle = "Tone & Style"
        }

        let toneMenuItem = NSMenuItem(title: toneTitle, action: nil, keyEquivalent: "")
        toneMenuItem.submenu = toneSubmenu
        menu.addItem(toneMenuItem)

        // Voice Snippets Submenu
        let snippetSubmenu = NSMenu()
        let snippets = ConfigManager.shared.config.snippets
        if snippets.isEmpty {
            let emptyItem = NSMenuItem(title: "No voice snippets defined", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            snippetSubmenu.addItem(emptyItem)
        } else {
            for (trigger, expansion) in snippets.sorted(by: { $0.key < $1.key }) {
                let disp = expansion.count > 30 ? "\(expansion.prefix(30))..." : expansion
                let sItem = NSMenuItem(title: "\"\(trigger)\" -> \(disp)", action: nil, keyEquivalent: "")
                sItem.isEnabled = false
                snippetSubmenu.addItem(sItem)
            }
        }
        snippetSubmenu.addItem(NSMenuItem.separator())
        let manageSnippetsItem = NSMenuItem(title: "Manage Snippets in Dashboard...", action: #selector(openSnippetsSettings), keyEquivalent: "")
        manageSnippetsItem.target = self
        snippetSubmenu.addItem(manageSnippetsItem)

        let snippetMenuItem = NSMenuItem(title: "Voice Snippets", action: nil, keyEquivalent: "")
        snippetMenuItem.submenu = snippetSubmenu
        menu.addItem(snippetMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences / Dashboard Window
        let settingsItem = NSMenuItem(title: "Open Dashboard...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let supportItem = NSMenuItem(title: "Support & Report Feedback...", action: #selector(openSupportSettings), keyEquivalent: "")
        supportItem.target = self
        menu.addItem(supportItem)

        // Sparkle In-App Updater
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        let permsItem = NSMenuItem(title: "Check Permissions...", action: #selector(checkPermissions), keyEquivalent: "")
        permsItem.target = self
        menu.addItem(permsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MinaFlow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleDictation() {
        if AudioRecorder.shared.isRecording {
            hotkeyDidFinish()
        } else {
            hotkeyDidStart()
        }
    }

    @objc public func pasteAgainAction() {
        hotkeyDidDoubleTap()
    }

    @objc private func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lastTranscript, forType: .string)
    }

    @objc private func selectDefaultMic() {
        if let first = AudioDeviceManager.shared.inputDevices.first(where: {
            $0.name.lowercased().contains("built-in") || $0.name.lowercased().contains("macbook")
        }) ?? AudioDeviceManager.shared.inputDevices.first {
            AudioDeviceManager.shared.setDefaultInputDevice(id: first.id)
            logMessage("Switched mic to auto-detect/default: \(first.name)")
        }
    }

    @objc private func selectAudioDeviceItem(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? AudioDeviceID {
            AudioDeviceManager.shared.setDefaultInputDevice(id: id)
            logMessage("Switched mic to device ID: \(id)")
        }
    }

    @objc private func selectSingleLanguageItem(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? String else { return }
        ConfigManager.shared.updateSpokenLanguage(lang)
        logMessage("Spoken language switched to: \(lang)")
    }

    @objc private func setToneMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        let config = ConfigManager.shared.config
        let isAIReady = config.canUseAIPolish && config.isAIPolishEnabled && config.hasConfiguredAIProvider
        if mode != "veryCasual" && !isAIReady {
            if config.canUseAIPolish && config.hasConfiguredAIProvider && !config.isAIPolishEnabled {
                // Key is ready! Auto-enable AI Polish and set tone!
                ConfigManager.shared.updateAIPolishEnabled(true)
                ConfigManager.shared.updateToneMode(mode)
                logMessage("Turned ON AI Polish and set Tone Mode to: \(mode)")
                updateMenu()
                FloatingHUDWindow.shared.setMode(.listening)
                FloatingHUDWindow.shared.hide(after: 2.0)
                return
            }
            closePopover()
            DashboardWindowController.shared.show(tab: 3)
            FloatingHUDWindow.shared.setMode(.error(message: "Add AI Key in Settings to enable tones"))
            FloatingHUDWindow.shared.hide(after: 3.0)
            return
        }
        ConfigManager.shared.updateToneMode(mode)
        logMessage("Tone Mode switched to: \(mode)")
    }

    @objc private func enableAIPolishFromMenu() {
        ConfigManager.shared.updateAIPolishEnabled(true)
        updateMenu()
        logMessage("AI Polish turned ON from menu")
        FloatingHUDWindow.shared.setMode(.listening)
        FloatingHUDWindow.shared.hide(after: 2.0)
    }

    @objc private func openProAccountSettings() {
        closePopover()
        DashboardWindowController.shared.show(tab: 6)
    }

    @objc private func openAIPolishSettings() {
        closePopover()
        DashboardWindowController.shared.show(tab: 3)
    }

    @objc private func openSettingsWindow() {
        closePopover()
        DashboardWindowController.shared.show(tab: 0)
    }

    @objc private func openSnippetsSettings() {
        closePopover()
        DashboardWindowController.shared.show(tab: 4)
    }

    @objc private func openSupportSettings() {
        closePopover()
        DashboardWindowController.shared.show(tab: 7)
    }

    @objc private func checkForUpdates() {
        closePopover()
        UpdaterService.shared.checkForUpdates()
    }

    @objc private func checkPermissions() {
        closePopover()
        let isAccGranted = PasteInjector.shared.isAccessibilityGranted()
        let alert = NSAlert()
        alert.messageText = "MinaFlow Permissions"
        if isAccGranted {
            alert.informativeText = "Accessibility permission is active. MinaFlow is ready to auto-type into your focused apps."
        } else {
            alert.informativeText = "Accessibility permission is required for auto-pasting and global Fn hotkey detection. Click Request to open System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                PasteInjector.shared.promptAccessibilityPermission()
            }
            return
        }
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var startContext: AppContext? = nil

    // MARK: - HotkeyManagerDelegate
    public func hotkeyDidStart() {
        guard !isBusy, !AudioRecorder.shared.isRecording else { return }

        let config = ConfigManager.shared.config

        // 0. Speech-to-Text (STT) Provider Pre-flight Validation
        let isHinglish = config.languageMode.lowercased() == "hinglish" || config.selectedLanguages.contains(where: { $0.caseInsensitiveCompare("hinglish") == .orderedSame })

        if isHinglish {
            // Hinglish uses the dedicated Apex Hinglish model
            let hinglishModelId = config.hinglishModel.isEmpty ? "apex-q8" : config.hinglishModel
            let isDownloaded = LocalWhisperEngine.shared.isModelDownloaded(hinglishModelId) ||
                               LocalWhisperEngine.shared.isModelDownloaded("apex-q8") ||
                               LocalWhisperEngine.shared.isModelDownloaded("apex-q5")
            if !isDownloaded {
                logMessage("Hinglish model is not downloaded. Prompting user for confirmation...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                LocalWhisperEngine.promptForHinglishDownloadIfNeeded()
                return
            }
        } else {
            switch config.sttProvider {
            case .localWhisper:
                let modelId = config.localWhisperModel
                if !LocalWhisperEngine.shared.isModelDownloaded(modelId) {
                    let modelName = LocalWhisperEngine.generalModels.first(where: { $0.id == modelId })?.displayName ?? modelId
                    logMessage("Selected Local Whisper model '\(modelName)' is not downloaded. Opening Dashboard > Speech Models (Local Whisper)...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    LocalWhisperEngine.shared.downloadModel(id: modelId)
                    FloatingHUDWindow.shared.setMode(.error(message: "Downloading '\(modelName)'... Check Dashboard"))
                    FloatingHUDWindow.shared.hide(after: 3.5)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 2, subTab: 0)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .groq:
                if config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: Groq API Key is missing for STT. Opening Dashboard > Speech Models (Cloud Speech)...")
                    HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Add Groq API Key in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 1)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        case .deepgram:
            if config.deepgramApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logMessage("Dictation blocked: Deepgram API Key is missing. Opening Dashboard > Speech Models (Cloud Speech)...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Add Deepgram API Key in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 1)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        case .openai:
            if config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logMessage("Dictation blocked: OpenAI API Key is missing for STT. Opening Dashboard > Speech Models (Cloud Speech)...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Add OpenAI API Key in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 1)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        case .cohere:
            if config.cohereApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logMessage("Dictation blocked: Cohere API Key is missing. Opening Dashboard > Speech Models (Cloud Speech)...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Add Cohere API Key in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 1)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        case .soniox:
            if config.sonioxApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logMessage("Dictation blocked: Soniox API Key is missing. Opening Dashboard > Speech Models (Cloud Speech)...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Add Soniox API Key in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 1)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        case .custom:
            if config.customApiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logMessage("Dictation blocked: Custom API URL is missing. Opening Dashboard > Speech Models (Local Server)...")
                HotkeyManager.shared.notifyRecordingEnded()
                MediaController.shared.unmuteNow()
                FloatingHUDWindow.shared.setMode(.error(message: "Configure Endpoint in Dashboard"))
                FloatingHUDWindow.shared.hide(after: 3.0)
                NSSound(named: "Basso")?.play()
                DashboardWindowController.shared.show(tab: 2, subTab: 2)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    }

        // 1. AI Polish LLM Provider Pre-flight Validation (Pro feature)
        if config.isLicenseActivated && config.isAIPolishEnabled {
            switch config.provider {
            case .cloudflare:
                break
            case .groq:
                if config.groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: Groq API Key is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add Groq Key for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .openai:
                if config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: OpenAI API Key is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add OpenAI Key for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .anthropic:
                if config.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: Anthropic API Key is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add Claude Key for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .gemini:
                if config.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: Google Gemini API Key is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add Gemini Key for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .openrouter:
                if config.openrouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: OpenRouter API Key is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add OpenRouter Key for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            case .custom:
                if config.customApiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logMessage("Dictation blocked: Custom API URL is missing for AI Polish. Opening Dashboard > AI Polish...")
                    HotkeyManager.shared.notifyRecordingEnded()
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: "Add Custom URL for AI Polish"))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    NSSound(named: "Basso")?.play()
                    DashboardWindowController.shared.show(tab: 3)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            }
        }

        // 2. Check network connectivity ONLY if using a cloud provider
        if config.sttProvider != .localWhisper && !NetworkMonitor.shared.checkConnection() {
            logMessage("Dictation blocked: Device is offline.")
            HotkeyManager.shared.notifyRecordingEnded()
            MediaController.shared.unmuteNow()
            FloatingHUDWindow.shared.setMode(.offline)
            FloatingHUDWindow.shared.hide(after: 2.5)
            NSSound(named: "Basso")?.play()
            return
        }

        // 2. Pause media if actively playing (before any sound effects play)
        MediaController.shared.muteNow()

        // 3. START RECORDING INSTANTLY (0ms latency, microphone immediately active!)
        do {
            try AudioRecorder.shared.startRecording()
            SoundEffectsService.shared.playStart()
            FloatingHUDWindow.shared.setMode(.listening)
            updateMenu()

            // 180s Max Recording Safety Timeout (Prevents runaway recording)
            maxRecordingTimer?.invalidate()
            maxRecordingTimer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.logMessage("Max recording duration reached (180s). Auto-stopping...")
                    self?.hotkeyDidFinish()
                }
            }
        } catch {
            HotkeyManager.shared.notifyRecordingEnded()
            MediaController.shared.unmuteNow()
            logMessage("Failed to start recording: \(error.localizedDescription)")
            FloatingHUDWindow.shared.setMode(.error(message: error.localizedDescription))
            FloatingHUDWindow.shared.hide(after: 2.5)
            return
        }

        // 4. Concurrently capture context in background
        // Heavy AppleScript (browser URL) and AX selection calls never delay the microphone!
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ctx = AppContextDetector.shared.getCurrentContext()
            DispatchQueue.main.async {
                self?.startContext = ctx
                if let selected = ctx.selectedText {
                    self?.logMessage("Context ready [EDIT MODE]: \(selected.count) chars selected")
                } else {
                    self?.logMessage("Context ready [DICTATION]: Target App = \(ctx.appName)")
                }
                if let browserURL = ctx.browserURL, !browserURL.isEmpty {
                    self?.logMessage("[Browser Context] Active Tab URL detected: \(browserURL)")
                }
            }
        }
    }

    public func hotkeyDidFinish() {
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = nil

        HotkeyManager.shared.notifyRecordingEnded()

        guard AudioRecorder.shared.isRecording else { return }

        logMessage("Hotkey released. Stopping recording...")
        guard let audioURL = AudioRecorder.shared.stopRecording() else {
            logMessage("No valid audio captured.")
            MediaController.shared.unmuteNow()
            FloatingHUDWindow.shared.hide(after: 0.2)
            startContext = nil
            updateMenu()
            return
        }

        let currentConfig = ConfigManager.shared.config
        if currentConfig.sttProvider != .localWhisper && !NetworkMonitor.shared.checkConnection() {
            logMessage("Cannot transcribe: Device is offline.")
            FloatingHUDWindow.shared.setMode(.offline)
            FloatingHUDWindow.shared.hide(after: 2.5)
            startContext = nil
            updateMenu()
            return
        }

        isBusy = true
        updateMenu()
        FloatingHUDWindow.shared.setMode(.polishing)

        // If selection was not captured at start (e.g. Fn/Option held down),
        // capture it now that modifier keys are fully released!
        if self.startContext?.selectedText == nil {
            if let sel = AppContextDetector.shared.captureSelectedText() {
                self.logMessage("Captured selection upon hotkey release: \(sel.count) chars: \"\(sel.prefix(50))...\"")
                self.startContext = AppContext(
                    appName: self.startContext?.appName ?? "Unknown",
                    bundleId: self.startContext?.bundleId,
                    category: self.startContext?.category ?? .general,
                    windowTitle: self.startContext?.windowTitle,
                    selectedText: sel,
                    browserURL: self.startContext?.browserURL,
                    runningApp: self.startContext?.runningApp
                )
            }
        }

        Task {
            // Revalidate active license with Dodo Payments on every dictation
            DodoPaymentsService.shared.recheckLicenseInBackground()

            do {
                // 1. Transcribe with Whisper or Deepgram (~200ms)
                let startTime = Date()
                let engineName = ConfigManager.shared.config.sttProvider.displayName
                let rawTranscript = try await AIService.shared.transcribeAudio(fileURL: audioURL)
                let whisperTime = Date().timeIntervalSince(startTime)
                self.logMessage("\(engineName) transcript (\(String(format: "%.2f", whisperTime))s): \"\(rawTranscript)\"")

                guard !rawTranscript.isEmpty else {
                    self.logMessage("No speech detected or silence prompt hallucination filtered. Ignored.")
                    await MainActor.run {
                        self.isBusy = false
                        self.startContext = nil
                        MediaController.shared.unmuteNow()
                        FloatingHUDWindow.shared.hide(after: 0.1)
                        self.updateMenu()
                    }
                    return
                }

                // 2. Check Voice Snippets (handles spacing variations e.g. "bolt scraper website" vs "boltscraper website")
                if let snippetMatch = self.matchVoiceSnippet(for: rawTranscript) {
                    self.logMessage("Voice snippet matched: '\(snippetMatch.trigger)' -> '\(snippetMatch.expansion)'")
                    let targetApp = self.startContext?.runningApp
                    await MainActor.run {
                        self.lastTranscript = snippetMatch.expansion
                        self.isBusy = false
                        self.startContext = nil

                        MediaController.shared.unmuteNow()
                        SoundEffectsService.shared.playSuccess()

                        PasteInjector.shared.inject(text: snippetMatch.expansion, targetApp: targetApp) { success in
                            DispatchQueue.main.async {
                                if success {
                                    FloatingHUDWindow.shared.hide()
                                } else {
                                    FloatingHUDWindow.shared.setMode(.accessibilityNeeded)
                                    FloatingHUDWindow.shared.hide(after: 3.0)
                                }
                                self.updateMenu()
                            }
                        }
                    }
                    return
                }

                // 3. Determine if Edit Mode or Dictation Mode
                let selected = self.startContext?.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasSelection = (selected != nil && !selected!.isEmpty)
                let isEditMode = hasSelection && ConfigManager.shared.config.isHighlightToEditEnabled

                if hasSelection && !ConfigManager.shared.config.isHighlightToEditEnabled {
                    self.logMessage("Highlight-to-Edit is toggled off -> Dictating and pasting text normally...")
                }

                if isEditMode {
                    if !ConfigManager.shared.config.hasConfiguredAIProvider {
                        self.logMessage("Highlight-to-Edit triggered without AI key/Ollama configured.")
                        await MainActor.run {
                            self.isBusy = false
                            self.startContext = nil
                            MediaController.shared.unmuteNow()
                            FloatingHUDWindow.shared.setMode(.error(message: "Highlight-to-Edit requires AI key or Local Ollama"))
                            FloatingHUDWindow.shared.hide(after: 3.0)
                            NSSound(named: "Basso")?.play()
                            DashboardWindowController.shared.show(tab: 3)
                            NSApp.activate(ignoringOtherApps: true)
                            self.updateMenu()
                        }
                        return
                    }
                }

                let systemPrompt: String
                let userPrompt: String

                if isEditMode, let sel = selected {
                    self.logMessage("Running in Edit Mode: Transforming selection according to spoken instruction...")
                    systemPrompt = AppContextDetector.shared.buildEditModePrompt(windowTitle: self.startContext?.windowTitle)
                    userPrompt = AppContextDetector.shared.buildEditModeUserPayload(instruction: rawTranscript, selectedText: sel)
                } else {
                    let currentContext = self.startContext ?? AppContextDetector.shared.getCurrentContext()
                    systemPrompt = AppContextDetector.shared.buildSystemPrompt(for: currentContext)
                    userPrompt = AppContextDetector.shared.wrapCleanupTranscript(rawTranscript)
                }

                // 4. Polish and format with LLM (~50ms)
                let llmStart = Date()
                var rawPolished: String = rawTranscript
                do {
                    rawPolished = try await AIService.shared.polishText(rawTranscript: rawTranscript, systemPrompt: systemPrompt, userPrompt: userPrompt)
                    let llmTime = Date().timeIntervalSince(llmStart)
                    self.logMessage("Output text (\(String(format: "%.2f", llmTime))s): \"\(rawPolished)\"")
                } catch {
                    self.logMessage("⚠️ LLM polishing failed (\(error.localizedDescription)). Seamlessly falling back to speech-to-text transcript.")
                    if isEditMode {
                        // In Edit Mode, transforming selection requires LLM, rethrow so error HUD informs user
                        throw error
                    }
                    // In standard dictation, never lose the user's spoken words! Paste raw transcript directly.
                    rawPolished = AIService.applyCustomVocabulary(rawTranscript, vocabulary: ConfigManager.shared.config.customVocabulary)
                }

                // Safety fallback: if LLM returned an empty string or whitespace on spoken input, never drop the user's words!
                if rawPolished.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.logMessage("⚠️ LLM returned empty string for speech. Falling back to speech-to-text transcript.")
                    rawPolished = AIService.applyCustomVocabulary(rawTranscript, vocabulary: ConfigManager.shared.config.customVocabulary)
                }

                // Secondary snippet check on polished text (in case Whisper formatting differed)
                let polished: String
                if let polishedSnippetMatch = self.matchVoiceSnippet(for: rawPolished) {
                    self.logMessage("Polished output matched voice snippet: '\(polishedSnippetMatch.trigger)' -> '\(polishedSnippetMatch.expansion)'")
                    polished = polishedSnippetMatch.expansion
                } else {
                    polished = rawPolished
                }

                let targetApp = self.startContext?.runningApp
                let appTitle = targetApp?.localizedName ?? "Active App"
                let currentModel = ConfigManager.shared.config.sttProvider == .localWhisper 
                    ? "Whisper \(ConfigManager.shared.config.localWhisperModel.capitalized)" 
                    : ConfigManager.shared.config.sttProvider.displayName
                let wasPolished = ConfigManager.shared.config.canUseAIPolish && ConfigManager.shared.config.isAIPolishEnabled

                HistoryManager.shared.addRecord(
                    text: polished,
                    duration: whisperTime,
                    model: currentModel,
                    wasPolished: wasPolished,
                    appName: appTitle
                )

                await MainActor.run {
                    self.lastTranscript = polished
                    self.isBusy = false
                    self.startContext = nil

                    MediaController.shared.unmuteNow()
                    SoundEffectsService.shared.playSuccess()

                    // 4. Inject paste into active window
                    PasteInjector.shared.inject(text: polished, targetApp: targetApp) { success in
                        DispatchQueue.main.async {
                            if success {
                                FloatingHUDWindow.shared.hide()
                            } else {
                                FloatingHUDWindow.shared.setMode(.accessibilityNeeded)
                                FloatingHUDWindow.shared.hide(after: 3.0)
                            }
                            self.updateMenu()
                        }
                    }
                }
            } catch {
                self.logMessage("Error processing audio: \(error.localizedDescription)")
                let errDesc = error.localizedDescription
                await MainActor.run {
                    self.isBusy = false
                    MediaController.shared.unmuteNow()
                    FloatingHUDWindow.shared.setMode(.error(message: errDesc))
                    FloatingHUDWindow.shared.hide(after: 3.0)
                    self.updateMenu()
                }
            }
        }
    }

    // MARK: - Double-Tap Shortcut (Paste Again)
    public func hotkeyDidDoubleTap() {
        logMessage("Double-tap shortcut detected -> Pasting last dictation...")
        AudioRecorder.shared.cancelRecording()
        MediaController.shared.unmuteNow()

        guard let textToPaste = PasteInjector.shared.lastPastedText ?? (!lastTranscript.isEmpty ? lastTranscript : nil),
              !textToPaste.isEmpty else {
            logMessage("No previous dictation available to paste again.")
            FloatingHUDWindow.shared.setMode(.error(message: "No dictation to paste"))
            FloatingHUDWindow.shared.hide(after: 1.5)
            NSSound(named: "Basso")?.play()
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        SoundEffectsService.shared.playSuccess()
        FloatingHUDWindow.shared.hide()

        PasteInjector.shared.pasteAgain(targetApp: frontmostApp) { [weak self] success in
            if !success {
                FloatingHUDWindow.shared.setMode(.accessibilityNeeded)
                FloatingHUDWindow.shared.hide(after: 2.5)
            }
            self?.logMessage("Double-tap Paste Again completed (success: \(success))")
        }
    }

    public func hotkeyDidCancel() {
        logMessage("Dictation cancelled (hold threshold not met or accidental tap).")
        AudioRecorder.shared.cancelRecording()
        MediaController.shared.unmuteNow()
        FloatingHUDWindow.shared.hide()
    }

    // MARK: - AudioRecorderDelegate
    public func audioRecorderDidUpdateLevel(_ level: Float) {
        if AudioRecorder.shared.isRecording {
            FloatingHUDWindow.shared.updateAudioLevel(level)
        }
    }

    // MARK: - Smart Snippet & Voice Macro Matching
    private func matchVoiceSnippet(for transcript: String) -> (trigger: String, expansion: String)? {
        let config = ConfigManager.shared.config
        var snippets = config.snippets
        if config.canUseSpokenShortcuts {
            for (trig, exp) in config.voiceMacros {
                snippets[trig] = exp
            }
        }
        guard !snippets.isEmpty else { return nil }

        let cleanInput = transcript.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        guard !cleanInput.isEmpty else { return nil }

        // 1. Direct match (e.g. "my meeting link")
        for (trigger, expansion) in snippets {
            let cleanTrigger = trigger.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            if cleanInput == cleanTrigger {
                return (trigger, expansion)
            }
        }

        // 2. Normalized alphanumerics match: strips out spaces, hyphens, and punctuation.
        // Solves "bolt scraper website" matching "boltscraper website" -> "boltscraperwebsite"
        let normInput = cleanInput.filter { $0.isLetter || $0.isNumber }
        guard !normInput.isEmpty else { return nil }

        for (trigger, expansion) in snippets {
            let normTrigger = trigger.lowercased().filter { $0.isLetter || $0.isNumber }
            if !normTrigger.isEmpty && normInput == normTrigger {
                return (trigger, expansion)
            }
        }

        // 3. Spoken phrase containing the trigger (e.g. "open boltscraper website", "my meeting link please")
        var bestMatch: (trigger: String, expansion: String, len: Int)? = nil
        for (trigger, expansion) in snippets {
            let normTrigger = trigger.lowercased().filter { $0.isLetter || $0.isNumber }
            if normTrigger.count >= 5 && normInput.contains(normTrigger) {
                if bestMatch == nil || normTrigger.count > bestMatch!.len {
                    bestMatch = (trigger, expansion, normTrigger.count)
                }
            }
        }
        if let match = bestMatch {
            return (match.trigger, match.expansion)
        }

        return nil
    }

    // MARK: - Menu Bar Icon Helper
    private func loadMenuBarIcon() -> NSImage? {
        // Try loading from the app bundle's Resources folder
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/MenuBarIcon.png" },
            Bundle.main.path(forResource: "MenuBarIcon", ofType: "png")
        ].compactMap { $0 }

        for path in candidates {
            if let img = NSImage(contentsOfFile: path) {
                // Scale to standard menu bar icon size (18×18 pt)
                let size = NSSize(width: 18, height: 18)
                let scaled = NSImage(size: size)
                scaled.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: size),
                         from: NSRect(origin: .zero, size: img.size),
                         operation: .sourceOver, fraction: 1.0)
                scaled.unlockFocus()
                scaled.isTemplate = true // Adapts to dark/light menu bar automatically
                return scaled
            }
        }
        return nil
    }

    private func logMessage(_ msg: String) {
        let line = "[\(Date())] [Controller] \(msg)\n"
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

// MARK: - AppKit First-Mouse Click-Through Support
/// Custom NSHostingView that overrides acceptsFirstMouse(for:) to return true.
/// This ensures buttons in inactive windows/popovers trigger on the very first click
/// without requiring an extra initial click just to focus the window.
public class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

public class FirstMouseHostingController<Content: View>: NSHostingController<Content> {
    public override func loadView() {
        let hostingView = FirstMouseHostingView(rootView: rootView)
        self.view = hostingView
    }
}
