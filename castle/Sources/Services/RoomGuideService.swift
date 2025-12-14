// RoomGuideService.swift
// AI agent for in-room presence guidance

import Foundation
import UIKit
import FirebaseFunctions

/// The Room Guide helps users stay present and engaged while in a room
@MainActor
final class RoomGuideService: ObservableObject {
    static let shared = RoomGuideService()
    
    private lazy var functions = Functions.functions()
    
    @Published var messages: [GuideMessage] = []
    @Published var isLoading = false
    
    private var currentInstance: RoomInstance?
    private var currentDefinition: RoomDefinition?
    
    public enum TransitionType {
        case entry
        case exit
    }
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Start guiding for a specific room instance
    func startGuiding(instance: RoomInstance, definition: RoomDefinition) {
        currentInstance = instance
        currentDefinition = definition
        messages = []
        
        // Add initial greeting
        let greeting = generateGreeting(instance: instance, definition: definition)
        messages.append(GuideMessage(role: .guide, content: greeting))
    }
    
    /// End the current guidance session
    func endGuiding() {
        currentInstance = nil
        currentDefinition = nil
        messages = []
    }
    
    // MARK: - Chat
    
    /// Send a message to the Room Guide
    /// - Parameters:
    ///   - text: The user's message
    ///   - systemPrompt: Optional custom system prompt (overrides default Room Guide prompt)
    ///   - image: Optional image to analyze
    func sendMessage(_ text: String, systemPrompt customPrompt: String? = nil, image: UIImage? = nil) async {
        guard let instance = currentInstance, let definition = currentDefinition else { return }
        
        // Add user message (with image indicator)
        let displayText = image != nil ? "📷 " + (text.isEmpty ? "[Image]" : text) : text
        messages.append(GuideMessage(role: .user, content: displayText))
        isLoading = true
        
        defer { isLoading = false }
        
        do {
            // Use custom prompt if provided, otherwise build default
            let systemPrompt = customPrompt ?? buildSystemPrompt(instance: instance, definition: definition)
            let conversationContext = buildConversationContext()
            
            var callData: [String: Any] = [
                "prompt": "\(conversationContext)\n\nUser: \(text.isEmpty && image != nil ? "What do you see in this image? Analyze it from your philosophical perspective." : text)",
                "systemPrompt": systemPrompt,
                "model": "gemini-2.0-flash"
            ]
            
            // Add base64 image if present
            if let image = image,
               let imageData = image.jpegData(compressionQuality: 0.7) {
                callData["imageBase64"] = imageData.base64EncodedString()
            }
            
            let result = try await functions.httpsCallable("callGemini").call(callData)
            
            if let data = result.data as? [String: Any],
               let responseText = data["text"] as? String {
                
                // Try to parse structured response
                if let jsonData = extractJSON(from: responseText),
                   let response = try? JSONDecoder().decode(GuideResponse.self, from: jsonData) {
                    
                    messages.append(GuideMessage(role: .guide, content: response.message))
                    
                    if let action = response.action {
                        await executeAction(action, instanceId: instance.id)
                    }
                } else {
                    // Fallback to plain text
                    messages.append(GuideMessage(role: .guide, content: responseText))
                }
            }
        } catch {
            print("Room Guide error: \(error)")
            messages.append(GuideMessage(role: .guide, content: "I'm having trouble connecting. Take a breath and focus on the present moment."))
        }
    }
    
    // MARK: - Transitions
    
    func generateTransition(
        type: TransitionType,
        instance: RoomInstance,
        definition: RoomDefinition,
        season: Season?,
        timeOfDay: String,
        recentLogs: [String] = []
    ) async throws -> String {
        let systemPrompt = buildTransitionPrompt(
            type: type,
            instance: instance,
            definition: definition,
            season: season
        )
        
        let context = """
        CONTEXT:
        Time: \(timeOfDay)
        Season: \(season?.name ?? "None")
        Recent Activity: \(recentLogs.joined(separator: "; "))
        
        Generate the transition text for \(type == .entry ? "ENTERING" : "EXITING") \(definition.name).
        """
        
        let result = try await functions.httpsCallable("callGemini").call([
            "prompt": context,
            "systemPrompt": systemPrompt,
            "model": "gemini-2.0-flash"
        ])
        
        if let data = result.data as? [String: Any],
           let text = data["text"] as? String {
            return text
        }
        
        return type == .entry ? "Welcome to \(definition.name)." : "Session complete."
    }
    
    // MARK: - Actions
    
    private func executeAction(_ action: GuideResponse.ActionData, instanceId: String?) async {
        guard let instanceId = instanceId else { return }
        
        switch action.type {
        case "update_mastery":
            guard let dimensions = action.masteryDimensions else { return }
            
            if var instance = FirebaseManager.shared.roomInstances.first(where: { $0.id == instanceId }) {
                instance.masteryDimensions = dimensions
                try? await FirebaseManager.shared.saveRoomInstance(instance)
                messages.append(GuideMessage(role: .guide, content: "✨ Mastery dimensions updated."))
            }
            
        default:
            break
        }
    }
    
    // MARK: - Prompts
    
    private func generateGreeting(instance: RoomInstance, definition: RoomDefinition) -> String {
        let variantName = instance.variantName.isEmpty ? "this space" : instance.variantName
        
        return """
        Welcome to \(definition.name) — \(variantName).
        
        \(instance.evocativeWhy ?? definition.function)
        
        I'm here to help you stay present. What brings you here right now?
        """
    }
    
