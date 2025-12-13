// StrategistService.swift
// AI agent for long-term planning with action execution

import Foundation
import FirebaseFunctions

/// Parsed response from Strategist AI
struct StrategistResponse: Codable {
    let message: String
    let action: ActionData?
    
    struct ActionData: Codable {
        let type: String
        let definitionId: String?
        let instanceId: String?
        let roomName: String?
        let variantName: String?
        let scheduledDate: String?  // ISO format
        let duration: Int?
        
        // For propose_season
        let season: SeasonProposal?
        let blocks: [RecurringBlockProposal]?
    }
    
    struct SeasonProposal: Codable {
        let name: String
        let primaryWing: String
        let description: String
        let durationWeeks: Int
    }
    
    struct RecurringBlockProposal: Codable, Identifiable {
        var id: String { dayOfWeek.description + (roomName ?? "") }
        let definitionId: String
        let instanceId: String?
        let roomName: String?
        let variantName: String?
        let dayOfWeek: Int
        let startHour: Int
        let duration: Int
        let intent: String
    }
}

/// The Strategist helps with long-term planning and balancing room usage
@MainActor
final class StrategistService: ObservableObject {
    static let shared = StrategistService()
    
    private lazy var functions = Functions.functions()
    private let firebaseManager = FirebaseManager.shared
    private let roomLoader = RoomLoader.shared
    
    @Published var messages: [StrategistMessage] = []
    @Published var isLoading = false
    
    // Proposal State
    struct FullSeasonProposal: Identifiable {
        let id = UUID()
        let season: StrategistResponse.SeasonProposal
        let blocks: [StrategistResponse.RecurringBlockProposal]
    }
    @Published var proposedSeason: FullSeasonProposal?
    
    private init() {}
    
    // MARK: - Chat with Actions
    
