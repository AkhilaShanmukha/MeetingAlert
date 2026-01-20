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
    // Track which events we've already shown to prevent duplicate popups
    private var shownEventIdentifiers: Set<String> = []
    
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
        // Only show overlay for meetings that are starting soon (within 2 minutes of start time)
        // This prevents showing the popup repeatedly for long-running meetings
        let now = Date()
        let startWindow = Date(timeIntervalSinceNow: -30) // Look back 30 seconds (in case we missed it)
        let endWindow = Date(timeIntervalSinceNow: 120)    // Look forward 2 minutes
        
        let predicate = eventStore.predicateForEvents(withStart: startWindow, end: endWindow, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        print("🔍 Checking for meetings starting soon - Found \(events.count) events")
        
        // Separate events into timed events and all-day events
        let timedEvents = events.filter { !$0.isAllDay }
        let allDayEvents = events.filter { $0.isAllDay }
        
        print("   Timed events: \(timedEvents.count), All-day events: \(allDayEvents.count)")
        
        // Clean up shown events to prevent unbounded growth
        // Strategy: Only keep identifiers for events currently in the time window
        // This automatically removes old events that have passed
        let currentEventIdentifiers = Set(events.compactMap { $0.eventIdentifier })
        
        // Filter: keep current events and today's all-day event keys
        shownEventIdentifiers = shownEventIdentifiers.filter { identifier in
            // Keep if it's a current event in the time window
            if currentEventIdentifiers.contains(identifier) {
                return true
            }
            
            // For day-based keys (all-day events), check if it's from today
            // Format: "eventIdentifier-YYYY-MM-DD" or similar
            if identifier.contains("-") {
                // Simple check: if the identifier contains today's date components, keep it
                // For now, we'll be conservative and remove all day keys that aren't current
                // The all-day event logic will re-add today's key if needed
                return false
            }
            
            // Remove everything else (events that have passed)
            return false
        }
        
        // Enforce hard maximum size limit (100 identifiers max)
        // This is a safety net in case cleanup misses something
        if shownEventIdentifiers.count > 100 {
            // If we exceed the limit, keep only current events
            shownEventIdentifiers = currentEventIdentifiers
            print("⚠️ Cleaned up shownEventIdentifiers: exceeded limit, reset to current events only")
        }
        
        // First, prioritize meetings with video links (Zoom, Teams, Google Meet, Webex)
        if let videoMeeting = timedEvents.first(where: { event in
            // Check if we've already shown this event
            guard let identifier = event.eventIdentifier, !shownEventIdentifiers.contains(identifier) else {
                return false
            }
            
            // Check if it has a video conferencing link
            let text = "\(event.notes ?? "") \(event.location ?? "")"
            let hasVideoLink = text.contains("zoom.us") || 
                              text.contains("teams.microsoft.com") || 
                              text.contains("teams.live.com") ||
                              text.contains("meet.google.com") ||
                              text.contains("webex.com")
            
            // Only show if meeting is starting within the next 2 minutes
            // or started in the last 30 seconds (to catch meetings that just started)
            let timeUntilStart = event.startDate.timeIntervalSince(now)
            let isStartingSoon = timeUntilStart >= -30 && timeUntilStart <= 120
            
            return hasVideoLink && isStartingSoon
        }) {
            print("📅 Found upcoming video meeting: \(videoMeeting.title ?? "Untitled") at \(videoMeeting.startDate)")
            if let identifier = videoMeeting.eventIdentifier {
                shownEventIdentifiers.insert(identifier)
            }
            DispatchQueue.main.async {
                self.showOverlay(for: videoMeeting)
            }
            return
        }
        
        // If no video meeting, check for any timed calendar event starting soon
        if let upcomingMeeting = timedEvents.first(where: { event in
            // Check if we've already shown this event
            guard let identifier = event.eventIdentifier, !shownEventIdentifiers.contains(identifier) else {
                return false
            }
            
            // Only show if meeting is starting within the next 2 minutes
            // or started in the last 30 seconds
            let timeUntilStart = event.startDate.timeIntervalSince(now)
            let isStartingSoon = timeUntilStart >= -30 && timeUntilStart <= 120
            
            return isStartingSoon
        }) {
            print("📅 Found upcoming timed calendar event: \(upcomingMeeting.title ?? "Untitled") at \(upcomingMeeting.startDate)")
            if let identifier = upcomingMeeting.eventIdentifier {
                shownEventIdentifiers.insert(identifier)
            }
            DispatchQueue.main.async {
                self.showOverlay(for: upcomingMeeting)
            }
            return
        }
        
        // Only show all-day events if there are no timed events starting soon
        // And only show once per day
        if let allDayEvent = allDayEvents.first {
            let today = Calendar.current.startOfDay(for: now)
            let eventDay = Calendar.current.startOfDay(for: allDayEvent.startDate)
            let dayKey = "\(allDayEvent.eventIdentifier ?? "")-\(eventDay)"
            
            if eventDay == today && !shownEventIdentifiers.contains(dayKey) {
                print("📅 Found all-day calendar event: \(allDayEvent.title ?? "Untitled")")
                shownEventIdentifiers.insert(dayKey)
                DispatchQueue.main.async {
                    self.showOverlay(for: allDayEvent)
                }
            }
        } else {
            print("   No meetings starting soon found")
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
        // Note: We keep the event identifier in shownEventIdentifiers
        // so we don't show the same meeting again
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
