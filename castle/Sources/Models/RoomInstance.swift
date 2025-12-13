// RoomInstance.swift
// Mutable room instance model (The User's Reality)
// Synced with Firebase Firestore

import Foundation
import FirebaseFirestore

/// The user's specific instantiation of a room
/// Contains the inventory, familiarity score, and health status
struct RoomInstance: Codable, Identifiable {
    @DocumentID var id: String?
    
    let definitionId: String        // FK to RoomDefinition ("013")
    var variantName: String         // "Balcony Chair"
    var familiarityScore: Double    // 0.0 to 1.0
    var healthScore: Double         // 0.0 to 1.0 (Decays with friction)
    var currentFriction: FrictionLevel
    var requiredInventory: [String]
    var isActive: Bool
    
    // Rich data from attention_architecture.json
    var physics: RoomPhysics?
    var evocativeWhy: String?
    var constraints: [String]
    var liturgy: RoomLiturgy?
    
    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case variantName = "variant_name"
        case familiarityScore = "familiarity_score"
        case healthScore = "health_score"
        case currentFriction = "current_friction"
        case requiredInventory = "required_inventory"
        case isActive = "is_active"
        case physics
        case evocativeWhy = "evocative_why"
        case constraints
        case liturgy
    }
    
    init(
        definitionId: String,
        variantName: String = "",
        familiarityScore: Double = 0.0,
        healthScore: Double = 1.0,
        currentFriction: FrictionLevel = .medium,
        requiredInventory: [String] = [],
        isActive: Bool = false,
        constraints: [String] = []
    ) {
        self.definitionId = definitionId
        self.variantName = variantName
        self.familiarityScore = familiarityScore
        self.healthScore = healthScore
        self.currentFriction = currentFriction
        self.requiredInventory = requiredInventory
        self.isActive = isActive
        self.constraints = constraints
    }
}

// MARK: - Friction Level

enum FrictionLevel: String, Codable, CaseIterable {
    case zero = "Zero"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .zero: return "green"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "red"
        }
    }
}

// MARK: - Room Physics

struct RoomPhysics: Codable, Equatable {
    let dionysianEnergy: String
    let apollonianStructure: String
    let inputLogic: String
    let outputLogic: String
    
    enum CodingKeys: String, CodingKey {
        case dionysianEnergy = "dionysian_energy"
        case apollonianStructure = "apollonian_structure"
        case inputLogic = "input_logic"
        case outputLogic = "output_logic"
    }
}

// MARK: - Room Liturgy

struct RoomLiturgy: Codable, Equatable {
    let entry: String
    let steps: [String]
    let exit: String
    
    init(entry: String, steps: [String] = [], exit: String) {
        self.entry = entry
        self.steps = steps
        self.exit = exit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var foundEntry: String = ""
        var foundExit: String = ""
        var foundSteps: [String] = []
        
        for key in container.allKeys {
            let value = try container.decode(String.self, forKey: key)
            if key.stringValue == "entry" {
                foundEntry = value
            } else if key.stringValue == "exit" {
                foundExit = value
            } else if key.stringValue.hasPrefix("step_") {
                foundSteps.append(value)
            }
        }
        
        self.entry = foundEntry
        self.exit = foundExit
        self.steps = foundSteps
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encode(entry, forKey: DynamicCodingKeys(stringValue: "entry")!)
        try container.encode(exit, forKey: DynamicCodingKeys(stringValue: "exit")!)
        for (index, step) in steps.enumerated() {
            try container.encode(step, forKey: DynamicCodingKeys(stringValue: "step_\(index + 1)")!)
        }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
