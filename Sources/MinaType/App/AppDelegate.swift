import Cocoa

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var licenseValidationTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure Dock icon visibility based on user setting
        let showDock = ConfigManager.shared.config.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)

        // Setup standard macOS Application and Edit menus
        setupStandardMenus()

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "MinaFlow_HasCompletedOnboarding")

        if hasCompletedOnboarding {
            // Returning user — wire up everything including the menu bar icon
            MinaMenuController.shared.setup()
            // When opened explicitly by user, show Settings so they have immediate visual confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                DashboardWindowController.shared.show(tab: 0)
            }
        } else {
            // First run — wire up hotkey/audio delegates but keep the menu bar icon hidden
            // until the user finishes onboarding (OnboardingView.finish() calls showMenuBarIcon)
            MinaMenuController.shared.setupCore()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                OnboardingWindowController.shared.show()
            }
        }

        // Setup local key monitor for instant Cmd+, and Cmd+Q handling
        setupGlobalAppShortcutMonitor()

        // Background license validation every 4 hours (catches revoked/refunded keys)
        scheduleLicenseValidationTimer()

        // Anonymous daily heartbeat ping for analytics (DAU/WAU)
        scheduleHeartbeatPing()

        print("MinaFlow is running! Press trigger key anywhere to voice-type.")
    }

    /// Called when the user relaunches or double-clicks the app while it is already running.
    /// If onboarding was dismissed without completing, we bring it back instead of doing nothing.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !UserDefaults.standard.bool(forKey: "MinaFlow_HasCompletedOnboarding") {
            OnboardingWindowController.shared.show()
            return true
        }
        DashboardWindowController.shared.show(tab: 0)
        return true
    }

    private func scheduleLicenseValidationTimer() {
        licenseValidationTimer?.invalidate()
        // Fire immediately on launch (after 30s delay so network is ready), then every 4h
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.performBackgroundLicenseValidation()
        }
        licenseValidationTimer = Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            self?.performBackgroundLicenseValidation()
        }
        RunLoop.main.add(licenseValidationTimer!, forMode: .common)
    }

    private func performBackgroundLicenseValidation() {
        let config = ConfigManager.shared.config
        guard config.isLicenseActivated, !config.licenseKey.isEmpty else { return }

        let key = config.licenseKey
        let instanceId = config.licenseInstanceId
        let lastCheckKey = "MinaFlow_LastLicenseValidation"

        Task {
            // Perform a raw validate call so we can distinguish a real "revoked"
            // response (HTTP 200 valid=false) from a mere network timeout.
            let (isValid, gotResponse) = await rawValidate(
                licenseKey: key,
                instanceId: instanceId.isEmpty ? nil : instanceId,
                env: DodoPaymentsService.shared.currentEnvironment
            )
            if !gotResponse { return } // Transient failure — don't stamp, retry next cycle
            await MainActor.run {
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
                if !isValid {
                    // Silently revoke — user will see the trial state on next open
                    ConfigManager.shared.deactivateLicenseLocally()
                    MinaMenuController.shared.updateMenu()
                    // Notify both SettingsView and MenuBarPopoverView
                    NotificationCenter.default.post(
                        name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil
                    )
                    print("[License] Key revoked/expired. Deactivated locally.")
                }
            }
        }
    }

    /// Thin validate wrapper that returns (isValid, gotResponse) so callers can
    /// distinguish network failure from a confirmed-invalid response.
    private func rawValidate(licenseKey: String, instanceId: String?, env: DodoEnvironment) async -> (Bool, Bool) {
        guard let url = URL(string: "/licenses/validate", relativeTo: env.baseURL) else { return (false, false) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        var body: [String: Any] = ["license_key": licenseKey]
        if let inst = instanceId, !inst.isEmpty { body["license_key_instance_id"] = inst }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return (false, true) }
            struct V: Decodable { let valid: Bool? }
            let val = try JSONDecoder().decode(V.self, from: data)
            return (val.valid ?? false, true)
        } catch {
            return (false, false)
        }
    }

    private func scheduleHeartbeatPing() {
        let key = "MinaFlow_AnonymousDeviceID"
        let deviceId: String
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            deviceId = existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            deviceId = newId
        }

        // Ping after 5 seconds on launch, then every 24 hours
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            self.sendPing(deviceId: deviceId)
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            self?.sendPing(deviceId: deviceId)
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func sendPing(deviceId: String) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        guard let escapedOs = os.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://krishra.com/api/minaflow/ping?id=\(deviceId)&v=\(version)&os=\(escapedOs)") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request).resume()
    }

    private func setupStandardMenus() {
        let mainMenu = NSMenu()

        // 1. Application Menu (MinaFlow)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "MinaFlow")

        let settingsItem = NSMenuItem(title: "Open Dashboard...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit MinaFlow", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. Edit Menu (Cut, Copy, Paste, Select All)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupGlobalAppShortcutMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command {
                if event.charactersIgnoringModifiers == "," {
                    MinaMenuController.shared.closePopover()
                    DashboardWindowController.shared.show(tab: 0)
                    return nil
                } else if event.charactersIgnoringModifiers == "q" {
                    NSApp.terminate(nil)
                    return nil
                }
            }
            return event
        }
    }

    @objc private func openSettingsFromMenu() {
        MinaMenuController.shared.closePopover()
        DashboardWindowController.shared.show(tab: 0)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        MediaController.shared.emergencyUnmute()
        HotkeyManager.shared.stopMonitoring()
    }
}
