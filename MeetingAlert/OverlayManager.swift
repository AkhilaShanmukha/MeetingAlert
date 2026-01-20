import SwiftUI
import AppKit
import EventKit
import Combine

struct FullScreenView: View {
    let event: EKEvent
    var dismissAction: () -> Void
    
    var meetingURL: URL? {
        let text = "\(event.notes ?? "") \(event.location ?? "")"
        return findMeetingURL(in: text)
    }
    
    var meetingService: String {
        guard let url = meetingURL else { return "Meeting" }
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom.us") { return "Zoom" }
        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") { return "Teams" }
        if host.contains("meet.google.com") { return "Google Meet" }
        if host.contains("webex.com") { return "Webex" }
        return "Meeting"
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Upcoming Meeting")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.gray)
            
            Text(event.title ?? "Untitled Meeting")
                .font(.system(size: 60, weight: .bold))
                .multilineTextAlignment(.center)
            
            if let url = meetingURL {
                Button(action: openMeeting) {
                    Text("Join \(meetingService)")
                        .font(.title)
                        .padding()
                        .frame(width: 250)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: openInCalendar) {
                    Text("Open in Calendar")
                        .font(.title)
                        .padding()
                        .frame(width: 250)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .buttonStyle(.plain)
            }

            Button("Dismiss") {
                dismissAction()
            }
            .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func openMeeting() {
        if let url = meetingURL {
            NSWorkspace.shared.open(url)
        }
        dismissAction()
    }
    
    func openInCalendar() {
        // Open the event in Calendar app
        if let url = URL(string: "ical://ekevent/\(event.eventIdentifier ?? "")") {
            NSWorkspace.shared.open(url)
        }
        dismissAction()
    }

    func findMeetingURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // Prioritize video conferencing links
        if let videoLink = matches?.first(where: { match in
            guard let url = match.url, let host = url.host?.lowercased() else { return false }
            return host.contains("zoom.us") || 
                   host.contains("teams.microsoft.com") || 
                   host.contains("teams.live.com") ||
                   host.contains("meet.google.com") ||
                   host.contains("webex.com")
        })?.url {
            return videoLink
        }
        
        // Return any URL found
        return matches?.first?.url
    }
}

class OverlayManager: NSObject, ObservableObject {
    var objectWillChange = PassthroughSubject<Void, Never>()
    var window: NSPanel?
    var checkTimer: Timer?
    let eventStore = EKEventStore()
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
               let status = EKEventStore.authorizationStatus(for: .event)
               print("Current EK authorization status: \(status.rawValue)")
           }
        
        // Check if we are on a version of macOS that supports Full Access (macOS 14+)
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                if granted {
                    print("Full Access Granted")
                    DispatchQueue.main.async {
                        self.scheduleTimer()
                    }
                } else {
                    print("Full Access Denied: \(String(describing: error))")
                }
            }
        } else {
            // Fallback for older macOS versions
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    DispatchQueue.main.async {
                        self.scheduleTimer()
                    }
                }
            }
        }
    }

    func scheduleTimer() {
        // Invalidate any existing timer
        checkTimer?.invalidate()
        
        // Check immediately first
        checkUpcomingMeetings()
        
        // Then check every 30 seconds for meetings starting in the next 1 minute
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkUpcomingMeetings()
        }
        
        // Ensure timer runs on main run loop
        RunLoop.main.add(checkTimer!, forMode: .common)
        
        print("✅ Timer scheduled - will check for meetings every 30 seconds")
    }

    func checkUpcomingMeetings() {
        // Check for meetings that started in the last minute or are starting in the next minute
        // This ensures we catch meetings that just started
        let now = Date()
        let start = Date(timeIntervalSinceNow: -60) // Look back 1 minute
        let end = Date(timeIntervalSinceNow: 60)    // Look forward 1 minute
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        print("🔍 Checking for meetings between \(start) and \(end) - Found \(events.count) events")
        
        // Separate events into timed events and all-day events
        let timedEvents = events.filter { !$0.isAllDay }
        let allDayEvents = events.filter { $0.isAllDay }
        
        print("   Timed events: \(timedEvents.count), All-day events: \(allDayEvents.count)")
        
        // First, prioritize Zoom meetings (timed events only)
        if let zoomMeeting = timedEvents.first(where: { event in
            let hasZoom = event.notes?.contains("zoom.us") == true || event.location?.contains("zoom.us") == true
            // Check if meeting is currently happening or starting within the next minute
            let isCurrentOrUpcoming = event.startDate <= Date(timeIntervalSinceNow: 60) && 
                                     event.endDate > now
            return hasZoom && isCurrentOrUpcoming
        }) {
            print("📅 Found upcoming Zoom meeting: \(zoomMeeting.title ?? "Untitled") at \(zoomMeeting.startDate)")
            DispatchQueue.main.async {
                self.showOverlay(for: zoomMeeting)
            }
            return
        }
        
        // If no Zoom meeting, check for any overlapping timed calendar event
        // Prioritize timed events over all-day events
        if let overlappingMeeting = timedEvents.first(where: { event in
            // Event overlaps if:
            // 1. It starts before or at the end of our window (within next minute)
            // 2. It ends after now (still happening or about to start)
            let startsWithinWindow = event.startDate <= end
            let isStillActive = event.endDate > now
            let isCurrentOrUpcoming = event.startDate <= Date(timeIntervalSinceNow: 60)
            
            return startsWithinWindow && isStillActive && isCurrentOrUpcoming
        }) {
            print("📅 Found overlapping timed calendar event: \(overlappingMeeting.title ?? "Untitled") at \(overlappingMeeting.startDate)")
            DispatchQueue.main.async {
                self.showOverlay(for: overlappingMeeting)
            }
            return
        }
        
        // Only show all-day events if there are no timed events overlapping
        if let allDayEvent = allDayEvents.first {
            print("📅 Found all-day calendar event: \(allDayEvent.title ?? "Untitled")")
            DispatchQueue.main.async {
                self.showOverlay(for: allDayEvent)
            }
        } else {
            print("   No overlapping meetings found in the current time window")
        }
    }

    func showOverlay(for event: EKEvent) {
        if window != nil { return }

        let screenFrame = NSScreen.main?.frame ?? .zero
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        
        // --- ANIMATION STEP 1: Start Invisible ---
        panel.alphaValue = 0.0
        
        let contentView = FullScreenView(event: event, dismissAction: { self.hideOverlay() })
        panel.contentView = NSHostingView(rootView: contentView)
        
        panel.orderFrontRegardless()
        self.window = panel

        // --- ANIMATION STEP 2: Fade In ---
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8 // Duration in seconds
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1.0
        }
    }

    func hideOverlay() {
        window?.orderOut(nil)
        window = nil
    }
    
    // Get the next or current meeting
    func getNextMeeting() -> EKEvent? {
        let start = Date()
        let end = Date(timeIntervalSinceNow: 24 * 60 * 60) // Check next 24 hours
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Return the first meeting (current or next)
        return events.sorted(by: { $0.startDate < $1.startDate }).first
    }
    
    // Get all upcoming events
    func getUpcomingEvents(limit: Int = 10) -> [EKEvent] {
        let start = Date()
        let end = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60) // Check next 7 days
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Return sorted events (upcoming first)
        return Array(events.sorted(by: { $0.startDate < $1.startDate }).prefix(limit))
    }
    
    // Find Zoom URL in event
    func findZoomURL(in event: EKEvent) -> URL? {
        let text = "\(event.notes ?? "") \(event.location ?? "")"
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first(where: { $0.url?.host?.contains("zoom.us") == true })?.url
    }
}
