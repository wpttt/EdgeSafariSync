import Foundation
import AppKit

/// Detects if browsers are currently running on the system.
struct BrowserProcessDetector {
    /// Checks if Microsoft Edge is currently running.
    /// 
    /// Uses `NSWorkspace.shared.runningApplications` to check for Edge by:
    /// - Bundle identifier: `com.microsoft.edgemac`
    /// - Localized name: `Microsoft Edge`
    ///
    /// - Returns: `true` if Edge is currently running, `false` otherwise
    static func isEdgeRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.microsoft.edgemac" ||
            app.localizedName == "Microsoft Edge"
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
