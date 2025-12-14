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
    
    // Rich spec fields (optional - may not be present in all rooms yet)
    let archetype: String?              // "The Filter", "The Reactor", etc.
    let physicsDescription: String?     // Full description of physics
    let equation: String?               // LaTeX equation
    let inputLogic: String?             // What goes in
    let outputLogic: String?            // What comes out
    let evocativeQuote: String?         // The motto/quote
    let evocativeDescription: String?   // The soul description
    let constraints: [RoomConstraint]?  // Hard constraints
    let altar: [AltarItem]?             // Material artifacts
    let liturgy: RoomLiturgy?           // The protocol
    let trap: RoomTrap?                 // Failure mode
    
    var id: String { number }
    
    enum CodingKeys: String, CodingKey {
        case number
        case name
        case physicsHint = "physics_hint"
        case function
        case archetype
        case physicsDescription = "physics_description"
        case equation
        case inputLogic = "input_logic"
        case outputLogic = "output_logic"
        case evocativeQuote = "evocative_quote"
        case evocativeDescription = "evocative_description"
        case constraints
        case altar
        case liturgy
        case trap
    }
    
    // MARK: - Initializer with defaults for optional fields
    
    init(
        number: String,
        name: String,
        physicsHint: String,
        function: String,
        archetype: String? = nil,
        physicsDescription: String? = nil,
        equation: String? = nil,
        inputLogic: String? = nil,
        outputLogic: String? = nil,
        evocativeQuote: String? = nil,
        evocativeDescription: String? = nil,
        constraints: [RoomConstraint]? = nil,
        altar: [AltarItem]? = nil,
        liturgy: RoomLiturgy? = nil,
        trap: RoomTrap? = nil
    ) {
        self.number = number
        self.name = name
        self.physicsHint = physicsHint
        self.function = function
        self.archetype = archetype
        self.physicsDescription = physicsDescription
        self.equation = equation
        self.inputLogic = inputLogic
        self.outputLogic = outputLogic
        self.evocativeQuote = evocativeQuote
        self.evocativeDescription = evocativeDescription
        self.constraints = constraints
        self.altar = altar
        self.liturgy = liturgy
        self.trap = trap
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

// MARK: - Room Constraint

struct RoomConstraint: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    
    init(name: String, description: String) {
        self.name = name
        self.description = description
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
    
    func definition(for id: String) -> RoomDefinition? {
        room(byId: id)
    }
    
    func rooms(inWing wingName: String) -> [RoomDefinition] {
        wings.first { $0.wing == wingName }?.rooms ?? []
    }
}
