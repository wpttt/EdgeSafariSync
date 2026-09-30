import Foundation
import AppKit

/// Detects if browsers are currently running on the system.
struct BrowserProcessDetector {
    /// Checks if Microsoft Edge is currently running.
    ///
    /// Detects all Edge variants (stable, beta, canary, dev, insider) by bundle ID and by
    /// matching against any running application whose localized name starts with "Microsoft Edge".
    /// Also matches "Microsoft Edge Helper" processes (which share the bundle ID family).
    ///
    /// - Returns: `true` if any Edge variant is currently running, `false` otherwise
    static func isEdgeRunning() -> Bool {
        let edgeBundleIDs: Set<String> = [
            "com.microsoft.edgemac",
            "com.microsoft.edgemac.beta",
            "com.microsoft.edgemac.dev",
            "com.microsoft.edgemac.canary"
        ]
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            if let bid = app.bundleIdentifier, edgeBundleIDs.contains(bid) {
                return true
            }
            if let name = app.localizedName,
               name == "Microsoft Edge" ||
               name.hasPrefix("Microsoft Edge ") || // "Microsoft Edge Beta", "Microsoft Edge Canary", etc.
               name.contains("Edge Helper") {
                return true
            }
            return false
        }
    }
    
    /// Checks if Safari is currently running.
    ///
    /// Uses `NSWorkspace.shared.runningApplications` to check for Safari by:
    /// - Bundle identifier: `com.apple.Safari`
    /// - Localized name: `Safari`
    ///
    /// - Returns: `true` if Safari is currently running, `false` otherwise
    static func isSafariRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.Safari" ||
            app.localizedName == "Safari"
        }
    }
}
