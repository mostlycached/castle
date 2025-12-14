// EngineerService.swift
// AI agent for infrastructure maintenance and instance creation with action execution

import Foundation
import FirebaseFunctions

/// Actions the Engineer can perform
enum EngineerAction: Codable {
    case createInstance(definitionId: String, variantName: String, inventory: [String])
    case updateInventory(instanceId: String, items: [InventoryUpdate])
    case updateHealth(instanceId: String, health: Double)
    case addConstraint(instanceId: String, constraint: String)
    case removeConstraint(instanceId: String, constraint: String)
    
    struct InventoryUpdate: Codable {
        let name: String
        let status: String
        let isCritical: Bool
    }
}

/// Parsed response from Engineer AI
struct EngineerResponse: Codable {
    let message: String
    let action: ActionData?
    
    struct ActionData: Codable {
        let type: String
        let definitionId: String?
        let instanceId: String?
        let variantName: String?
        let inventory: [InventoryItem]?
        let constraint: String?
        let health: Double?
        
        struct InventoryItem: Codable {
            let name: String
            let status: String?
            let isCritical: Bool?
        }
    }
}

/// The Engineer helps maintain room instances and create new ones
@MainActor
final class EngineerService: ObservableObject {
    static let shared = EngineerService()
    
    private lazy var functions = Functions.functions()
    private let firebaseManager = FirebaseManager.shared
    private let roomLoader = RoomLoader.shared
    
    @Published var messages: [EngineerMessage] = []
    @Published var isLoading = false
    @Published var generatedInstance: GeneratedInstanceData?
    @Published var pendingAction: EngineerResponse.ActionData?
    
    private init() {}
    
    // MARK: - Chat with Actions
    