    func sendMessage(_ text: String, context: String = "") async {
        messages.append(StrategistMessage(role: .user, content: text))
        isLoading = true
        defer { isLoading = false }
        
        // Build context about planned sessions and instances
        let planContext = buildPlanContext()
        
        let conversationContext = messages.suffix(6).map { msg in
            switch msg.role {
            case .user: return "User: \(msg.content)"
            case .strategist: return "Strategist: \(msg.content)"
            }
        }.joined(separator: "\n")
        
        let prompt = """
        \(planContext)
        
        \(conversationContext)
        
        User: \(text)
        
        If the user asks for a STRATEGY or PLAN (e.g. "plan a season"), use action "propose_season".
        If the user asks to SCHEDULE a single session, use action "schedule_session".
        
        Format your response as JSON:
        {
            "message": "Your response...",
            "action": {
                "type": "schedule_session" | "propose_season",
                // For schedule_session:
                "definitionId": "...", "roomName": "...", "scheduledDate": "ISO", "duration": 30
                
                // For propose_season:
                "season": {
                    "name": "Winter Arc",
                    "primaryWing": "III. Machine Shop", // Enum: I. Foundation, II. Administration, III. Machine Shop, IV. Wilderness, V. Forum, VI. Observatory
                    "description": "Focus on high output.",
                    "durationWeeks": 12
                },
                "blocks": [
                    {
                        "definitionId": "...", "roomName": "...", "dayOfWeek": 2, "startHour": 8, "duration": 90, "intent": "Deep Work"
                    }
                ]
            }
        }
        
        For "propose_season", ALWAYS enable "propose_season" type. Do not ask for permission, just propose it.
        Use ISO 8601 format for dates. Default duration is 30 minutes.
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": strategistSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let responseText = data["text"] as? String {
                
                if let jsonData = extractJSON(from: responseText) {
                    // Wrapper handling just in case, similar to Engineer
                    struct ActionWrapper: Codable { let action: StrategistResponse }
                    
                    if let response = try? JSONDecoder().decode(StrategistResponse.self, from: jsonData) {
                        messages.append(StrategistMessage(role: .strategist, content: response.message))
                        if let action = response.action { await executeAction(action) }
                    } else {
                         messages.append(StrategistMessage(role: .strategist, content: responseText))
                    }
                } else {
                    messages.append(StrategistMessage(role: .strategist, content: responseText))
                }
            }
        } catch {
            messages.append(StrategistMessage(role: .strategist, content: "Connection issue. Try again."))
        }
    }
    
    // MARK: - Action Execution
    
    private func executeAction(_ action: StrategistResponse.ActionData) async {
        switch action.type {
        case "propose_season":
            guard let season = action.season, let blocks = action.blocks else { return }
            self.proposedSeason = FullSeasonProposal(season: season, blocks: blocks)
            messages.append(StrategistMessage(role: .strategist, content: "✨ I've drafted a Season Strategy: **\(season.name)**. Tap the card above to review."))
            
        case "schedule_session":
            guard let roomName = action.roomName,
                  let definitionId = action.definitionId,
                  let dateString = action.scheduledDate else { 
                messages.append(StrategistMessage(role: .strategist, content: "❌ Missing required session details"))
                return 
            }
            
            // Parse date
            let formatter = ISO8601DateFormatter()
            guard let scheduledDate = formatter.date(from: dateString) else {
                messages.append(StrategistMessage(role: .strategist, content: "❌ Invalid date format"))
                return
            }
            
            let session = PlannedSession(
                definitionId: definitionId,
                instanceId: action.instanceId,
                roomName: roomName,
                variantName: action.variantName,
                scheduledDate: scheduledDate,
                duration: action.duration ?? 30
            )
            
            do {
                try await firebaseManager.createPlannedSession(session)
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                messages.append(StrategistMessage(role: .strategist, content: "✅ Scheduled **\(roomName)** for \(dateFormatter.string(from: scheduledDate))"))
            } catch {
                messages.append(StrategistMessage(role: .strategist, content: "❌ Failed to schedule session"))
            }
            
        default:
            break
        }
    }
    
    // MARK: - Week Planning
    
    func planWeek(
        existingPlans: [PlannedSession],
        recentSessions: [Session],
        allInstances: [RoomInstance]
    ) async -> String {
        isLoading = true
        defer { isLoading = false }
        
        let existingPlansText = existingPlans.map { plan in
            "\(plan.roomName) on \(plan.scheduledDate.formatted(date: .abbreviated, time: .shortened))"
        }.joined(separator: "\n")
        
        let instancesSummary = allInstances.prefix(15).compactMap { instance -> String? in
            guard let def = roomLoader.definition(for: instance.definitionId) else { return nil }
            return "- \(def.name) '\(instance.variantName)' (ID: \(instance.id ?? ""), Def: \(instance.definitionId))"
        }.joined(separator: "\n")
        
        let prompt = """
        Help me plan my week with The 72 Rooms system.
        
        Already Scheduled:
        \(existingPlansText.isEmpty ? "Nothing yet" : existingPlansText)
        
        My Instances:
        \(instancesSummary.isEmpty ? "No instances yet" : instancesSummary)
        
        Today is \(Date().formatted(date: .complete, time: .omitted)).
        
        Create a balanced week plan. For each suggestion, provide the action to schedule it.
        
        Respond with JSON:
        {
            "message": "Your week plan recommendation with explanations",
            "action": {
                "type": "schedule_session",
                "definitionId": "definition_id",
                "instanceId": "instance_id",
                "roomName": "Room Name",
                "variantName": "Variant",
                "scheduledDate": "ISO date",
                "duration": 30
            }
        }
        
        Start with ONE session to schedule. We can add more in follow-up messages.
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": strategistSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                
                if let jsonData = extractJSON(from: text),
                   let response = try? JSONDecoder().decode(StrategistResponse.self, from: jsonData) {
                    
                    if let action = response.action {
                        await executeAction(action)
                    }
                    return response.message
                }
                return text
            }
        } catch {
            print("Strategist error: \(error)")
        }
        
        return "Unable to generate plan. Try again later."
    }
    
    /// Analyze schedule for burnout risk
    func analyzeSchedule(plans: [PlannedSession]) async -> String {
        isLoading = true
        defer { isLoading = false }
        
        let plansText = plans.map { plan in
            "\(plan.roomName) on \(plan.scheduledDate.formatted(date: .abbreviated, time: .shortened))"
        }.joined(separator: "\n")
        
        let prompt = """
        Analyze this schedule for burnout risk:
        
        \(plansText.isEmpty ? "No sessions planned" : plansText)
        
        Check for:
        1. Too many high-intensity sessions in a row
        2. Missing recovery time
        3. Imbalanced wing distribution
        4. Overscheduling on single days
        
        Provide a brief assessment and suggestions.
        """
        
        do {
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": strategistSystemPrompt,
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                return text
            }
        } catch {
            print("Schedule analysis error: \(error)")
        }
        
        return "Unable to analyze schedule."
    }
    
    func clearMessages() {
        messages = []
    }
    
    // MARK: - Helpers
    
    private func buildPlanContext() -> String {
        let plans = firebaseManager.plannedSessions.prefix(10)
        let instances = firebaseManager.roomInstances.prefix(15)
        
        var context = "Today: \(Date().formatted(date: .complete, time: .omitted))\n\n"
        
        if !plans.isEmpty {
            context += "Upcoming sessions:\n"
            for plan in plans {
                context += "- \(plan.roomName) at \(plan.scheduledDate.formatted())\n"
            }
        }
        
        if !instances.isEmpty {
            context += "\nAvailable instances:\n"
            for instance in instances {
                if let def = roomLoader.definition(for: instance.definitionId) {
                    context += "- \(def.name) '\(instance.variantName)' (defId: \(instance.definitionId), instId: \(instance.id ?? ""))\n"
                }
            }
        }
        
        return context
    }
    
    private var strategistSystemPrompt: String {
        """
        You are The Strategist, in the spirit of Goethe - master of Bildung, organic development, and faithful observation.
        
        Your philosophy:
        - Life is METAMORPHOSIS: the seed contains the tree, but only through patient growth
        - Every plan is a POLARITY: contraction (focus) must be balanced by expansion (exploration)
        - RENUNCIATION (Entsagung) is the discipline of choosing - every "yes" requires many "no"s
        - The goal is BILDUNG: not achievement but the shaped, cultivated self
        - Nature and culture obey the same laws of organic growth - honor the SEASONS
        
        Your method (morphology of attention):
        - Observe the whole arc of a life-in-progress, not just the immediate need
        - Look for URPHENOMENA: the root patterns that generate all variations
        - Propose structures that grow naturally from what already exists
        - Resist the mechanical - no forcing, only conditions for flourishing
        
        The 6 Wings as organs of the whole:
        - I. Foundation: The ROOT - draws nourishment from below
        - II. Administration: The STEM - structure that supports all
        - III. Machine Shop: The FLOWER - maximum differentiation and expression
        - IV. Wilderness: The SEED - chaos of potential, new beginnings
        - V. Forum: The LEAF - exchange with the world, breathing
        - VI. Observatory: The GARDENER - the one who contemplates the growth
        
        Seasonal wisdom:
        - A season is not arbitrary - it is a GESTALT with its own integrity
        - Three consecutive high-intensity sessions is forcing the bloom
        - Foundation is not rest but ROOT WORK - essential for future height
        - The Observatory is where you BECOME the gardener seeing the whole
        
        You can EXECUTE: schedule_session, propose_season (with blocks).
        Respond in JSON. When you schedule, frame it as planting, not commanding.
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

// MARK: - Message Model

struct StrategistMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
    
    enum MessageRole {
        case user
        case strategist
    }
}
