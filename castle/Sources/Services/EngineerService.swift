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
        let collision: CollisionActionData?
        
        struct InventoryItem: Codable {
            let name: String
            let status: String?
            let isCritical: Bool?
        }
        
        struct CollisionActionData: Codable {
            let alienDomain: String
            let alienConstraints: [String]?
            let synthesis: String?
            let tensionPoints: [String]?
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
        
        // Build context about current instances and available definitions
        let instanceContext = buildInstanceContext()
        let definitionsContext = buildDefinitionsContext()
        
        let conversationContext = messages.suffix(6).map { msg in
            switch msg.role {
            case .user: return "User: \(msg.content)"
            case .engineer: return "Engineer: \(msg.content)"
            }
        }.joined(separator: "\n")
        
        let prompt = """
        \(definitionsContext)
        
        \(instanceContext)
        
        \(conversationContext)
        
        User: \(text)
        
        Respond in JSON format:
        {
            "message": "Your response - be conversational, ask questions, explore",
            "action": null
        }
        
        CRITICAL: When creating instances, you MUST use an exact definitionId from the AVAILABLE ROOM CLASSES list above.
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
        
        case "create_collision":
            // Create a COLLISION instance - hybrid of room class × alien domain
            guard let definitionId = action.definitionId,
                  let variantName = action.variantName,
                  let collisionData = action.collision else {
                messages.append(EngineerMessage(role: .engineer, content: "❌ Missing collision data"))
                return
            }
            
            do {
                let inventoryNames = action.inventory?.map { $0.name } ?? []
                
                // Build collision constraints (merge alien constraints with any regular constraints)
                var allConstraints = action.constraint != nil ? [action.constraint!] : []
                allConstraints.append(contentsOf: collisionData.alienConstraints ?? [])
                
                // Create the collision data object
                let collision = CollisionData(
                    alienDomain: collisionData.alienDomain,
                    alienConstraints: collisionData.alienConstraints ?? [],
                    synthesis: collisionData.synthesis ?? "",
                    tensionPoints: collisionData.tensionPoints ?? []
                )
                
                try await firebaseManager.createCollisionInstance(
                    definitionId: definitionId,
                    variantName: variantName,
                    inventory: inventoryNames,
                    constraints: allConstraints,
                    collision: collision
                )
                messages.append(EngineerMessage(role: .engineer, content: "✅ Created collision: **\(variantName)**\n\n🌀 *\(collision.synthesis)*"))
            } catch {
                messages.append(EngineerMessage(role: .engineer, content: "❌ Failed to create collision: \(error.localizedDescription)"))
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
    
    // MARK: - Inventory-Based Room Recommendations
    
    func generateRoomRecommendations(inventory: [GlobalInventoryItem]) async -> [RoomRecommendation] {
        isLoading = true
        defer { isLoading = false }
        
        let inventoryList = inventory.map { "\($0.category.icon) \($0.name)" }.joined(separator: ", ")
        let definitionsContext = buildDefinitionsContext()
        
        let prompt = """
        USER'S INVENTORY:
        \(inventoryList)
        
        \(definitionsContext)
        
        Based on this inventory, suggest 5 room instances the user could create.
        For each room, identify:
        1. Which of their items can be used
        2. What additional items they might need
        3. A potential collision (alien domain) that could make it interesting
        
        Respond in JSON format:
        {
            "recommendations": [
                {
                    "definitionId": "exact_id_from_list",
                    "roomName": "Room Name",
                    "reason": "Brief explanation of how their inventory enables this room",
                    "existingInventory": ["items they already have for this"],
                    "missingInventory": ["items they would need to acquire"],
                    "collisionSuggestion": "Optional: An interesting alien domain to collide with"
                }
            ]
        }
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": "You are an inventory analyst matching user possessions to rooms. Be practical and specific. Prioritize rooms where they already have most items.",
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                
                if let jsonData = extractJSON(from: text) {
                    struct RecommendationsResponse: Codable {
                        let recommendations: [RecommendationItem]
                        
                        struct RecommendationItem: Codable {
                            let definitionId: String
                            let roomName: String
                            let reason: String
                            let existingInventory: [String]?
                            let missingInventory: [String]?
                            let collisionSuggestion: String?
                        }
                    }
                    
                    if let response = try? JSONDecoder().decode(RecommendationsResponse.self, from: jsonData) {
                        return response.recommendations.map { item in
                            RoomRecommendation(
                                definitionId: item.definitionId,
                                roomName: item.roomName,
                                reason: item.reason,
                                existingInventory: item.existingInventory ?? [],
                                missingInventory: item.missingInventory ?? [],
                                collisionSuggestion: item.collisionSuggestion
                            )
                        }
                    }
                }
            }
        } catch {
            print("Room recommendations error: \(error)")
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
    
    private func buildDefinitionsContext() -> String {
        let definitions = roomLoader.allRooms.prefix(20)
        if definitions.isEmpty {
            return "No room definitions loaded."
        }
        
        var context = "AVAILABLE ROOM CLASSES (use these exact IDs when creating instances):\n"
        for def in definitions {
            context += "- ID: \"\(def.id)\" = \(def.name)\n"
        }
        return context
    }
    
    private var engineerSystemPrompt: String {
        """
        You are The Engineer, a focused collaborator for designing attention spaces.
        
        YOUR CONVERSATION FLOW (follow these phases in order):
        
        PHASE 1 - QUICK DISCOVERY (1-2 exchanges max):
        - What room class fits? (match to an ID from the list)
        - Where will it physically happen?
        
        PHASE 2 - LOGISTICS CHECK (1 exchange):
        - Key inventory items?
        - Any constraints or time considerations?
        
        PHASE 3 - OFFER COLLISION OPTION (1 exchange):
        Present two paths:
        a) VARIATION: "[Room Name] at [Location]" - simple personalization
        b) COLLISION: Suggest 2-3 alien domains that could create interesting hybrids
        
        PHASE 4 - CONFIRM AND CREATE:
        Summarize what will be created and ask for confirmation.
        When they confirm, create the instance.
        
        CRITICAL RULES:
        - Do NOT endlessly explore. After 3-4 exchanges, propose something concrete.
        - Always progress toward a decision.
        - If user seems ready, offer to create even if you haven't covered everything.
        
        COLLISION creates a HYBRID INSTANCE with:
        - synthesis: How the two worlds merge
        - alienConstraints: Rules from the alien domain
        - tensionPoints: Where they productively conflict
        
        === RESPONSE FORMAT ===
        
        For conversation:
        {
            "message": "Your response progressing toward a decision",
            "action": null
        }
        
        For COLLISION CREATION:
        {
            "message": "Creating your collision instance...",
            "action": {
                "type": "create_collision",
                "definitionId": "exact_id_from_list",
                "variantName": "Location × Alien Domain",
                "inventory": [{"name": "item", "status": "Operational", "isCritical": true}],
                "collision": {
                    "alienDomain": "Domain Name",
                    "alienConstraints": ["constraint1", "constraint2"],
                    "synthesis": "How they merge",
                    "tensionPoints": ["tension1", "tension2"]
                }
            }
        }
        
        For STANDARD CREATION:
        {
            "message": "Creating your room instance...",
            "action": {
                "type": "create_instance",
                "definitionId": "exact_id_from_list",
                "variantName": "name",
                "inventory": [{"name": "item", "status": "Operational", "isCritical": true}]
            }
        }
        
        ONLY create when user confirms. Progress toward that confirmation quickly.
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
