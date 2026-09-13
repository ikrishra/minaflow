import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

public class PasteInjector {
    public static let shared = PasteInjector()

    private init() {}

    public func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    public func promptAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAccessibilitySettings() {
        promptAccessibilityPermission()
    }

    public private(set) var lastPastedText: String?

    public func pasteAgain(targetApp: NSRunningApplication? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let text = lastPastedText, !text.isEmpty else {
            log("No previous text to paste again.")
            completion?(false)
            return
        }
        log("Paste Again triggered: \"\(text.prefix(40))...\"")
        inject(text: text, targetApp: targetApp, completion: completion)
    }

    public func inject(text: String, targetApp: NSRunningApplication? = nil, completion: ((Bool) -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?(true)
            return
        }

        self.lastPastedText = text

        // Smart Spacing Optimization:
        // Strip leading/trailing whitespace, then append a single trailing space
        // so consecutive voice dictations seamlessly flow without colliding!
        var formatted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty {
            formatted.append(" ")
        }

        // 1. Backup existing pasteboard contents so user never loses copied items
        let pasteboard = NSPasteboard.general
        let savedItems = backupPasteboard(pasteboard)

        // 2. Put dictated text on pasteboard
        pasteboard.clearContents()
        pasteboard.setString(formatted, forType: .string)
        let changeCountAtPaste = pasteboard.changeCount
        log("Text placed on clipboard for paste: \"\(formatted.prefix(40))...\"")

        let isTrusted = isAccessibilityGranted()
        if !isTrusted {
            log("Notice: AXIsProcessTrusted is false, prompting accessibility.")
        }

        // 3. Target Application Activation & Paste Delivery
        // Re-assert focus to the app that was active when dictation started
        if let target = targetApp, !target.isActive {
            target.activate(options: [.activateIgnoringOtherApps])
        }

        // Small 60ms delay ensures window focus transition and modifier keys are completely settled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.simulateCmdV(targetApp: targetApp)
            completion?(true)

            // 4. Safely restore original clipboard after 2.0s
            // Only restore if the user hasn't copied something new in the meantime!
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if pasteboard.changeCount == changeCountAtPaste {
                    self.restorePasteboard(pasteboard, savedItems: savedItems)
                    self.log("Original clipboard restored successfully.")
                } else {
                    self.log("User copied something new during paste; keeping new clipboard.")
                }
            }
        }
    }

    // MARK: - Clipboard Preservation
    private struct SavedPasteboardItem {
        let typesAndData: [(NSPasteboard.PasteboardType, Data)]
    }

    private func backupPasteboard(_ pasteboard: NSPasteboard) -> [SavedPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        var result: [SavedPasteboardItem] = []
        for item in items {
            var pairs: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    pairs.append((type, data))
                }
            }
            if !pairs.isEmpty {
                result.append(SavedPasteboardItem(typesAndData: pairs))
            }
        }
        return result
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, savedItems: [SavedPasteboardItem]) {
        guard !savedItems.isEmpty else { return }
        pasteboard.clearContents()
        for saved in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in saved.typesAndData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }

    private func simulateCmdV(targetApp: NSRunningApplication? = nil) {
        let vKeyCode: CGKeyCode = 0x09 // Virtual key code for 'V'
        
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            fallbackAppleScriptPaste()
            return
        }

        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand

        // If target app is known, post directly to its process identifier
        if let target = targetApp, target.processIdentifier > 0 {
            keyDown.postToPid(target.processIdentifier)
            usleep(25_000) // 25ms realistic key hold duration for Electron/WebKit event loops
            keyUp.postToPid(target.processIdentifier)
        } else {
            // Post to both session and HID event taps for universal application capture
            keyDown.post(tap: CGEventTapLocation.cgSessionEventTap)
            keyDown.post(tap: CGEventTapLocation.cghidEventTap)
            usleep(25_000) // 25ms realistic key hold duration
            keyUp.post(tap: CGEventTapLocation.cgSessionEventTap)
            keyUp.post(tap: CGEventTapLocation.cghidEventTap)
        }

        log("Simulated Cmd+V event posted.")
    }

    private func fallbackAppleScriptPaste() {
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                log("AppleScript paste fallback error: \(error)")
            } else {
                log("AppleScript paste fallback executed successfully.")
            }
        }
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] [Paste] \(msg)\n"
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
