import SwiftUI
import AppKit
import EventKit
import Combine

struct FullScreenView: View {
    let event: EKEvent
    var dismissAction: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("Upcoming Meeting")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.gray)
            
            Text(event.title)
                .font(.system(size: 60, weight: .bold))
                .multilineTextAlignment(.center)
            
            Button(action: openZoom) {
                Text("Join Zoom")
                    .font(.title)
                    .padding()
                    .frame(width: 250)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .buttonStyle(.plain)

            Button("Dismiss") {
                dismissAction()
            }
            .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func openZoom() {
        // Heuristic to find the URL in notes or location
        let text = "\(event.notes ?? "") \(event.location ?? "")"
        if let url = findZoomURL(in: text) {
            NSWorkspace.shared.open(url)
        }
        dismissAction()
    }

    func findZoomURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first(where: { $0.url?.host?.contains("zoom.us") == true })?.url
    }
}

class OverlayManager: NSObject, ObservableObject {
    var objectWillChange = PassthroughSubject<Void, Never>()
    var window: NSPanel?
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
                    self.scheduleTimer()
                } else {
                    print("Full Access Denied: \(String(describing: error))")
                }
            }
        } else {
            // Fallback for older macOS versions
            eventStore.requestAccess(to: .event) { granted, error in
                if granted { self.scheduleTimer() }
            }
        }
    }

    func scheduleTimer() {
        // Check every 30 seconds for meetings starting in the next 1 minute
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.checkUpcomingMeetings()
        }
    }

    func checkUpcomingMeetings() {
        let start = Date()
        let end = Date(timeIntervalSinceNow: 60)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        if let meeting = events.first(where: { $0.notes?.contains("zoom.us") == true || $0.location?.contains("zoom.us") == true }) {
            DispatchQueue.main.async {
                self.showOverlay(for: meeting)
            }
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
