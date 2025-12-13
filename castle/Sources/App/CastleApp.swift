// CastleApp.swift
// Main entry point for Castle

import SwiftUI
import FirebaseCore

// Ensure configuration helper is available

@main
struct CastleApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

