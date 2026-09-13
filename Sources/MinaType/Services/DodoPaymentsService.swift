import Foundation
import AppKit

public enum DodoEnvironment: String, Codable, CaseIterable {
    case test = "test"
    case live = "live"

    public var baseURL: URL {
        switch self {
        case .test:
            return URL(string: "https://test.dodopayments.com")!
        case .live:
            return URL(string: "https://live.dodopayments.com")!
        }
    }

    public var displayName: String {
        switch self {
        case .test: return "Test Mode (Sandbox)"
        case .live: return "Live Production"
        }
    }
}

public struct DodoActivationResponse: Decodable {
    public let id: String?
    public let licenseKeyId: String?
    public let status: String?
    public let activationsUsed: Int?
    public let activationsLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case licenseKeyId = "license_key_id"
        case status
        case activationsUsed = "activations_used"
        case activationsLimit = "activations_limit"
    }
}

public struct DodoErrorResponse: Decodable {
    public let code: String?
    public let message: String?
}

public struct DodoValidationResponse: Decodable {
    public let valid: Bool?
}

public class DodoPaymentsService {
    public static let shared = DodoPaymentsService()

    private init() {}

    public var currentEnvironment: DodoEnvironment {
        let envStr = ConfigManager.shared.config.dodoEnvironment
        return DodoEnvironment(rawValue: envStr) ?? .live
    }

    /// Public endpoint: POST /licenses/activate
    /// Activates a license key for this device instance. Automatically checks environments.
    public func activate(licenseKey: String, environment: DodoEnvironment? = nil) async -> (success: Bool, message: String, instanceId: String?) {
        let cleanKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return (false, "Please enter your license key.", nil)
        }

        let primaryEnv = environment ?? currentEnvironment
        let primaryResult = await performActivate(cleanKey: cleanKey, env: primaryEnv)
        if primaryResult.success {
            ConfigManager.shared.updateDodoEnvironment(primaryEnv.rawValue)
            return primaryResult
        }

        // If key not found or invalid in primary, attempt the alternate environment
        if primaryResult.message.lowercased().contains("not found") || primaryResult.message.lowercased().contains("invalid") {
            let altEnv: DodoEnvironment = (primaryEnv == .live) ? .test : .live
            let altResult = await performActivate(cleanKey: cleanKey, env: altEnv)
            if altResult.success {
                ConfigManager.shared.updateDodoEnvironment(altEnv.rawValue)
                return altResult
            }
        }

        return primaryResult
    }

    private func performActivate(cleanKey: String, env: DodoEnvironment) async -> (success: Bool, message: String, instanceId: String?) {
        guard let url = URL(string: "/licenses/activate", relativeTo: env.baseURL) else {
            return (false, "Invalid endpoint.", nil)
        }

        let deviceName = Host.current().localizedName ?? "Mac"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "license_key": cleanKey,
            "name": deviceName
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Network connection error.", nil)
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let activation = try JSONDecoder().decode(DodoActivationResponse.self, from: data)
                let instanceId = activation.id ?? ""
                return (true, "License activated successfully!", instanceId)
            } else {
                if let err = try? JSONDecoder().decode(DodoErrorResponse.self, from: data) {
                    let code = err.code ?? ""
                    let detail = err.message ?? ""
                    if code.contains("LIMIT") || detail.lowercased().contains("limit") {
                        return (false, "Activation limit reached (1 device). Please deactivate your previous Mac first to use this key here.", nil)
                    } else if code == "NOT_FOUND" || detail.lowercased().contains("not found") || code.contains("INVALID") {
                        return (false, "Invalid license key. Please check your key and try again.", nil)
                    } else if code == "EXPIRED" || detail.lowercased().contains("expired") {
                        return (false, "This license key has expired.", nil)
                    } else if !detail.isEmpty && !detail.contains("{") && !detail.contains("_") {
                        return (false, detail, nil)
                    } else {
                        return (false, "Invalid license key. Please check your key and try again.", nil)
                    }
                } else {
                    return (false, "Invalid license key. Please check your key and try again.", nil)
                }
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)", nil)
        }
    }

    /// Public endpoint: POST /licenses/validate
    /// Validates if the license key is still valid and not revoked or expired.
    /// Returns:
    /// - true: Confirmed active and valid by Dodo server.
    /// - false: Explicitly revoked, expired, or invalid.
    /// - nil: Network error or offline — never revoke a locally activated user when offline.
    public func validate(licenseKey: String, instanceId: String? = nil, environment: DodoEnvironment? = nil) async -> Bool? {
        let env = environment ?? currentEnvironment
        guard let url = URL(string: "/licenses/validate", relativeTo: env.baseURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        var body: [String: Any] = ["license_key": licenseKey]
        if let inst = instanceId, !inst.isEmpty {
            body["license_key_instance_id"] = inst
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode == 200 {
                let val = try JSONDecoder().decode(DodoValidationResponse.self, from: data)
                return val.valid ?? false
            } else if http.statusCode == 404 || http.statusCode == 422 {
                return false
            } else {
                return nil // 5xx server issues: preserve local status
            }
        } catch {
            // Network failure / Offline: do NOT revoke locally
            return nil
        }
    }

    /// Revalidates the active license with Dodo Payments in the background.
    /// Runs on dictation and when menu bar / dashboard opens.
    /// If the key has been refunded, disputed, or revoked, downgrades locally.
    public func recheckLicenseInBackground() {
        let cfg = ConfigManager.shared.config
        guard cfg.isLicenseActivated, !cfg.licenseKey.isEmpty else { return }
        let key = cfg.licenseKey
        let instanceId = cfg.licenseInstanceId

        Task {
            let env = currentEnvironment
            guard let url = URL(string: "/licenses/validate", relativeTo: env.baseURL) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 8

            var body: [String: Any] = ["license_key": key]
            if !instanceId.isEmpty {
                body["license_key_instance_id"] = instanceId
            }

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        if let val = try? JSONDecoder().decode(DodoValidationResponse.self, from: data) {
                            if val.valid == false {
                                await MainActor.run {
                                    ConfigManager.shared.deactivateLicenseLocally()
                                    MinaMenuController.shared.updateMenu()
                                    NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
                                    print("[DodoLicense] Key revoked or expired on Dodo Payments.")
                                }
                            }
                        }
                    } else if http.statusCode == 404 || http.statusCode == 422 {
                        await MainActor.run {
                            ConfigManager.shared.deactivateLicenseLocally()
                            MinaMenuController.shared.updateMenu()
                            NotificationCenter.default.post(name: NSNotification.Name("MinaFlowTrialUpdated"), object: nil)
                            print("[DodoLicense] Key not found or invalid on Dodo Payments.")
                        }
                    }
                }
            } catch {
                // Transient network failure — do not revoke offline user
            }
        }
    }

    /// Public endpoint: POST /licenses/deactivate
    /// Releases this Mac's seat so the customer can use the key on another device.
    public func deactivate(licenseKey: String, instanceId: String, environment: DodoEnvironment? = nil) async -> (success: Bool, message: String) {
        let env = environment ?? currentEnvironment
        guard let url = URL(string: "/licenses/deactivate", relativeTo: env.baseURL) else {
            return (false, "Invalid endpoint URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "license_key": licenseKey,
            "license_key_instance_id": instanceId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response from server.")
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                return (true, "License successfully deactivated from this Mac.")
            } else {
                if let err = try? JSONDecoder().decode(DodoErrorResponse.self, from: data) {
                    return (false, err.message ?? "Deactivation failed.")
                }
                return (false, "Deactivation failed (HTTP \(httpResponse.statusCode)).")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }
}
