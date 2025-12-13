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
                try? doc.data(as: RoomInstance.self)
            }
        } catch {
            print("Error fetching rooms: \(error)")
        }
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
    
    func instance(for definitionId: String) -> RoomInstance? {
        roomInstances.first { $0.definitionId == definitionId }
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
}
