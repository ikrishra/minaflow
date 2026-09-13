import AppKit
import Foundation

public class BrowserURLService {
    public static let shared = BrowserURLService()

    private init() {}

    /// Checks if a bundle identifier corresponds to a supported browser
    public func isBrowser(bundleId: String?) -> Bool {
        guard let bundleId = bundleId?.lowercased() else { return false }
        return bundleId.contains("safari") ||
               bundleId.contains("chrome") ||
               bundleId.contains("company.thebrowser") ||
               bundleId.contains("brave") ||
               bundleId.contains("edge") ||
               bundleId.contains("opera") ||
               bundleId.contains("orion") ||
               bundleId.contains("arc") ||
               bundleId.contains("comet")
    }

    /// Fetches the active tab URL for the given frontmost browser app
    public func getActiveURL(bundleId: String?) -> String? {
        guard ConfigManager.shared.config.isBrowserURLExtractionEnabled else { return nil }
        guard let bundleId = bundleId?.lowercased() else { return nil }

        let scriptSource: String?

        if bundleId.contains("safari") {
            scriptSource = "tell application \"Safari\" to if (count of windows) > 0 then return URL of current tab of front window"
        } else if bundleId.contains("chrome") {
            scriptSource = "tell application \"Google Chrome\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else if bundleId.contains("company.thebrowser") || bundleId.contains("arc") {
            scriptSource = "tell application \"Arc\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else if bundleId.contains("brave") {
            scriptSource = "tell application \"Brave Browser\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else if bundleId.contains("edge") {
            scriptSource = "tell application \"Microsoft Edge\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else if bundleId.contains("opera") {
            scriptSource = "tell application \"Opera\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else if bundleId.contains("orion") {
            scriptSource = "tell application \"Orion\" to if (count of windows) > 0 then return URL of current tab of front window"
        } else if bundleId.contains("comet") {
            scriptSource = "tell application \"Comet\" to if (count of windows) > 0 then return URL of active tab of front window"
        } else {
            scriptSource = nil
        }

        guard let script = scriptSource else { return nil }

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let output = appleScript?.executeAndReturnError(&error)

        if let urlString = output?.stringValue, !urlString.isEmpty {
            return urlString
        }
        return nil
    }
}
