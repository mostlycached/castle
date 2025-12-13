// RoomInstance.swift
// Mutable room instance model (The User's Reality)
// Synced with Firebase Firestore

import Foundation
import FirebaseFirestore

/// The user's specific instantiation of a room
/// Contains the inventory, familiarity score, and health status
struct RoomInstance: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    let definitionId: String        // FK to RoomDefinition ("013")
    var variantName: String         // "Balcony Chair"
    var familiarityScore: Double    // 0.0 to 1.0
    var healthScore: Double         // 0.0 to 1.0 (Decays with friction)
    var currentFriction: FrictionLevel
    var requiredInventory: [String] // Legacy simple list
    var inventory: [InventoryItem]  // Structured inventory with status
    var isActive: Bool
    
    // Rich data from attention_architecture.json
    var physics: RoomPhysics?
    var evocativeWhy: String?
    var constraints: [String]
    var liturgy: RoomLiturgy?
    
    // Mastery tracking
    var totalMinutes: Int               // Cumulative time in room
    var lastVisited: Date?              // Last session end time
    var masteryDimensions: [MasteryDimension] // AI-analyzed dimensions
    
    // Music Playlist (8 tracks × ~4 min each)
    var playlist: [RoomTrack]?           // Array of generated tracks
    var playlistGeneratedAt: Date?       // For 4-week expiry check
    var musicContext: MusicContext?      // Rich prompt context
    
    // Mastery level (1-10) based on cumulative time
    // Logarithmic scale: Level 1 = 0min, Level 2 = 60min, Level 3 = 180min, ... Level 10 = 500+ hours
    var masteryLevel: Int {
        switch totalMinutes {
        case 0..<60: return 1           // 0-1 hour
        case 60..<180: return 2         // 1-3 hours
        case 180..<420: return 3        // 3-7 hours
        case 420..<900: return 4        // 7-15 hours
        case 900..<1800: return 5       // 15-30 hours
        case 1800..<3600: return 6      // 30-60 hours
        case 3600..<7200: return 7      // 60-120 hours
        case 7200..<15000: return 8     // 120-250 hours
        case 15000..<30000: return 9    // 250-500 hours
        default: return 10              // 500+ hours = Master
        }
    }
    
    var masteryLevelName: String {
        switch masteryLevel {
        case 1: return "Novice"
        case 2: return "Beginner"
        case 3: return "Apprentice"
        case 4: return "Journeyman"
        case 5: return "Competent"
        case 6: return "Proficient"
        case 7: return "Advanced"
        case 8: return "Expert"
        case 9: return "Virtuoso"
        case 10: return "Master"
        case 11...100: return "Grandmaster"
        default: return "Unknown"
        }
    }
    
    // Computed health based on inventory
    var computedHealth: Double {
        guard !inventory.isEmpty else { return healthScore }
        let criticalItems = inventory.filter { $0.isCritical }
        if criticalItems.isEmpty { return healthScore }
        let operationalCritical = criticalItems.filter { $0.status == .operational }.count
        let criticalRatio = Double(operationalCritical) / Double(criticalItems.count)
        return healthScore * criticalRatio
    }
    
    // Playlist is expired if generated more than 4 weeks ago
    var isPlaylistExpired: Bool {
        guard let generatedAt = playlistGeneratedAt else { return false }
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        return generatedAt < fourWeeksAgo
    }
    
    var hasPlaylist: Bool {
        guard let tracks = playlist else { return false }
        return !tracks.isEmpty
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case variantName = "variant_name"
        case familiarityScore = "familiarity_score"
        case healthScore = "health_score"
        case currentFriction = "current_friction"
        case requiredInventory = "required_inventory"
        case inventory
        case isActive = "is_active"
        case physics
        case evocativeWhy = "evocative_why"
        case constraints
        case liturgy
        case totalMinutes = "total_minutes"
        case lastVisited = "last_visited"
        case masteryDimensions = "mastery_dimensions"
        case playlist
        case playlistGeneratedAt = "playlist_generated_at"
        case musicContext = "music_context"
    }
    
    init(
        definitionId: String,
        variantName: String = "",
        familiarityScore: Double = 0.0,
        healthScore: Double = 1.0,
        currentFriction: FrictionLevel = .medium,
        requiredInventory: [String] = [],
        inventory: [InventoryItem] = [],
        isActive: Bool = false,
        constraints: [String] = [],
        totalMinutes: Int = 0,
        masteryDimensions: [MasteryDimension] = []
    ) {
        self.definitionId = definitionId
        self.variantName = variantName
        self.familiarityScore = familiarityScore
        self.healthScore = healthScore
        self.currentFriction = currentFriction
        self.requiredInventory = requiredInventory
        self.inventory = inventory
        self.isActive = isActive
        self.constraints = constraints
        self.totalMinutes = totalMinutes
        self.lastVisited = nil
        self.masteryDimensions = masteryDimensions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Note: id is handled manually by FirebaseManager due to custom decoding
        id = try container.decodeIfPresent(String.self, forKey: .id) 
        definitionId = try container.decode(String.self, forKey: .definitionId)
        variantName = try container.decodeIfPresent(String.self, forKey: .variantName) ?? ""
        familiarityScore = try container.decodeIfPresent(Double.self, forKey: .familiarityScore) ?? 0.0
        healthScore = try container.decodeIfPresent(Double.self, forKey: .healthScore) ?? 1.0
        currentFriction = try container.decodeIfPresent(FrictionLevel.self, forKey: .currentFriction) ?? .medium
        requiredInventory = try container.decodeIfPresent([String].self, forKey: .requiredInventory) ?? []
        inventory = try container.decodeIfPresent([InventoryItem].self, forKey: .inventory) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        physics = try container.decodeIfPresent(RoomPhysics.self, forKey: .physics)
        evocativeWhy = try container.decodeIfPresent(String.self, forKey: .evocativeWhy)
        constraints = try container.decodeIfPresent([String].self, forKey: .constraints) ?? []
        liturgy = try container.decodeIfPresent(RoomLiturgy.self, forKey: .liturgy)
        totalMinutes = try container.decodeIfPresent(Int.self, forKey: .totalMinutes) ?? 0
        lastVisited = try container.decodeIfPresent(Date.self, forKey: .lastVisited)
        masteryDimensions = try container.decodeIfPresent([MasteryDimension].self, forKey: .masteryDimensions) ?? []
        playlist = try container.decodeIfPresent([RoomTrack].self, forKey: .playlist)
        playlistGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .playlistGeneratedAt)
        musicContext = try container.decodeIfPresent(MusicContext.self, forKey: .musicContext)
    }
}

