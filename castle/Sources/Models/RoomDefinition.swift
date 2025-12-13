// RoomDefinition.swift
// Static room class model (The Platonic Ideal)
// Loaded from bundled rooms_data.json

import Foundation

/// A Wing contains a group of related rooms
struct Wing: Codable, Identifiable {
    var id: String { wing }
    let wing: String
    let rooms: [RoomDefinition]
}

/// The Platonic definition of a room - immutable, bundled with the app
struct RoomDefinition: Codable, Identifiable, Hashable {
    let number: String      // "013"
    let name: String        // "The Morning Chapel"
    let physicsHint: String // "Low D, High A. Signal calibration."
    let function: String    // "Setting the trajectory. Zero external input."
    
    var id: String { number }
    
    enum CodingKeys: String, CodingKey {
        case number
        case name
        case physicsHint = "physics_hint"
        case function
    }
    
    // MARK: - Computed Properties
    
    /// Parse Dionysian energy level from physics hint
    var dionysianLevel: EnergyLevel {
        let hint = physicsHint.lowercased()
        if hint.contains("high d") { return .high }
        if hint.contains("medium d") || hint.contains("moderate d") { return .medium }
        if hint.contains("meta") { return .meta }
        return .low
    }
    
    /// Parse Apollonian structure level from physics hint
    var apollonianLevel: EnergyLevel {
        let hint = physicsHint.lowercased()
        if hint.contains("high a") { return .high }
        if hint.contains("medium a") || hint.contains("moderate a") { return .medium }
        if hint.contains("meta") { return .meta }
        return .low
    }
    
    enum EnergyLevel: String, Codable {
        case low, medium, high, meta
        
        var color: String {
            switch self {
            case .low: return "blue"
            case .medium: return "purple"
            case .high: return "orange"
            case .meta: return "teal"
            }
        }
    }
}

// MARK: - Room Loader

@MainActor
final class RoomLoader: ObservableObject {
    static let shared = RoomLoader()
    
    @Published var wings: [Wing] = []
    @Published var allRooms: [RoomDefinition] = []
    
    private init() {
        loadRooms()
    }
    
    private func loadRooms() {
        guard let url = Bundle.main.url(forResource: "rooms_data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load rooms_data.json")
            return
        }
        
        do {
            wings = try JSONDecoder().decode([Wing].self, from: data)
            allRooms = wings.flatMap { $0.rooms }
        } catch {
            print("Failed to decode rooms: \(error)")
        }
    }
    
    func room(byId id: String) -> RoomDefinition? {
        allRooms.first { $0.id == id }
    }
    
    func rooms(inWing wingName: String) -> [RoomDefinition] {
        wings.first { $0.wing == wingName }?.rooms ?? []
    }
}
