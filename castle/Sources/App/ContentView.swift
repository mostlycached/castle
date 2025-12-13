// ContentView.swift
// Main navigation container for Castle

import SwiftUI

struct ContentView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        TabView {
            CompassView()
                .tabItem {
                    Label("Compass", systemImage: "location.north.circle.fill")
                }
            
            BlueprintView()
                .tabItem {
                    Label("Blueprint", systemImage: "building.2.crop.circle")
                }
            
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            
            WorkshopView()
                .tabItem {
                    Label("Workshop", systemImage: "wrench.and.screwdriver")
                }
        }
        .task {
            await firebaseManager.signInAnonymously()
        }
    }
}

// MARK: - Placeholder Views

struct TimelineView: View {
    var body: some View {
        NavigationStack {
            Text("Timeline")
                .navigationTitle("Timeline")
        }
    }
}

struct WorkshopView: View {
    var body: some View {
        NavigationStack {
            Text("Workshop")
                .navigationTitle("Workshop")
        }
    }
}

#Preview {
    ContentView()
}