// MARK: - Mastery Dimension

struct MasteryDimension: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    var level: Double     // 1.0 to 10.0
    var description: String
    
    init(name: String, level: Double, description: String = "") {
        self.name = name
        self.level = level
        self.description = description
    }
}

// MARK: - Inventory Item

struct InventoryItem: Codable, Identifiable, Equatable, Hashable {
    var id: String { name }
    let name: String
    var status: ItemStatus
    let isCritical: Bool
    
    init(name: String, status: ItemStatus = .operational, isCritical: Bool = false) {
        self.name = name
        self.status = status
        self.isCritical = isCritical
    }
}

enum ItemStatus: String, Codable, CaseIterable {
    case operational = "Operational"
    case missing = "Missing"
    case broken = "Broken"
    
    var icon: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .missing: return "questionmark.circle"
        case .broken: return "exclamationmark.triangle"
        }
    }
    
    var color: String {
        switch self {
        case .operational: return "green"
        case .missing: return "orange"
        case .broken: return "red"
        }
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

struct RoomPhysics: Codable, Equatable, Hashable {
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

struct RoomLiturgy: Codable, Equatable, Hashable {
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

// MARK: - Room Track (Single song in playlist)

struct RoomTrack: Codable, Identifiable, Hashable {
    var id: String { url }
    let url: String                 // Firebase Storage URL
    let title: String               // Generated track title
    let durationSeconds: Int        // ~240 seconds (4 min)
    let prompt: String              // Specific prompt for this track
    var isDownloaded: Bool          // Local download status
    var localPath: String?          // Path to downloaded file
    
    init(url: String, title: String, durationSeconds: Int = 240, prompt: String) {
        self.url = url
        self.title = title
        self.durationSeconds = durationSeconds
        self.prompt = prompt
        self.isDownloaded = false
    }
    
    enum CodingKeys: String, CodingKey {
        case url, title, prompt
        case durationSeconds = "duration_seconds"
        case isDownloaded = "is_downloaded"
        case localPath = "local_path"
    }
}

// MARK: - Music Context (Rich prompt generation context)

struct MusicContext: Codable, Hashable {
    // Scene Setting
    let sceneSetting: SceneSetting          // Solo, relational, social
    
    // Narrative
    let narrativeArc: String?               // Story movement if applicable
    
    // Somatic Presence
    let somaticElements: [String]           // heartbeat, touch, breath, etc.
    
    // Physical Location Inspiration
    let locationInspiration: String         // volcano, sea, forest, etc.
    
    // Material (Instruments)
    let instruments: [String]               // piano, strings, synth, etc.
    
    // Atmosphere
    let mood: String                        // contemplative, energizing, etc.
    let tempo: String                       // slow, moderate, upbeat
    
    // Found Sounds
    let foundSounds: [String]               // bubbles, pen clicks, rain, etc.
    
    enum CodingKeys: String, CodingKey {
        case sceneSetting = "scene_setting"
        case narrativeArc = "narrative_arc"
        case somaticElements = "somatic_elements"
        case locationInspiration = "location_inspiration"
        case instruments
        case mood
        case tempo
        case foundSounds = "found_sounds"
    }
    
    /// Generate ElevenLabs prompt for a specific track number
    func promptFor(trackNumber: Int) -> String {
        var parts: [String] = []
        
        // Base context
        parts.append("Ambient music for a \(sceneSetting.rawValue) experience.")
        
        // Location
        parts.append("Inspired by: \(locationInspiration).")
        
        // Instruments
        if !instruments.isEmpty {
            parts.append("Instruments: \(instruments.joined(separator: ", ")).")
        }
        
        // Atmosphere
        parts.append("Mood: \(mood). Tempo: \(tempo).")
        
        // Somatic
        if !somaticElements.isEmpty {
            parts.append("Evoking: \(somaticElements.joined(separator: ", ")).")
        }
        
        // Found sounds
        if !foundSounds.isEmpty {
            parts.append("Integrate found sounds: \(foundSounds.joined(separator: ", ")).")
        }
        
        // Narrative progression
        if let arc = narrativeArc {
            let progression = ["opening", "rising", "building", "peak", "reflection", "descent", "resolution", "closing"]
            let phase = progression[min(trackNumber - 1, progression.count - 1)]
            parts.append("Narrative phase: \(phase) (\(arc)).")
        }
        
        // Track variation
        parts.append("Track \(trackNumber) of 8. Duration: 4 minutes.")
        
        return parts.joined(separator: " ")
    }
}

enum SceneSetting: String, Codable, CaseIterable {
    case solo = "solo/single person"
    case relational = "relational/one-on-one"
    case social = "social/group"
}
