// Session.swift
// Tracks when a user enters and exits a room instance

import Foundation
import FirebaseFirestore

/// A session represents a single visit to a room instance
struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    
    let instanceId: String
    let definitionId: String
    let roomName: String
    let variantName: String
    
    let startedAt: Date
    var endedAt: Date?
    
    var observations: [String]
    
    /// Duration in seconds (computed on end)
    var durationSeconds: Int? {
        guard let end = endedAt else { return nil }
        return Int(end.timeIntervalSince(startedAt))
    }
    
    /// Formatted duration
    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "In progress..." }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    var isActive: Bool {
        endedAt == nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case roomName = "room_name"
        case variantName = "variant_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case observations
    }
    
    init(
        instanceId: String,
        definitionId: String,
        roomName: String,
        variantName: String
    ) {
        self.instanceId = instanceId
        self.definitionId = definitionId
        self.roomName = roomName
        self.variantName = variantName
        self.startedAt = Date()
        self.observations = []
    }
}


