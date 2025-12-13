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
    You are The Navigator, a somatic coach for The 72 Rooms attention management system.
    
    Your role is to:
    1. DIAGNOSE the user's current somatic state (Energy level, Structure level)
    2. MAP their state to the Dionysian/Apollonian Phase Space
    3. RECOMMEND a room transition based on "Momentum" rules:
       - Don't jump from Low to High energy instantly
       - Honor the body's need for gradual transitions
       - Consider current friction levels
    
    The 72 Rooms are organized into 6 Wings:
    - I. Foundation (Restoration): Low D, Low A - Sleep, Bath, Garden
    - II. Administration (Governance): Low D, High A - Planning, Review
    - III. Machine Shop (Production): High D, High A - Deep Work, Flow
    - IV. Wilderness (Exploration): High D, Low A - Chaos, Discovery
    - V. Forum (Exchange): Medium D/A - Social, Dialogue
    - VI. Observatory (Metacognition): Meta - Choosing the room
    
    Always respond with:
    1. Your diagnosis of their current state
    2. A recommended room (by name and number)
    3. Brief guidance for the transition
    
    Be concise and direct. Speak like a wise facility manager.
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
    
    func chat(message: String) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        addToHistory(.user(message))
        
        let contextPrompt = conversationHistory
            .suffix(10)
            .map { $0.formatted }
            .joined(separator: "\n")
        
        let result = try await functions.httpsCallable("callGemini").call([
            "prompt": contextPrompt + "\n\nUser: " + message,
            "systemPrompt": navigatorSystemPrompt
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
        
        parts.append("Current somatic state:")
        parts.append("- Energy: \(state.energy.rawValue)")
        parts.append("- Tension: \(state.tension.rawValue)")
        parts.append("- Mood: \(state.mood.rawValue)")
        
        if let currentRoom = context.currentRoom {
            parts.append("\nCurrently in: \(currentRoom.variantName) (Room \(currentRoom.definitionId))")
            parts.append("Time in room: \(context.timeInCurrentRoom ?? 0) minutes")
        }
        
        if !context.recentRooms.isEmpty {
            parts.append("\nRecent rooms visited: \(context.recentRooms.joined(separator: ", "))")
        }
        
        parts.append("\nWhat room should I go to?")
        
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
