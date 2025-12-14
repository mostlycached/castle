// FirebaseManager.swift
// Singleton for Firebase Auth and Firestore operations

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import FirebaseFunctions

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private var db: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }
    
    private var auth: Auth? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth()
    }
    
    @Published var isAuthenticated = false
    @Published var roomInstances: [RoomInstance] = []
    @Published var globalInventory: [GlobalInventoryItem] = []
    
    private init() {
        if FirebaseApp.app() != nil {
            setupAuthStateListener()
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        guard let auth = auth else { return }
        
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if user != nil {
                    await self?.fetchRoomInstances()
                    await self?.fetchGlobalInventory()
                }
            }
        }
    }
    
    func signInAnonymously() async {
        guard let auth = auth else { return }
        do {
            try await auth.signInAnonymously()
        } catch {
            print("Auth error: \(error)")
        }
    }
    
    var currentUserId: String? {
        auth?.currentUser?.uid
    }
    
    // MARK: - Room Instance Operations
    
    func fetchRoomInstances() async {
        guard let db = db, let uid = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("rooms")
                .getDocuments()
            
            roomInstances = snapshot.documents.compactMap { doc in
                var instance = try? doc.data(as: RoomInstance.self)
                instance?.id = doc.documentID
                return instance
            }
        } catch {
            print("Error fetching rooms: \(error)")
        }
    }
    
    // MARK: - Global Inventory Operations
    
    func fetchGlobalInventory() async {
        guard let db = db, let uid = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("inventory")
                .order(by: "addedAt", descending: true)
                .getDocuments()
            
            globalInventory = snapshot.documents.compactMap { doc in
                var item = try? doc.data(as: GlobalInventoryItem.self)
                item?.id = doc.documentID
                return item
            }
        } catch {
            print("Error fetching inventory: \(error)")
        }
    }
    
    func addInventoryItem(_ item: GlobalInventoryItem) async throws {
        guard let db = db, let uid = currentUserId else { return }
        
        _ = try db.collection("users")
            .document(uid)
            .collection("inventory")
            .addDocument(from: item)
        
        await fetchGlobalInventory()
    }
    
    func deleteInventoryItem(_ itemId: String) async throws {
        guard let db = db, let uid = currentUserId else { return }
        
        try await db.collection("users")
            .document(uid)
            .collection("inventory")
            .document(itemId)
            .delete()
        
        await fetchGlobalInventory()
    }
    
    func saveRoomInstance(_ instance: RoomInstance) async throws {
        guard let db = db, let uid = currentUserId else { return }
        
        if let id = instance.id {
            try db.collection("users")
                .document(uid)
                .collection("rooms")
                .document(id)
                .setData(from: instance, merge: true)
        } else {
            _ = try db.collection("users")
                .document(uid)
                .collection("rooms")
                .addDocument(from: instance)
        }
        
        await fetchRoomInstances()
    }
    
    func activateRoom(_ instance: RoomInstance) async throws {
        // Deactivate all other rooms first
        for var room in roomInstances where room.isActive {
            room.isActive = false
            try await saveRoomInstance(room)
        }
        
        // Activate the selected room
        var activeRoom = instance
        activeRoom.isActive = true
        try await saveRoomInstance(activeRoom)
    }
    
    /// Get all instances for a given room definition (supports multiple instances per class)
    func instances(for definitionId: String) -> [RoomInstance] {
        roomInstances.filter { $0.definitionId == definitionId }
    }
    
    /// Get first instance for a definition (backwards compatibility)
    func instance(for definitionId: String) -> RoomInstance? {
        roomInstances.first { $0.definitionId == definitionId }
    }
    
    /// Delete a room instance
    func deleteInstance(_ instance: RoomInstance) async throws {
        guard let db = db, let uid = currentUserId, let id = instance.id else { return }
        
        try await db.collection("users")
            .document(uid)
            .collection("rooms")
            .document(id)
            .delete()
        
        await fetchRoomInstances()
    }
    
    var activeRoom: RoomInstance? {
        roomInstances.first { $0.isActive }
    }
    
    // MARK: - Seeding
    
    private lazy var functions = Functions.functions()
    
    /// Seed room instances from Cloud Function
    func seedRooms() async throws {
        let result = try await functions.httpsCallable("seedRooms").call()
        
        if let data = result.data as? [String: Any],
           let message = data["message"] as? String {
            print("Seeding result: \(message)")
        }
        
        // Refresh room instances after seeding
        await fetchRoomInstances()
    }
    
    /// Generate a single track for a room instance via Cloud Function
    /// The cloud function fetches the album concept and uses its prompts directly
    func generateTrack(for instance: RoomInstance, trackNumber: Int) async throws {
        guard let instanceId = instance.id else { 
            throw NSError(domain: "FirebaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Instance has no ID"])
        }
        guard currentUserId != nil else {
            throw NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let result = try await functions.httpsCallable("generateTrack").call([
            "instanceId": instanceId,
            "trackNumber": trackNumber
        ])
        
        if let data = result.data as? [String: Any],
           let message = data["message"] as? String {
            print("Track generation: \(message)")
        }
        
        // Refresh to get updated playlist
        await fetchRoomInstances()
    }
    
    /// Generate album concept using Gemini for diverse track descriptions
    func generateAlbumConcept(for instance: RoomInstance, roomName: String, context: MusicContext) async throws {
        guard let instanceId = instance.id else { 
            throw NSError(domain: "FirebaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Instance has no ID"])
        }
        guard currentUserId != nil else {
            throw NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let contextDict: [String: Any] = [
            "scene_setting": context.sceneSetting.rawValue,
            "narrative_arc": context.narrativeArc ?? "",
            "somatic_elements": context.somaticElements,
            "location_inspiration": context.locationInspiration,
            "instruments": context.instruments,
            "mood": context.mood,
            "tempo": context.tempo,
            "found_sounds": context.foundSounds
        ]
        
        let result = try await functions.httpsCallable("generateAlbumConcept").call([
            "instanceId": instanceId,
            "roomName": roomName,
            "musicContext": contextDict
        ])
        
        if let data = result.data as? [String: Any],
           let message = data["message"] as? String {
            print("Album concept: \(message)")
        }
        
        // Refresh to get updated album concept
        await fetchRoomInstances()
    }
    
    /// Update a room instance with downloaded track info
    func updatePlaylistDownload(_ instance: RoomInstance, tracks: [RoomTrack]) async throws {
        var updated = instance
        updated.playlist = tracks
        try await saveRoomInstance(updated)
    }
    
    /// Delete playlist from a room instance
    func deletePlaylist(_ instance: RoomInstance) async throws {
        guard let db = db, let uid = currentUserId, let instanceId = instance.id else { return }
        
        // Use updateData to explicitly delete fields (merge: true won't work with nil values)
        try await db.collection("users")
            .document(uid)
            .collection("rooms")
            .document(instanceId)
            .updateData([
                "playlist": FieldValue.delete(),
                "playlist_generated_at": FieldValue.delete(),
                "music_context": FieldValue.delete()
            ])
        
        print("🗑️ Firebase updateData completed")
        await fetchRoomInstances()
        print("🗑️ fetchRoomInstances completed, count: \(roomInstances.count)")
    }
    
    /// Add observation to an instance
    func addObservation(_ text: String, to instance: RoomInstance) async throws {
        var updated = instance
        updated.observations.append(text)
        try await saveRoomInstance(updated)
    }
    
    /// Generate narrative prose for a room instance using LLM
    func generateNarrative(for instance: RoomInstance, definition: RoomDefinition) async throws {
        guard let instanceId = instance.id else { return }
        
        let prompt = """
        Write a ~250-word evocative prose narrative for this room.
        
        ROOM: \(definition.name) (Room \(definition.number))
        FUNCTION: \(definition.function)
        PHYSICS: \(definition.physicsHint)
        ARCHETYPE: \(definition.archetype ?? "N/A")
        VARIANT: \(instance.variantName.isEmpty ? "Default" : instance.variantName)
        EVOCATIVE: \(definition.evocativeDescription ?? "N/A")
        
        STYLE RULES:
        1. ROOM FRAME: Start by defining the physical limits of this space
        2. DIRECT ASSERTION: State what things ARE (never "not X, but Y")
        3. NO META-COMMENTARY: Don't explain logic, just state reality
        4. Active voice only, no onomatopoeia
        5. Derive consequences from the room's physical law
        
        ANALYSIS TO WEAVE IN:
        - Phenomenology: What is the experience of time/space here? What do inhabitants share?
        - Structure: What is valued? What are the unspoken rules? What behaviors are internalized?
        - System: What does this room DO? What is its core binary distinction?
        
        OUTPUT: Literary prose in the style of Italo Calvino's Invisible Cities.
        No headers, no bullet points, no explanations. Just the prose.
        """
        
        let result = try await functions.httpsCallable("callGemini").call([
            "prompt": prompt,
            "systemPrompt": "You are a literary author writing evocative, constraint-driven prose about spaces. Write like Calvino.",
            "model": "gemini-2.0-flash"
        ])
        
        if let data = result.data as? [String: Any],
           let text = data["text"] as? String {
            var updated = instance
            updated.narrative = text
            try await saveRoomInstance(updated)
            await fetchRoomInstances()
        }
    }
    
    /// Create a new instance of a room class directly
    func createInstance(
        definitionId: String,
        variantName: String,
        inventory: [String] = [],
        constraints: [String] = [],
        liturgy: RoomLiturgy? = nil,
        masteryDimensions: [MasteryDimension] = []
    ) async throws {
        // Create local instance model
        var instance = RoomInstance(
            definitionId: definitionId,
            variantName: variantName,
            requiredInventory: inventory,
            isActive: false,
            constraints: constraints,
            masteryDimensions: masteryDimensions
        )
        instance.liturgy = liturgy
        
        // Save to Firestore directly
        try await saveRoomInstance(instance)
        print("Created instance: \(variantName)")
    }
    
    /// Create a COLLISION instance - hybrid of room class × alien domain
    func createCollisionInstance(
        definitionId: String,
        variantName: String,
        inventory: [String] = [],
        constraints: [String] = [],
        collision: CollisionData
    ) async throws {
        // Create instance with collision data
        var instance = RoomInstance(
            definitionId: definitionId,
            variantName: variantName,
            requiredInventory: inventory,
            isActive: false,
            constraints: constraints
        )
        
        // Set the collision - this is what makes it a hybrid
        instance.collision = collision
        
        // Use the synthesis as the evocative why
        instance.evocativeWhy = collision.synthesis
        
        // Save to Firestore
        try await saveRoomInstance(instance)
        print("Created collision instance: \(variantName) (× \(collision.alienDomain))")
    }
    
    // MARK: - Sessions
    
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?
    
    /// Start a new session for an instance
    func startSession(instance: RoomInstance, roomName: String) async throws -> Session {
        guard let db = db, let uid = currentUserId, let instanceId = instance.id else {
            throw NSError(domain: "FirebaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let session = Session(
            instanceId: instanceId,
            definitionId: instance.definitionId,
            roomName: roomName,
            variantName: instance.variantName
        )
        
        let docRef = try db.collection("users")
            .document(uid)
            .collection("sessions")
            .addDocument(from: session)
        
        var savedSession = session
        savedSession.id = docRef.documentID
        
        activeSession = savedSession
        
        // Also activate the room instance
        try await activateRoom(instance)
        
        return savedSession
    }
    
    /// End the current session with observations
    func endSession(_ session: Session, observations: [String]) async throws {
        guard let db = db, let uid = currentUserId, let sessionId = session.id else { return }
        
        var updated = session
        updated.endedAt = Date()
        updated.observations = observations
        
        try db.collection("users")
            .document(uid)
            .collection("sessions")
            .document(sessionId)
            .setData(from: updated)
        
        activeSession = nil
        
        // Deactivate the room
        if var instance = roomInstances.first(where: { $0.id == session.instanceId }) {
            instance.isActive = false
            // Increase familiarity slightly
            instance.familiarityScore = min(1.0, instance.familiarityScore + 0.05)
            try await saveRoomInstance(instance)
        }
    }
    
    /// Fetch sessions for a specific instance
    func fetchSessions(for instanceId: String) async -> [Session] {
        guard let db = db, let uid = currentUserId else { return [] }
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("sessions")
                .whereField("instance_id", isEqualTo: instanceId)
                .order(by: "started_at", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            return snapshot.documents.compactMap { try? $0.data(as: Session.self) }
        } catch {
            print("Error fetching sessions: \(error)")
            return []
        }
    }
    
    /// Add observation to active session
    func addObservation(_ text: String) {
        activeSession?.observations.append(text)
    }
    
    // MARK: - Planned Sessions
    
    @Published var plannedSessions: [PlannedSession] = []
    
    /// Fetch planned sessions for the week
    func fetchPlannedSessions() async {
        guard let db = db, let uid = currentUserId else { return }
        
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) ?? Date()
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("planned_sessions")
                .whereField("scheduled_date", isGreaterThanOrEqualTo: startOfWeek)
                .order(by: "scheduled_date")
                .getDocuments()
            
            plannedSessions = snapshot.documents.compactMap { try? $0.data(as: PlannedSession.self) }
        } catch {
            print("Error fetching planned sessions: \(error)")
        }
    }
    
    /// Create a planned session
    func createPlannedSession(_ session: PlannedSession) async throws {
        guard let db = db, let uid = currentUserId else { return }
        
        _ = try db.collection("users")
            .document(uid)
            .collection("planned_sessions")
            .addDocument(from: session)
        
        await fetchPlannedSessions()
    }
    
    /// Update a planned session
    func updatePlannedSession(_ session: PlannedSession) async throws {
        guard let db = db, let uid = currentUserId, let sessionId = session.id else { return }
        
        try db.collection("users")
            .document(uid)
            .collection("planned_sessions")
            .document(sessionId)
            .setData(from: session)
        
        await fetchPlannedSessions()
    }
    
    /// Delete a planned session
    func deletePlannedSession(_ session: PlannedSession) async throws {
        guard let db = db, let uid = currentUserId, let sessionId = session.id else { return }
        
        try await db.collection("users")
            .document(uid)
            .collection("planned_sessions")
            .document(sessionId)
            .delete()
        
        await fetchPlannedSessions()
    }
    
    /// Mark planned session as completed
    func completePlannedSession(_ session: PlannedSession) async throws {
        var updated = session
        updated.isCompleted = true
        try await updatePlannedSession(updated)
    }
    
    // MARK: - Seasons
    
    @Published var seasons: [Season] = []
    @Published var activeSeason: Season?
    
    /// Fetch all seasons
    func fetchSeasons() async {
        guard let db = db, let uid = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("seasons")
                .order(by: "start_date")
                .getDocuments()
            
            seasons = snapshot.documents.compactMap { try? $0.data(as: Season.self) }
            activeSeason = seasons.first { $0.isActive }
        } catch {
            print("Error fetching seasons: \(error)")
        }
    }
    
    /// Create a season
    func createSeason(_ season: Season) async throws -> String {
        guard let db = db, let uid = currentUserId else { throw NSError(domain: "Auth", code: 401) }
        
        let ref = try db.collection("users")
            .document(uid)
            .collection("seasons")
            .addDocument(from: season)
        
        await fetchSeasons()
        return ref.documentID
    }
    
    /// Update a season
    func updateSeason(_ season: Season) async throws {
        guard let db = db, let uid = currentUserId, let seasonId = season.id else { return }
        
        try db.collection("users")
            .document(uid)
            .collection("seasons")
            .document(seasonId)
            .setData(from: season)
        
        await fetchSeasons()
    }
    
    /// Delete a season
    func deleteSeason(_ season: Season) async throws {
        guard let db = db, let uid = currentUserId, let seasonId = season.id else { return }
        
        try await db.collection("users")
            .document(uid)
            .collection("seasons")
            .document(seasonId)
            .delete()
        
        await fetchSeasons()
    }
    
    // MARK: - Recurring Blocks
    
    @Published var recurringBlocks: [RecurringBlock] = []
    
    /// Fetch all recurring blocks
    func fetchRecurringBlocks() async {
        guard let db = db, let uid = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("recurring_blocks")
                .order(by: "day_of_week")
                .getDocuments()
            
            recurringBlocks = snapshot.documents.compactMap { try? $0.data(as: RecurringBlock.self) }
        } catch {
            print("Error fetching recurring blocks: \(error)")
        }
    }
    
    /// Create a recurring block
    func createRecurringBlock(_ block: RecurringBlock) async throws {
        guard let db = db, let uid = currentUserId else { return }
        
        _ = try db.collection("users")
            .document(uid)
            .collection("recurring_blocks")
            .addDocument(from: block)
        
        await fetchRecurringBlocks()
    }
    
    /// Update a recurring block
    func updateRecurringBlock(_ block: RecurringBlock) async throws {
        guard let db = db, let uid = currentUserId, let blockId = block.id else { return }
        
        try db.collection("users")
            .document(uid)
            .collection("recurring_blocks")
            .document(blockId)
            .setData(from: block)
        
        await fetchRecurringBlocks()
    }
    
    /// Delete a recurring block
    func deleteRecurringBlock(_ block: RecurringBlock) async throws {
        guard let db = db, let uid = currentUserId, let blockId = block.id else { return }
        
        try await db.collection("users")
            .document(uid)
            .collection("recurring_blocks")
            .document(blockId)
            .delete()
        
        await fetchRecurringBlocks()
    }
    
    /// Mark a recurring block as completed for today
    func completeRecurringBlock(_ block: RecurringBlock) async throws {
        var updated = block
        updated.completedCount += 1
        updated.lastCompleted = Date()
        try await updateRecurringBlock(updated)
    }
    
    /// Mark a recurring block as missed
    func missRecurringBlock(_ block: RecurringBlock) async throws {
        var updated = block
        updated.missedCount += 1
        try await updateRecurringBlock(updated)
    }
    
    // MARK: - Mastery Tracking
    
    /// Add time to an instance's total minutes (called when session ends)
    func addMasteryTime(to instance: RoomInstance, minutes: Int) async throws {
        var updated = instance
        updated.totalMinutes += minutes
        updated.lastVisited = Date()
        try await saveRoomInstance(updated)
    }
}
