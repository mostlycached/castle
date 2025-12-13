// PlannedSession.swift
// Model for scheduling future room sessions

import Foundation
import FirebaseFirestore

/// A planned session for a future date
struct PlannedSession: Codable, Identifiable {
    @DocumentID var id: String?
    
    let definitionId: String
    let instanceId: String?
    let roomName: String
    let variantName: String?
    
    var scheduledDate: Date
    var duration: Int  // minutes
    var isCompleted: Bool
    var notes: String?
    var seasonId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case instanceId = "instance_id"
        case roomName = "room_name"
        case variantName = "variant_name"
        case scheduledDate = "scheduled_date"
        case duration
        case isCompleted = "is_completed"
        case notes
        case seasonId = "season_id"
    }
    
    init(
        definitionId: String,
        instanceId: String? = nil,
        roomName: String,
        variantName: String? = nil,
        scheduledDate: Date,
        duration: Int = 30,
        notes: String? = nil,
        seasonId: String? = nil
    ) {
        self.definitionId = definitionId
        self.instanceId = instanceId
        self.roomName = roomName
        self.variantName = variantName
        self.scheduledDate = scheduledDate
        self.duration = duration
        self.isCompleted = false
        self.notes = notes
        self.seasonId = seasonId
    }
}
