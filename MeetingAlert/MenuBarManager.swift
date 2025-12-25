import SwiftUI
import AppKit
import EventKit
import Combine

class MenuBarManager: NSObject, ObservableObject {
    // Keep strong reference to prevent deallocation
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var updateTimer: Timer?
    
    @Published var overlayManager: OverlayManager
    @Published var currentMeeting: EKEvent?
    
    init(overlayManager: OverlayManager) {
        self.overlayManager = overlayManager
        super.init()
        setupMenuBar()
        startUpdatingMeetingInfo()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    func setupMenuBar() {
        // Create status bar item with strong reference
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else {
            print("ERROR: Failed to get status bar button")
            return
        }
        
        // Use text for maximum visibility - "MA" for Meeting Alert
        // Prioritize text over image to ensure visibility
        button.title = "MA"
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.appearsDisabled = false
        
        // Optionally add an image alongside text (not replacing it)
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Meeting Alert") {
                image.isTemplate = true
                image.size = NSSize(width: 16, height: 16)
                button.image = image
                button.imagePosition = .imageLeading  // Image on left, text on right
            }
        }
        
        button.action = #selector(showMenu)
        button.target = self
        button.toolTip = "Meeting Alert - Click to open menu"
        
        print("✅ Menu bar item created successfully - look for 'MA' or calendar icon in menu bar")
        
        // Create menu
        menu = NSMenu()
        menu.delegate = self
    }
    
    func startUpdatingMeetingInfo() {
        // Update immediately
        updateMeetingInfo()
        
        // Update every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMeetingInfo()
        }
    }
    
    func updateMeetingInfo() {
        guard let meeting = overlayManager.getNextMeeting() else {
            // No meeting found, show default
            updateMenuBarTitle("MA")
            currentMeeting = nil
            return
        }
        
        currentMeeting = meeting
        
        // Format the meeting name for menu bar
        let meetingTitle = meeting.title ?? "Untitled Meeting"
        
        // Truncate if too long (menu bar has limited space)
        let maxLength = 30
        let displayTitle = meetingTitle.count > maxLength 
            ? String(meetingTitle.prefix(maxLength - 3)) + "..." 
            : meetingTitle
        
        updateMenuBarTitle(displayTitle)
    }
    
    func updateMenuBarTitle(_ title: String) {
        guard let button = statusItem?.button else { return }
        
        DispatchQueue.main.async {
            button.title = title
            button.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            
            // Update tooltip with full meeting info
            if let meeting = self.currentMeeting {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let timeString = formatter.string(from: meeting.startDate)
                button.toolTip = "\(meeting.title ?? "Meeting")\nStarts at \(timeString)"
            } else {
                button.toolTip = "Meeting Alert - Click to open menu"
            }
        }
    }
    
    @objc func showMenu(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        // Update menu before showing
        buildMenu()
        
        // Show menu
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil // Remove menu so button click works next time
    }
    
    func buildMenu() {
        menu.removeAllItems()
        
        // Get upcoming events
        let events = overlayManager.getUpcomingEvents(limit: 10)
        
        if events.isEmpty {
            let noEventsItem = NSMenuItem(title: "No upcoming meetings", action: nil, keyEquivalent: "")
            noEventsItem.isEnabled = false
            menu.addItem(noEventsItem)
        } else {
            // Add header
            let headerItem = NSMenuItem(title: "Upcoming Meetings", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(NSMenuItem.separator())
            
            // Add each event
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE" // Day of week
            
            var currentDay: String? = nil
            
            for event in events {
                let eventDay = dayFormatter.string(from: event.startDate)
                
                // Add day separator if needed
                if currentDay != eventDay {
                    if currentDay != nil {
                        menu.addItem(NSMenuItem.separator())
                    }
                    currentDay = eventDay
                    
                    let dayItem = NSMenuItem(title: eventDay, action: nil, keyEquivalent: "")
                    dayItem.isEnabled = false
                    menu.addItem(dayItem)
                }
                
                // Create menu item for event
                let timeString = dateFormatter.string(from: event.startDate)
                let title = "\(timeString) - \(event.title ?? "Untitled Meeting")"
                
                let menuItem = NSMenuItem(title: title, action: #selector(openEvent(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = event
                
                // Check if it has a Zoom link
                if overlayManager.findZoomURL(in: event) != nil {
                    menuItem.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Zoom meeting")
                    menuItem.image?.isTemplate = true
                    menuItem.image?.size = NSSize(width: 16, height: 16)
                }
                
                menu.addItem(menuItem)
            }
        }
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login toggle
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        // Add separator and quit
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Meeting Alert", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let currentlyEnabled = LaunchAtLoginManager.shared.isEnabled
        let newState = !currentlyEnabled
        
        if LaunchAtLoginManager.shared.setLaunchAtLogin(newState) {
            sender.state = newState ? .on : .off
            print("✅ Launch at login \(newState ? "enabled" : "disabled")")
        } else {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Unable to change launch at login setting"
            alert.informativeText = "Please try again or check System Settings > Users & Groups > Login Items"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func openEvent(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? EKEvent else { return }
        
        // Try to open Zoom link
        if let zoomURL = overlayManager.findZoomURL(in: event) {
            NSWorkspace.shared.open(zoomURL)
            print("✅ Opened Zoom link: \(zoomURL)")
        } else {
            // No Zoom link found, show alert or open calendar
            let alert = NSAlert()
            alert.messageText = event.title ?? "Meeting"
            alert.informativeText = "No Zoom link found for this meeting."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate
extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update menu when it's about to open
        buildMenu()
    }
}

struct MenuBarView: View {
    @ObservedObject var overlayManager: OverlayManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Meeting Alert")
                .font(.headline)
                .padding(.top)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Status: Active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Monitoring calendar for Zoom meetings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Divider()
            
            Button("Test Overlay") {
                let store = EKEventStore()
                let testEvent = EKEvent(eventStore: store)
                testEvent.title = "Test Zoom Meeting"
                testEvent.notes = "https://zoom.us/j/123456789"
                overlayManager.showOverlay(for: testEvent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.bottom)
        }
        .frame(width: 300, height: 200)
    }
}