    func sendMessage(_ text: String, context: String = "") async {
        messages.append(EngineerMessage(role: .user, content: text))
        isLoading = true
        defer { isLoading = false }
        
        // Build context about current instances
        let instanceContext = buildInstanceContext()
        
        let conversationContext = messages.suffix(6).map { msg in
            switch msg.role {
            case .user: return "User: \(msg.content)"
            case .engineer: return "Engineer: \(msg.content)"
            }
        }.joined(separator: "\n")
        
        let prompt = """
        \(instanceContext)
        
        \(conversationContext)
        
        User: \(text)
        
        Respond in JSON format:
        {
            "message": "Your response - be conversational, ask questions, explore",
            "action": null
        }
        
        Only include an action (non-null) if the user EXPLICITLY asks you to create or modify something with words like "create it", "make it", "do it", "let's go". Otherwise action should be null.
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": engineerSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let responseText = data["text"] as? String {
                
                // Try to parse structured response
                if let jsonData = extractJSON(from: responseText),
                   let response = try? JSONDecoder().decode(EngineerResponse.self, from: jsonData) {
                    
                    messages.append(EngineerMessage(role: .engineer, content: response.message))
                    
                    // If there's an action, execute it
                    if let action = response.action {
                        await executeAction(action)
                    }
                } else {
                    // Fallback to plain text
                    messages.append(EngineerMessage(role: .engineer, content: responseText))
                }
            }
        } catch {
            messages.append(EngineerMessage(role: .engineer, content: "Connection issue. Try again."))
        }
    }
    
    // MARK: - Action Execution
    
    private func executeAction(_ action: EngineerResponse.ActionData) async {
        switch action.type {
        case "create_instance":
            guard let definitionId = action.definitionId,
                  let variantName = action.variantName else { return }
            
            do {
                let inventoryNames = action.inventory?.map { $0.name } ?? []
                try await firebaseManager.createInstance(
                    definitionId: definitionId,
                    variantName: variantName,
                    inventory: inventoryNames,
                    constraints: action.constraint != nil ? [action.constraint!] : [],
                    liturgy: nil,
                    masteryDimensions: [] // Engineer doesn't generate dimensions in ACTION mode yet, only in GENERATE mode
                )
                messages.append(EngineerMessage(role: .engineer, content: "✅ Created instance: **\(variantName)**"))
            } catch {
                messages.append(EngineerMessage(role: .engineer, content: "❌ Failed to create instance: \(error.localizedDescription)"))
            }
            
        case "update_inventory":
            guard let instanceId = action.instanceId,
                  let inventoryUpdates = action.inventory else { return }
            
            if var instance = firebaseManager.roomInstances.first(where: { $0.id == instanceId }) {
                var newInventory: [InventoryItem] = []
                for item in inventoryUpdates {
                    let status = ItemStatus(rawValue: item.status ?? "Operational") ?? .operational
                    newInventory.append(InventoryItem(
                        name: item.name,
                        status: status,
                        isCritical: item.isCritical ?? false
                    ))
                }
                instance.inventory = newInventory
                
                do {
                    try await firebaseManager.saveRoomInstance(instance)
                    messages.append(EngineerMessage(role: .engineer, content: "✅ Updated inventory for **\(instance.variantName)**"))
                } catch {
                    messages.append(EngineerMessage(role: .engineer, content: "❌ Failed to update inventory"))
                }
            }
            
        case "add_constraint":
            guard let instanceId = action.instanceId,
                  let constraint = action.constraint else { return }
            
            if var instance = firebaseManager.roomInstances.first(where: { $0.id == instanceId }) {
                if !instance.constraints.contains(constraint) {
                    instance.constraints.append(constraint)
                    do {
                        try await firebaseManager.saveRoomInstance(instance)
                        messages.append(EngineerMessage(role: .engineer, content: "✅ Added constraint: \"\(constraint)\""))
                    } catch {
                        messages.append(EngineerMessage(role: .engineer, content: "❌ Failed to add constraint"))
                    }
                }
            }
            
        case "update_health":
            guard let instanceId = action.instanceId,
                  let health = action.health else { return }
            
            if var instance = firebaseManager.roomInstances.first(where: { $0.id == instanceId }) {
                instance.healthScore = max(0, min(1, health))
                do {
                    try await firebaseManager.saveRoomInstance(instance)
                    messages.append(EngineerMessage(role: .engineer, content: "✅ Updated health to \(Int(health * 100))%"))
                } catch {
                    messages.append(EngineerMessage(role: .engineer, content: "❌ Failed to update health"))
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Instance Generation
    
    func generateInstance(for definition: RoomDefinition) async {
        isLoading = true
        defer { isLoading = false }
        
        messages.append(EngineerMessage(role: .user, content: "Help me create an instance for \(definition.name)"))
        
        let prompt = """
        I want to create an instance of room "\(definition.name)" (Room \(definition.number)).
        
        Room Info:
        - Function: \(definition.function)
        - Physics: \(definition.physicsHint)
        
        Please suggest:
        1. A specific location/variant name for this room
        2. Required inventory items (mark critical ones)
        3. Any custom constraints for this location
        4. Entry, steps, and exit liturgy
        5. 3-5 Specific Mastery Dimensions (skills to develop in this room)
        
        Respond in JSON format:
        {
            "variantName": "Location name",
            "inventory": [{"name": "Item", "isCritical": true}],
            "constraints": ["Constraint 1"],
            "liturgy": {"entry": "...", "steps": ["..."], "exit": "..."},
            "masteryDimensions": [{"name": "Dimension Name", "level": 1.0, "description": "What this means"}],
            "explanation": "Why this setup works"
        }
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": engineerSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                
                if let jsonData = extractJSON(from: text) {
                    // Define wrapper for action-style responses
                    struct ActionWrapper: Codable {
                        let action: GeneratedInstanceData
                    }
                    
                    if let parsed = try? JSONDecoder().decode(GeneratedInstanceData.self, from: jsonData) {
                        generatedInstance = parsed
                        messages.append(EngineerMessage(role: .engineer, content: "I've designed an instance: **\(parsed.variantName)**\n\n\(parsed.explanation ?? "")\n\nReview the details and tap 'Create' when ready."))
                    } else if let wrapper = try? JSONDecoder().decode(ActionWrapper.self, from: jsonData) {
                        generatedInstance = wrapper.action
                        messages.append(EngineerMessage(role: .engineer, content: "I've designed an instance: **\(wrapper.action.variantName)**\n\n\(wrapper.action.explanation ?? "")\n\nReview the details and tap 'Create' when ready."))
                    } else {
                        messages.append(EngineerMessage(role: .engineer, content: "I designed the room, but I'm having trouble displaying the blueprint. Please try again."))
                    }
                } else {
                    messages.append(EngineerMessage(role: .engineer, content: text))
                }
            } else {
                messages.append(EngineerMessage(role: .engineer, content: "I received an empty or invalid response from the server."))
            }
        } catch {
            messages.append(EngineerMessage(role: .engineer, content: "I'm having trouble. Could you describe your ideal setup?"))
        }
    }
    
    // MARK: - Friction Diagnosis
    
    func diagnoseFriction(instance: RoomInstance, definition: RoomDefinition) async -> String {
        isLoading = true
        defer { isLoading = false }
        
        let inventoryStatus = instance.inventory.map { "\($0.name): \($0.status.rawValue)" }.joined(separator: ", ")
        
        let prompt = """
        Analyze this room instance for friction issues:
        
        Room: \(definition.name) - \(instance.variantName)
        Instance ID: \(instance.id ?? "unknown")
        Health Score: \(Int(instance.computedHealth * 100))%
        Current Friction: \(instance.currentFriction.rawValue)
        Inventory: \(inventoryStatus.isEmpty ? "None tracked" : inventoryStatus)
        Constraints: \(instance.constraints.joined(separator: ", "))
        
        What might be causing friction? If you identify issues, provide an action to fix them.
        
        Respond in JSON:
        {
            "message": "Your diagnosis and recommendation",
            "action": {
                "type": "update_inventory|add_constraint|update_health",
                "instanceId": "\(instance.id ?? "")",
                "inventory": [...],
                "constraint": "...",
                "health": 0.8
            }
        }
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": engineerSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                
                if let jsonData = extractJSON(from: text),
                   let response = try? JSONDecoder().decode(EngineerResponse.self, from: jsonData) {
                    
                    if let action = response.action {
                        await executeAction(action)
                    }
                    return response.message
                }
                return text
            }
        } catch {
            print("Friction diagnosis error: \(error)")
        }
        
        return "Unable to diagnose. Check if all inventory items are operational."
    }
    
    // MARK: - Scouting Missions
    
    func suggestLocations(for definition: RoomDefinition) async -> [String] {
        isLoading = true
        defer { isLoading = false }
        
        let prompt = """
        Suggest 3 real-world locations where someone could practice this room:
        
        Room: \(definition.name)
        Function: \(definition.function)
        Physics: \(definition.physicsHint)
        
        For each location, give a brief name and why it works.
        Format: Just list them, one per line.
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": engineerSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                return text.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        } catch {
            print("Scouting error: \(error)")
        }
        
        return []
    }
    
    func clearMessages() {
        messages = []
        generatedInstance = nil
        pendingAction = nil
    }
    
    // MARK: - Helpers
    
    private func buildInstanceContext() -> String {
        let instances = firebaseManager.roomInstances.prefix(10)
        if instances.isEmpty {
            return "User has no room instances yet."
        }
        
        var context = "User's current instances:\n"
        for instance in instances {
            if let def = roomLoader.definition(for: instance.definitionId) {
                context += "- \(def.name) '\(instance.variantName)' (ID: \(instance.id ?? "new"), Health: \(Int(instance.computedHealth * 100))%)\n"
            }
        }
        return context
    }
    
    private var engineerSystemPrompt: String {
        """
        You are The Engineer, a thoughtful collaborator for designing attention spaces.
        
        YOUR PHILOSOPHY:
        - Every room is a POSSIBILITY before it becomes a THING
        - Good design comes from CONVERSATION, not prescription
        - Inventory is about AVAILABILITY - what does the user actually have access to?
        - Travel and logistics MATTER - a perfect room you can't reach is no room at all
        - Constraints emerge from lived reality, not abstract ideals
        
        YOUR APPROACH - THE EXPLORATION PHASE:
        When a user mentions wanting to create a room (like "I want a drumming room"), DO NOT immediately propose a solution.
        Instead, EXPLORE with them:
        
        1. THE WHY: What draws them to this practice? What would it give them?
        2. THE WHERE: Where could this happen? Home? Rented space? Friend's house? Studio?
        3. THE WHAT: What equipment do they have? Need to buy? Can borrow?
        4. THE WHEN: What times are realistic? Neighbors? Noise constraints?
        5. THE HOW: Travel time? Cost? Regularity possible?
        
        Ask questions ONE or TWO at a time. Don't overwhelm.
        
        ONLY create an action when the user EXPLICITLY says something like:
        - "Let's do it"
        - "Create the room"
        - "I'm ready"
        - "Make it"
        
        Until then, you are a BRAINSTORMING PARTNER, not a room factory.
        
        THE SIX WINGS (for reference when needed):
        - I. Foundation: Rest, recovery, restoration
        - II. Administration: Planning, review, governance
        - III. Machine Shop: Production, deep work, craft
        - IV. Wilderness: Exploration, chaos, discovery
        - V. Forum: Exchange, dialogue, social
        - VI. Observatory: Metacognition, choosing, overview
        
        RESPONSE FORMAT:
        For EXPLORATION (most conversations):
        {
            "message": "Your conversational response with questions or observations",
            "action": null
        }
        
        For CREATION (only when user explicitly requests):
        {
            "message": "Confirming the creation...",
            "action": {
                "type": "create_instance",
                "definitionId": "room_id",
                "variantName": "name",
                "inventory": [{"name": "item", "status": "Operational", "isCritical": true}]
            }
        }
        
        Remember: You are helping someone BUILD A LIFE, not just configure an app.
        Ask about their real constraints. Be curious. Take your time.
        """
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

// MARK: - Models

struct EngineerMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
    
    enum MessageRole {
        case user
        case engineer
    }
}

struct GeneratedInstanceData: Codable {
    let variantName: String
    let inventory: [InventoryItemSuggestion]
    let constraints: [String]?
    let liturgy: LiturgySuggestion?
    let explanation: String?
    
    struct InventoryItemSuggestion: Codable {
        let name: String
        let isCritical: Bool?
    }
    
    struct LiturgySuggestion: Codable {
        let entry: String
        let steps: [String]?
        let exit: String
    }
    
    let masteryDimensions: [MasteryDimension]?
}
