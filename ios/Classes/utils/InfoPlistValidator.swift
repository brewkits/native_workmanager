import Foundation

/// Validates Info.plist configuration for BGTaskScheduler.
///
/// This utility helps developers ensure their Info.plist is correctly configured
/// for background task scheduling on iOS 13+.
@available(iOS 13.0, *)
class InfoPlistValidator {

    /// Required BGTaskScheduler identifiers.
    static let requiredIdentifiers = [
        "dev.brewkits.native_workmanager.task",
        "dev.brewkits.native_workmanager.refresh"
    ]

    /// Validates Info.plist configuration and returns any missing identifiers.
    ///
    /// - Returns: Array of missing identifiers, or empty array if all configured.
    static func validateConfiguration() -> [String] {
        guard let permittedIdentifiers = Bundle.main.object(
            forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers"
        ) as? [String] else {
            // No BGTaskSchedulerPermittedIdentifiers key found
            return requiredIdentifiers
        }

        var missing: [String] = []

        for required in requiredIdentifiers {
            if !permittedIdentifiers.contains(required) {
                missing.append(required)
            }
        }

        return missing
    }

    /// Checks if BGTaskScheduler is properly configured.
    ///
    /// - Returns: `true` if all required identifiers are present.
    static func isConfigured() -> Bool {
        return validateConfiguration().isEmpty
    }

    /// Prints a helpful setup guide if configuration is missing.
    static func printSetupGuideIfNeeded() {
        let missing = validateConfiguration()

        if missing.isEmpty {
            print("✅ BGTaskScheduler: Info.plist configured correctly")
            return
        }

        print("⚠️ BGTaskScheduler: Missing Info.plist configuration!")
        print("")
        print("Add the following to your Info.plist:")
        print("")
        print("<key>BGTaskSchedulerPermittedIdentifiers</key>")
        print("<array>")
        for identifier in missing {
            print("    <string>\(identifier)</string>")
        }
        print("</array>")
        print("")
        print("See: https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler")
    }

    /// Returns a user-friendly error message for missing configuration.
    static func getSetupInstructions() -> String {
        let missing = validateConfiguration()

        if missing.isEmpty {
            return "BGTaskScheduler is properly configured."
        }

        var message = "⚠️ Missing BGTaskScheduler configuration in Info.plist\n\n"
        message += "Add these identifiers to Info.plist:\n\n"
        message += "<key>BGTaskSchedulerPermittedIdentifiers</key>\n"
        message += "<array>\n"

        for identifier in missing {
            message += "    <string>\(identifier)</string>\n"
        }

        message += "</array>\n\n"
        message += "Without this, background tasks will not execute when the app is closed."

        return message
    }
}
