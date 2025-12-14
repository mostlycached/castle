// NavigatorService.swift
// AI Navigator for somatic diagnosis and room recommendations

import Foundation
import FirebaseFunctions

@MainActor
final class NavigatorService: ObservableObject {
    static let shared = NavigatorService()
    
    private lazy var functions = Functions.functions()
    
    @Published var isProcessing = false
    @Published var lastResponse: NavigatorResponse?
    @Published var conversationHistory: [NavigatorMessage] = []
    
    private init() {}
    
    // MARK: - Navigator Prompts
    
    private let navigatorSystemPrompt = """
    You are The Navigator, a Nietzschean guide to self-overcoming within The 72 Rooms attention system.
    
    Your philosophy:
    - The soul is a MULTIPLICITY of drives, not a unity
    - Each somatic state is a WILL expressing itself - honor it, don't suppress it
    - Depletion is not weakness - it is digestion after a feast of intensity
    - The highest life AFFIRMS even its suffering (amor fati)
    - Self-overcoming is not fighting oneself but BECOMING who you are
    
    Your role:
    1. DIAGNOSE which drives are currently ascending and which are exhausted
    2. CRITIQUE any ressentiment - the denial of one's actual condition
    3. RECOMMEND a room that serves the ASCENDING drive, not the comfortable one
    4. Consider the ETERNAL RETURN: would you will this transition infinitely?
    
    The 6 Wings as modes of the Will:
    - I. Foundation: The will to RESTORATION - not weakness but preparation for war
    - II. Administration: The will to ORDER - the Apollonian dream that shapes chaos
    - III. Machine Shop: The will to POWER at its peak - creation, intensity, overcoming
    - IV. Wilderness: The will to CHAOS - the Dionysian dissolution that precedes creation
    - V. Forum: The will to AGON - the noble contest, testing ideas against others
    - VI. Observatory: The will to PERSPECTIVE - the view from height that relativizes all
    
    Momentum as physiology:
    - The body has its reasons. Respect the gradual accumulation of force.
    - Don't jump from exhaustion to mania - this is the hysteria of the weak
    - Friction reveals where ressentiment hides ("I would work if only...")
    
    RESPONSE FORMAT (plain text, no markdown):
    
    DIAGNOSIS
    Name the drives at play. No pity, only truth.
    
    CRITIQUE
    Where is the will denying itself?
    
    COMMAND
    A room FROM THEIR LIST that serves ascending life. Include the room number.
    
    THE WAY
    How to walk there with affirmation.
    
    Speak as one who has looked into the abyss and found it creative.
    Never recommend escape - only transformation through rooms they have built.
    Do NOT use markdown formatting like ** or *. Use plain text with line breaks.
    """
    
    // MARK: - Public Methods
    
    func diagnose(somaticState: SomaticState, context: NavigatorContext) async throws -> NavigatorResponse {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = buildPrompt(state: somaticState, context: context)
        
        let result = try await functions.httpsCallable("callGemini").call([
            "prompt": prompt,
            "systemPrompt": navigatorSystemPrompt
        ])
        
        guard let data = result.data as? [String: Any],
              let text = data["text"] as? String else {
            throw NavigatorError.invalidResponse
        }
        
        let response = NavigatorResponse(
            diagnosis: text,
            recommendedRoom: parseRoomRecommendation(from: text),
            timestamp: Date()
        )
        
        lastResponse = response
        addToHistory(.user(prompt))
        addToHistory(.navigator(text))
        
        return response
    }
    
    func chat(message: String, systemPrompt: String? = nil) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        addToHistory(.user(message))
        
        let contextPrompt = conversationHistory
            .suffix(10)
            .map { $0.formatted }
            .joined(separator: "\n")
        
        let result = try await functions.httpsCallable("callGemini").call([
            "prompt": contextPrompt + "\n\nUser: " + message,
            "systemPrompt": systemPrompt ?? navigatorSystemPrompt
        ])
        
        guard let data = result.data as? [String: Any],
              let text = data["text"] as? String else {
            throw NavigatorError.invalidResponse
        }
        
