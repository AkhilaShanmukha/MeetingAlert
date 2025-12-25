//
//  MeetingAlertApp.swift
//  MeetingAlert
//
//  Created by Shanmukha Padala on 24/12/25.
//

import SwiftUI
import AppKit

@main
struct MeetingAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// App delegate to handle app lifecycle and menu bar setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayManager: OverlayManager?
    var menuBarManager: MenuBarManager?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hide dock icon - show only in menu bar (call this early)
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App delegate: applicationDidFinishLaunching called")
        
        // Create managers on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create managers
            let overlayManager = OverlayManager()
            let menuBarManager = MenuBarManager(overlayManager: overlayManager)
            
            self.overlayManager = overlayManager
            self.menuBarManager = menuBarManager
            
            print("✅ Managers created, requesting calendar access...")
            
            // Request calendar permissions on app launch
            overlayManager.requestAccess()
            
            // Prompt for launch at login (after a short delay)
            LaunchAtLoginManager.shared.promptUserForLaunchAtLogin()
            
            print("✅ App initialization complete - Menu bar item should be visible now")
            print("   Look for 'MA' text in the top-right menu bar (near the clock)")
        }
    }
}
