// Season.swift
// Macro-constraint for long-term planning

import Foundation
import FirebaseFirestore

/// A Season defines the ruling theme for a time period
/// Transitions to the primary wing are "cheaper" during this season
struct Season: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    var name: String                    // "The Winter of Strategy"
    var primaryWing: Wing               // Ruling wing for this season
    var startDate: Date
    var endDate: Date
    var focusRooms: [String]            // Whitelist of room definition IDs
    var notes: String?
    
    enum Wing: String, Codable, CaseIterable {
        case foundation = "I. Foundation"
        case administration = "II. Administration"
        case machineShop = "III. Machine Shop"
        case wilderness = "IV. Wilderness"
        case forum = "V. Forum"
        case observatory = "VI. Observatory"
        
        var displayName: String {
            switch self {
            case .foundation: return "Foundation (Restoration)"
            case .administration: return "Administration (Governance)"
            case .machineShop: return "Machine Shop (Production)"
            case .wilderness: return "Wilderness (Exploration)"
            case .forum: return "Forum (Exchange)"
            case .observatory: return "Observatory (Metacognition)"
            }
        }
        
        var color: String {
            switch self {
            case .foundation: return "blue"
            case .administration: return "gray"
            case .machineShop: return "orange"
            case .wilderness: return "green"
            case .forum: return "purple"
            case .observatory: return "cyan"
            }
        }
        
        var energyDescription: String {
            switch self {
            case .foundation: return "Low D, Low A"
            case .administration: return "Low D, High A"
            case .machineShop: return "High D, High A"
            case .wilderness: return "High D, Low A"
            case .forum: return "Medium D/A"
            case .observatory: return "Meta"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case primaryWing = "primary_wing"
        case startDate = "start_date"
        case endDate = "end_date"
        case focusRooms = "focus_rooms"
        case notes
    }
    
    init(
        name: String,
        primaryWing: Wing,
        startDate: Date,
        endDate: Date,
        focusRooms: [String] = [],
        notes: String? = nil
    ) {
        self.name = name
        self.primaryWing = primaryWing
        self.startDate = startDate
        self.endDate = endDate
        self.focusRooms = focusRooms
        self.notes = notes
    }
    
    /// Check if this season is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Duration in days
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