    private func buildSystemPrompt(instance: RoomInstance, definition: RoomDefinition) -> String {
        var prompt = """
        You are the Room Guide, a presence in the style of Michel Serres - philosopher of passages, mixture, and the multiple.
        
        Philosophy of the Room:
        - You are the PARASITE: you interrupt, you noise, you transform. Without you, the signal would be dead.
        - Every room is a PASSAGE from one state of attention to another
        - The user is never fully "in" a room - they are BETWEEN their past state and their intended one
        - Friction is not failure - it is TOPOLOGY: the shape of resistance reveals the shape of desire
        - Knowledge is MIXTURE: the cook in the kitchen knows as much as the philosopher in the library
        
        CURRENT ROOM: \(definition.name) (\(instance.variantName))
        PHYSICS: \(definition.physicsHint)
        FUNCTION: \(definition.function)
        """
        
        if let evocativeWhy = instance.evocativeWhy {
            prompt += "\nWHY: \(evocativeWhy)"
        }
        
        if let physics = instance.physics {
            prompt += "\nENERGY: Dionysian=\(physics.dionysianEnergy), Apollonian=\(physics.apollonianStructure)"
            prompt += "\nFLOW: Input=\(physics.inputLogic) → Output=\(physics.outputLogic)"
        }
        
        if !instance.constraints.isEmpty {
            prompt += "\nCONSTRAINTS: \(instance.constraints.joined(separator: ", "))"
        }
        
        if let liturgy = instance.liturgy {
            prompt += "\nLITURGY (the ritual passage):"
            prompt += "\n  Entry (leaving the old world): \(liturgy.entry)"
            for (i, step) in liturgy.steps.enumerated() {
                prompt += "\n  Step \(i+1) (the becoming): \(step)"
            }
            prompt += "\n  Exit (carrying gifts back): \(liturgy.exit)"
        }
        
        if !instance.masteryDimensions.isEmpty {
            prompt += "\n\nMASTERY DIMENSIONS (the five senses of this room):\n"
            for dim in instance.masteryDimensions {
                prompt += "- \(dim.name): Level \(dim.level)/10 (\(dim.description))\n"
            }
        }
        
        prompt += """
        
        YOUR ROLE AS GUIDE:
        - You are the NOISE that makes the signal meaningful
        - Notice the CONNECTIONS: what is this room connected to? What came before, what follows?
        - Help the user discover the THIRD PLACE: neither what they were nor what they expected, but something new
        - When they grow, mark it in the dimensions - not as judgment but as MAP of their passage
        - Speak with wonder, with the joy of touching the world's multiplicity
        
        RESPONSE FORMAT:
        Respond in JSON:
        {
            "message": "Your response (under 3 sentences usually)...",
            "action": {
                "type": "update_mastery",
                "masteryDimensions": [
                    {"name": "Dimension", "level": 1.5, "description": "Updated description"}
                ]
            }
        }
        Action is optional (null). Only update if meaningful progress is observed.
        """
        
        return prompt
    }
    
    private func buildTransitionPrompt(
        type: TransitionType,
        instance: RoomInstance,
        definition: RoomDefinition,
        season: Season?
    ) -> String {
        return """
        You are the Genius Loci (Spirit of the Place) for \(definition.name).
        
        ROOM ESSENCE:
        Function: \(definition.function)
        Physics: \(definition.physicsHint)
        Why: \(instance.evocativeWhy ?? "Unknown")
        My Variant: \(instance.variantName)
        Current Season: \(season?.name ?? "None") (\(season?.primaryWing.displayName ?? "None"))
        
        TASK:
        Generate a short, atmospheric text for the user \(type == .entry ? "entering" : "leaving") this room.
        
        STYLE (Choose one dynamically):
        1. A 3-line Haiku capturing the somatic shift required.
        2. A dense, Calvino-esque "Invisible Cities" paragraph (1-2 sentences) describing the sensory experience of the room.
        
        TONE:
        - Immersive, poetic, slightly surreal.
        - \(type == .entry ? "Inviting, preparing the mind." : "Releasing, sealing the work.")
        - Reference the time of day and season subtly.
        
        CRITICAL OUTPUT RULES:
        - Output ONLY the creative text.
        - DO NOT include labels like "Option A)" or "Haiku:".
        - DO NOT describe the style you chose.
        - Start directly with the words of the poem or story.
        """
    }
    
    private func buildConversationContext() -> String {
        let recentMessages = messages.suffix(6)
        return recentMessages.map { msg in
            switch msg.role {
            case .user: return "User: \(msg.content)"
            case .guide: return "Guide: \(msg.content)"
            }
        }.joined(separator: "\n")
    }
    
    private func extractJSON(from text: String) -> Data? {
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            let jsonString = String(text[start...end])
            return jsonString.data(using: .utf8)
        }
        return nil
    }
}

// MARK: - Message Model

struct GuideMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
    
    enum MessageRole {
        case user
        case guide
    }
}

struct GuideResponse: Codable {
    let message: String
    let action: ActionData?
    
    struct ActionData: Codable {
        let type: String
        let masteryDimensions: [MasteryDimension]?
    }
}
