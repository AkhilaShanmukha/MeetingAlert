//
//  ContentView.swift
//  MeetingAlert
//
//  Created by Shanmukha Padala on 24/12/25.
//

import SwiftUI
import AppKit
import EventKit  // <--- This is the missing line

struct ContentView: View {
    // Use the shared manager from the app
    @ObservedObject var overlayManager: OverlayManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Focus Meeting Controller")
                .font(.headline)
            
            Button("Test Full Screen Overlay") {
                // Create a dummy event to test the UI immediately
                let store = EKEventStore()
                let testEvent = EKEvent(eventStore: store)
                testEvent.title = "Test Zoom Meeting"
                testEvent.notes = "https://zoom.us/j/123456789"
                
                overlayManager.showOverlay(for: testEvent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Ensure you have granted Calendar access in System Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 200)
        .task {
            // Request calendar permissions when the view appears
            overlayManager.requestAccess()
        }
    }
}

#Preview {
    ContentView(overlayManager: OverlayManager())
}
