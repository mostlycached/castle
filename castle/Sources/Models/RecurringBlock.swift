// RecurringBlock.swift
// Pre-scheduled recurring room rituals

import Foundation
import FirebaseFirestore

/// A recurring block represents a pre-booked room session
/// Used to force adaptation through scheduled practice
struct RecurringBlock: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    let definitionId: String            // Room class
    var instanceId: String?             // Specific instance (optional)
    var roomName: String                // Cached for display
    var variantName: String?            // Cached for display
    
    var dayOfWeek: Int                  // 1=Sunday, 2=Monday, etc.
    var startHour: Int                  // 0-23
    var startMinute: Int                // 0-59
    var durationMinutes: Int            // Duration
    
    var intent: String?                 // "Deep work on manifesto"
    var isActive: Bool                  // Can be paused
    var seasonId: String?               // Associated season
    
    // Adherence tracking
    var completedCount: Int             // Times completed
    var missedCount: Int                // Times missed
    var lastCompleted: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case instanceId = "instance_id"
        case roomName = "room_name"
        case variantName = "variant_name"
        case dayOfWeek = "day_of_week"
        case startHour = "start_hour"
        case startMinute = "start_minute"
        case durationMinutes = "duration_minutes"
        case intent
        case isActive = "is_active"
        case seasonId = "season_id"
        case completedCount = "completed_count"
        case missedCount = "missed_count"
        case lastCompleted = "last_completed"
    }
    
    init(
        definitionId: String,
        instanceId: String? = nil,
        roomName: String,
        variantName: String? = nil,
        dayOfWeek: Int,
        startHour: Int,
        startMinute: Int = 0,
        durationMinutes: Int = 60,
        intent: String? = nil,
        seasonId: String? = nil
    ) {
        self.definitionId = definitionId
        self.instanceId = instanceId
        self.roomName = roomName
        self.variantName = variantName
        self.dayOfWeek = dayOfWeek
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.intent = intent
        self.seasonId = seasonId
        self.isActive = true
        self.completedCount = 0
        self.missedCount = 0
        self.lastCompleted = nil
    }
    
    /// Day name for display
    var dayName: String {
        let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "?" }
        return days[dayOfWeek]
    }
    
    var dayNameFull: String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "Unknown" }
        return days[dayOfWeek]
    }
    
    /// Formatted time string
    var timeString: String {
        let hour = startHour % 12 == 0 ? 12 : startHour % 12
        let period = startHour < 12 ? "AM" : "PM"
        if startMinute == 0 {
            return "\(hour) \(period)"
        }
        return String(format: "%d:%02d %@", hour, startMinute, period)
    }
    
    /// Adherence rate (0.0 - 1.0)
    var adherenceRate: Double {
        let total = completedCount + missedCount
        guard total > 0 else { return 1.0 } // No data yet = assume good
        return Double(completedCount) / Double(total)
    }
    
    /// Is struggling (3+ missed)
    var isStruggling: Bool {
        missedCount >= 3 && adherenceRate < 0.5
    }
}
