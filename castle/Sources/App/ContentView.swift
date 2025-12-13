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
            
            StrategistView()
                .tabItem {
                    Label("Strategist", systemImage: "map.fill")
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

#Preview {
    ContentView()
}
