//
//  LaunchAtLoginManager.swift
//  MeetingAlert
//
//  Created for MeetingAlert
//

import Foundation
import ServiceManagement
import AppKit
import CoreServices

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let bundleIdentifier = "shanmukrao.MeetingAlert"
    
    private init() {}
    
    var isEnabled: Bool {
        // Simplified check: use UserDefaults to track state
        // The actual system check is complex due to deprecated APIs
        // We'll rely on our own state tracking
        return UserDefaults.standard.bool(forKey: "launchAtLoginEnabled")
    }
    
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        // Store the preference
        UserDefaults.standard.set(enabled, forKey: "launchAtLoginEnabled")
        
        // Use AppleScript to add/remove from login items (works even with sandboxing)
        let script = enabled ? """
            tell application "System Events"
                make login item at end with properties {path:"\(Bundle.main.bundleURL.path)", hidden:false}
            end tell
        """ : """
            tell application "System Events"
                delete login item "\(Bundle.main.bundleURL.lastPathComponent)"
            end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error == nil {
                return true
            }
        }
        
        // Fallback: Open System Settings to Login Items
        if enabled {
            // Open System Settings to Login Items page
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?LoginItems")!
            NSWorkspace.shared.open(url)
        }
        
        return error == nil
    }
    
    func promptUserForLaunchAtLogin() {
        // Check if we've already asked
        let hasAsked = UserDefaults.standard.bool(forKey: "hasAskedLaunchAtLogin")
        
        if !hasAsked && !isEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let alert = NSAlert()
                alert.messageText = "Launch at Login"
                alert.informativeText = "Would you like MeetingAlert to launch automatically when you log in? You can change this later from the menu."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "Not Now")
                
                let response = alert.runModal()
                
                if response == .alertFirstButtonReturn {
                    // User clicked "Yes"
                    _ = self.setLaunchAtLogin(true)
                }
                
                UserDefaults.standard.set(true, forKey: "hasAskedLaunchAtLogin")
            }
        }
    }
}
