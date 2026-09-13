import Foundation
import AppKit
import Carbon

public protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyDidStart()
    func hotkeyDidFinish()
    func hotkeyDidDoubleTap()
    func hotkeyDidCancel()
}

public class HotkeyManager {
    public static let shared = HotkeyManager()

    public weak var delegate: HotkeyManagerDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workspaceObserver: Any?

    private var isHoldingFn = false
    private var isHoldingOptionSpace = false
    private var lastToggleTime: Date = .distantPast

    // Hybrid hands-free toggle tracking
    private var isHandsFree = false

    // Double-tap detection tracking
    private var lastTapReleaseTime: Date = .distantPast
    private var tapDownTime: Date = .distantPast
    private var isDoubleTapHandling = false
    private var pendingHoldTimer: Timer?

    /// Authoritative state tracking so toggle mode never relies on asynchronous recorder polling
    public private(set) var isRecordingActive = false

    // Carbon HotKey references for rock-solid global Option + Space
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonEventHandler: EventHandlerRef?

    private var isObservingHotkeyChange = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MinaFlowHotkeyChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[HotkeyManager] Hotkey selection changed. Rebinding dynamically...")
            self?.startMonitoring()
        }
    }

    public func startMonitoring() {
        stopMonitoring()

        let selected = ConfigManager.shared.config.hotkey

        // 1. Setup Carbon HotKey for Option + Space (if selected or if Accessibility is not granted)
        if selected == "option+space" || !AXIsProcessTrusted() {
            setupCarbonHotKey()
        }

        // 2. Setup CGEventTap for low-level key intercept & consumption
        setupEventTap()

        // 3. Setup workspace observer to suppress CharacterPaletteIM if Fn is active
        if selected == "fn" {
            setupPaletteDismissalObserver()
        }

        print("[HotkeyManager] Monitoring active for key: \(selected)")
    }

    public func stopMonitoring() {
        // Remove Carbon HotKey
        if let ref = carbonHotKeyRef {
            UnregisterEventHotKey(ref)
            carbonHotKeyRef = nil
        }
        if let handler = carbonEventHandler {
            RemoveEventHandler(handler)
            carbonEventHandler = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil

        if let wObserver = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wObserver)
            workspaceObserver = nil
        }

        pendingHoldTimer?.invalidate()
        pendingHoldTimer = nil
        isHoldingFn = false
        isHoldingOptionSpace = false
        isRecordingActive = false
        isHandsFree = false
        isDoubleTapHandling = false
        lastTapReleaseTime = .distantPast
    }

    /// Called by MinaMenuController when dictation finishes, cancels, or encounters an error
    public func notifyRecordingEnded() {
        pendingHoldTimer?.invalidate()
        pendingHoldTimer = nil
        isRecordingActive = false
        isHandsFree = false
        isHoldingFn = false
        isHoldingOptionSpace = false
        isDoubleTapHandling = false
    }

    /// Called when dictation is triggered from UI buttons (e.g. Menu Bar popover or HUD)
    public func notifyUIToggledRecording() {
        isRecordingActive = true
        isHandsFree = true
    }

    // MARK: - CharacterPaletteIM Auto-Dismissal
    private func setupPaletteDismissalObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.apple.CharacterPaletteIM" {
                if self.isHoldingFn || self.isRecordingActive {
                    app.hide()
                    app.forceTerminate()
                }
            }
        }
    }

    public func dismissCharacterPalette() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.CharacterPaletteIM") {
            app.hide()
            app.forceTerminate()
        }
        // Delayed check in case WindowServer spawns it asynchronously
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.CharacterPaletteIM") {
                app.hide()
                app.forceTerminate()
            }
        }
    }

    // MARK: - Carbon HotKey for Option + Space
    private func setupCarbonHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D494E41) // 'MINA'
        hotKeyID.id = UInt32(1)

        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(optionKey)

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
        ]

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData, let theEvent = theEvent else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var eventHotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &eventHotKeyID
                )

                guard status == noErr, eventHotKeyID.id == 1 else {
                    return CallNextEventHandler(nextHandler, theEvent)
                }

                let kind = GetEventKind(theEvent)
                if kind == OSType(kEventHotKeyPressed) {
                    manager.handleOptionSpaceKeyDown()
                } else if kind == OSType(kEventHotKeyReleased) {
                    manager.handleOptionSpaceKeyUp()
                }

                return noErr
            },
            2,
            &eventTypes,
            selfPtr,
            &carbonEventHandler
        )

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &carbonHotKeyRef
        )

        if installStatus == noErr && regStatus == noErr {
            print("[HotkeyManager] Registered global Carbon HotKey for Option + Space")
        } else {
            print("[HotkeyManager] Carbon HotKey registration code: \(regStatus)")
        }
    }

    // MARK: - CGEventTap for Fn (Globe) Key & Fallback
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            print("[HotkeyManager] CGEventTap creation failed. Relying on Carbon and NSEvent.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recover tap if macOS disables it due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[HotkeyManager] CGEventTap re-enabled after timeout.")
            }
            return nil
        }

        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let selected = ConfigManager.shared.config.hotkey

        // 1. Right Option (keyCode 61) - Wispr Flow style single-key shortcut
        if selected == "rightOption" && keyCode == 61 && type == .flagsChanged {
            let isDown = flags.contains(.maskAlternate)
            handleModifierTransition(isPressed: isDown, keyName: "Right Option")
            return nil
        }

        // 2. Fn (Globe) key (keyCode 63)
        if selected == "fn" && keyCode == 63 && type == .flagsChanged {
            let isDown = flags.contains(.maskSecondaryFn)
            handleModifierTransition(isPressed: isDown, keyName: "Fn (Globe)")
            dismissCharacterPalette()
            return nil
        }

        // 3. Right Command (keyCode 54)
        if selected == "rightCommand" && keyCode == 54 && type == .flagsChanged {
            let isDown = flags.contains(.maskCommand)
            handleModifierTransition(isPressed: isDown, keyName: "Right Command")
            return nil
        }

        // 4. Option + Space (keyCode 49 with Option flag)
        if selected == "option+space" {
            let isOption = flags.contains(.maskAlternate)
            let isSpace = (keyCode == 49)

            if isSpace && isOption {
                if type == .keyDown {
                    handleOptionSpaceKeyDown()
                    return nil // Consume event so space is never typed
                }
            }

            if type == .keyUp && isSpace {
                handleOptionSpaceKeyUp()
                if isHoldingOptionSpace {
                    return nil
                }
            }

            if type == .flagsChanged && !isOption {
                handleOptionSpaceKeyUp()
            }
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Generic Modifier Action Handler (Right Option, Fn, Right Command)
    private func handleModifierTransition(isPressed: Bool, keyName: String) {
        let isConfigToggle = ConfigManager.shared.config.mode == "toggle"
        let now = Date()

        if isPressed {
            tapDownTime = now
            let timeSinceLastRelease = now.timeIntervalSince(lastTapReleaseTime)

            // Double-tap detection: 2nd tap within 350ms of releasing the 1st tap
            if timeSinceLastRelease <= 0.35 {
                print("[HotkeyManager] \(keyName) DOUBLE-TAP detected! (interval: \(String(format: "%.3f", timeSinceLastRelease))s)")
                isDoubleTapHandling = true
                lastTapReleaseTime = .distantPast
                pendingHoldTimer?.invalidate()
                pendingHoldTimer = nil

                if isRecordingActive {
                    isRecordingActive = false
                    isHandsFree = false
                    triggerFinish()
                }

                triggerDoubleTap()
                return
            }

            isDoubleTapHandling = false

            // If we are currently hands-free recording, this tap stops dictation and pastes
            if isRecordingActive && (isHandsFree || isConfigToggle) {
                print("[HotkeyManager] \(keyName) tap while hands-free recording -> STOPPING dictation")
                isRecordingActive = false
                isHandsFree = false
                lastTapReleaseTime = .distantPast
                triggerFinish()
                return
            }

            if !isRecordingActive {
                if isConfigToggle {
                    isRecordingActive = true
                    isHandsFree = true
                    lastToggleTime = now
                    print("[HotkeyManager] \(keyName) pressed in Toggle mode -> STARTING dictation")
                    triggerStart()
                } else {
                    // Push-to-Talk (Hold to Speak) mode:
                    // Require minimum hold threshold (200ms) so simple taps never start listening!
                    pendingHoldTimer?.invalidate()
                    pendingHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        if !self.isRecordingActive {
                            self.isRecordingActive = true
                            self.isHandsFree = false
                            self.lastToggleTime = Date()
                            print("[HotkeyManager] \(keyName) held past threshold (200ms) -> STARTING dictation")
                            self.triggerStart()
                        }
                    }
                }
            }
        } else {
            // Key released
            if isDoubleTapHandling {
                isDoubleTapHandling = false
                lastTapReleaseTime = .distantPast
                return
            }

            let tapDuration = now.timeIntervalSince(tapDownTime)
            if tapDuration < 0.35 {
                lastTapReleaseTime = now
            } else {
                lastTapReleaseTime = .distantPast
            }

            if isConfigToggle {
                isHandsFree = true
                return
            }

            // In Push-to-Talk (Hold to Speak) mode:
            // 1. If released before hold threshold timer fired: ignore simple press completely
            if let timer = pendingHoldTimer, timer.isValid {
                timer.invalidate()
                pendingHoldTimer = nil
                print("[HotkeyManager] \(keyName) released before hold threshold (\(String(format: "%.3f", tapDuration))s). Ignored simple press.")
                return
            }
            pendingHoldTimer = nil

            // 2. If recording was started:
            if isRecordingActive {
                isRecordingActive = false
                isHandsFree = false
                if tapDuration < 0.35 {
                    print("[HotkeyManager] \(keyName) held for only \(String(format: "%.3f", tapDuration))s -> Cancelling accidental start")
                    triggerCancel()
                } else {
                    print("[HotkeyManager] \(keyName) released in Push-To-Talk mode -> STOPPING dictation")
                    triggerFinish()
                }
            }
        }
    }

    // MARK: - Option + Space Action Handlers
    public func handleOptionSpaceKeyDown() {
        let isConfigToggle = ConfigManager.shared.config.mode == "toggle"
        let now = Date()
        tapDownTime = now
        let timeSinceLastRelease = now.timeIntervalSince(lastTapReleaseTime)

        if timeSinceLastRelease <= 0.35 {
            print("[HotkeyManager] Option+Space DOUBLE-TAP detected! (interval: \(String(format: "%.3f", timeSinceLastRelease))s)")
            isDoubleTapHandling = true
            lastTapReleaseTime = .distantPast
            pendingHoldTimer?.invalidate()
            pendingHoldTimer = nil

            if isRecordingActive {
                isRecordingActive = false
                isHandsFree = false
                triggerFinish()
            }
            triggerDoubleTap()
            return
        }

        isDoubleTapHandling = false

        if isRecordingActive && (isHandsFree || isConfigToggle) {
            print("[HotkeyManager] Option+Space tap while hands-free recording -> STOPPING dictation")
            isRecordingActive = false
            isHandsFree = false
            isHoldingOptionSpace = false
            lastTapReleaseTime = .distantPast
            triggerFinish()
            return
        }

        if !isHoldingOptionSpace {
            isHoldingOptionSpace = true
            if !isRecordingActive {
                if isConfigToggle {
                    isRecordingActive = true
                    isHandsFree = true
                    lastToggleTime = now
                    print("[HotkeyManager] Option+Space pressed in Toggle mode -> STARTING dictation")
                    triggerStart()
                } else {
                    // Push-to-Talk (Hold to Speak) mode:
                    pendingHoldTimer?.invalidate()
                    pendingHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        if !self.isRecordingActive {
                            self.isRecordingActive = true
                            self.isHandsFree = false
                            self.lastToggleTime = Date()
                            print("[HotkeyManager] Option+Space held past threshold (200ms) -> STARTING dictation")
                            self.triggerStart()
                        }
                    }
                }
            }
        }
    }

    public func handleOptionSpaceKeyUp() {
        let now = Date()
        isHoldingOptionSpace = false

        if isDoubleTapHandling {
            isDoubleTapHandling = false
            lastTapReleaseTime = .distantPast
            return
        }

        let tapDuration = now.timeIntervalSince(tapDownTime)
        if tapDuration < 0.35 {
            lastTapReleaseTime = now
        } else {
            lastTapReleaseTime = .distantPast
        }

        let isConfigToggle = ConfigManager.shared.config.mode == "toggle"
        if isConfigToggle {
            isHandsFree = true
            return
        }

        // In Push-to-Talk (Hold to Speak) mode:
        if let timer = pendingHoldTimer, timer.isValid {
            timer.invalidate()
            pendingHoldTimer = nil
            print("[HotkeyManager] Option+Space released before hold threshold (\(String(format: "%.3f", tapDuration))s). Ignored simple press.")
            return
        }
        pendingHoldTimer = nil

        if isRecordingActive {
            isRecordingActive = false
            isHandsFree = false
            if tapDuration < 0.35 {
                print("[HotkeyManager] Option+Space held for only \(String(format: "%.3f", tapDuration))s -> Cancelling accidental start")
                triggerCancel()
            } else {
                print("[HotkeyManager] Option+Space released in Push-To-Talk mode -> STOPPING dictation")
                triggerFinish()
            }
        }
    }

    private func triggerStart() {
        DispatchQueue.main.async {
            self.delegate?.hotkeyDidStart()
        }
    }

    private func triggerFinish() {
        DispatchQueue.main.async {
            self.delegate?.hotkeyDidFinish()
        }
    }

    private func triggerCancel() {
        DispatchQueue.main.async {
            self.delegate?.hotkeyDidCancel()
        }
    }

    private func triggerDoubleTap() {
        DispatchQueue.main.async {
            self.delegate?.hotkeyDidDoubleTap()
        }
    }
}