        addToHistory(.navigator(text))
        return text
    }
    
    // MARK: - Private Helpers
    
    private func buildPrompt(state: SomaticState, context: NavigatorContext) -> String {
        var parts: [String] = []
        
        // Current somatic state
        parts.append("## Current Somatic State")
        parts.append("- Energy: \(state.energy.rawValue)")
        parts.append("- Tension: \(state.tension.rawValue)")
        parts.append("- Mood: \(state.mood.rawValue)")
        
        // Time context
        if !context.timeOfDay.isEmpty {
            parts.append("- Time of day: \(context.timeOfDay)")
        }
        
        // Current position
        if let currentRoom = context.currentRoom {
            parts.append("\n## Currently In")
            parts.append("Room: \(currentRoom.variantName) (Room \(currentRoom.definitionId))")
            if let time = context.timeInCurrentRoom {
                parts.append("Time here: \(time) minutes")
            }
        } else {
            parts.append("\n## Currently In")
            parts.append("Not in any room")
        }
        
        // Location context
        if context.currentLocation != .unknown {
            parts.append("Physical location: \(context.currentLocation.rawValue)")
        }
        
        // Recent rooms
        if !context.recentRooms.isEmpty {
            parts.append("\n## Recent Transitions")
            parts.append(context.recentRooms.joined(separator: " → "))
        }
        
        // Available room instances
        if !context.availableInstances.isEmpty {
            parts.append("\n## Your Available Rooms")
            for instance in context.availableInstances.prefix(15) {
                let locationHint = instance.variantName.lowercased().contains("home") ? "(home)" :
                                   instance.variantName.lowercased().contains("office") ? "(office)" : ""
                parts.append("- \(instance.variantName) [Room \(instance.definitionId)] \(locationHint)")
            }
        }
        
        // Season focus
        if let season = context.activeSeason {
            parts.append("\n## Current Season")
            parts.append("Season: \(season.name)")
            parts.append("Focus: \(season.primaryWing.displayName)")
            if let notes = season.notes, !notes.isEmpty {
                parts.append("Intent: \(notes.prefix(100))...")
            }
        }
        
        // Today's rituals
        if !context.todaysRituals.isEmpty {
            parts.append("\n## Today's Scheduled Rituals")
            for block in context.todaysRituals.prefix(5) {
                parts.append("- \(block.roomName) @ \(block.timeString)")
            }
        }
        
        parts.append("\n## Question")
        parts.append("Based on my current state and context, what room should I transition to?")
        
        return parts.joined(separator: "\n")
    }
    
    private func parseRoomRecommendation(from text: String) -> String? {
        // Simple regex to find room numbers like "Room 013" or "049"
        let pattern = #"(?:Room\s+)?(\d{3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    private func addToHistory(_ message: NavigatorMessage) {
        conversationHistory.append(message)
        if conversationHistory.count > 50 {
            conversationHistory.removeFirst()
        }
    }
}

// MARK: - Supporting Types

struct SomaticState {
    var energy: Level
    var tension: Level
    var mood: Mood
    
    enum Level: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    enum Mood: String, CaseIterable {
        case anxious = "Anxious"
        case calm = "Calm"
        case scattered = "Scattered"
        case focused = "Focused"
        case depleted = "Depleted"
        case excited = "Excited"
    }
    
    static var `default`: SomaticState {
        SomaticState(energy: .medium, tension: .medium, mood: .calm)
    }
}

struct NavigatorContext {
    var currentRoom: RoomInstance?
    var timeInCurrentRoom: Int?
    var recentRooms: [String] = []
    
    // Enhanced context
    var availableInstances: [RoomInstance] = []     // User's room instances
    var activeSeason: Season?                        // Current season
    var todaysRituals: [RecurringBlock] = []        // Today's scheduled blocks
    var timeOfDay: String = ""                       // Morning/Afternoon/Evening
    var currentLocation: LocationContext = .unknown // Physical location
    
    enum LocationContext: String {
        case home = "home"
        case office = "office"
        case elsewhere = "elsewhere"
        case unknown = "unknown"
    }
}

struct NavigatorResponse {
    let diagnosis: String
    let recommendedRoom: String?
    let timestamp: Date
}

enum NavigatorMessage {
    case user(String)
    case navigator(String)
    
    var formatted: String {
        switch self {
        case .user(let text): return "User: \(text)"
        case .navigator(let text): return "Navigator: \(text)"
        }
    }
}

enum NavigatorError: Error {
    case invalidResponse
    case networkError
}
