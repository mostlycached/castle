import SwiftUI

struct SeasonDetailView: View {
    let season: Season
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Stats
                    statsSection
                    
                    // Intent
                    if let notes = season.notes, !notes.isEmpty {
                        intentSection(notes)
                    }
                    
                    // Rhythm (Recurring Blocks)
                    rhythmSection
                    
                    // Session Logs
                    logsSection
                }
                .padding()
            }
            .navigationTitle(season.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.fill") // Or wing icon
                .font(.system(size: 48))
                .foregroundStyle(season.primaryWing.uiColor)
                .padding()
                .background(season.primaryWing.uiColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(season.name)
                    .font(.title2.bold())
                
                Text(season.primaryWing.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(season.primaryWing.uiColor)
                
                HStack {
                    Text(formatDate(season.startDate))
                    Spacer()
                    Text(formatDate(season.endDate))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem("Sessions", value: "\(seasonSessions.count)")
            Divider()
            statItem("Hours", value: "\(totalHours)")
            Divider()
            statItem("Rituals", value: "\(seasonBlocks.count)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func statItem(_ title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    

    
    private func intentSection(_ notes: String) -> some View {
        sectionContainer(title: "Intent") {
            Text(notes)
                .font(.body)
                .italic()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var rhythmSection: some View {
        sectionContainer(title: "The Rhythm") {
            if seasonBlocks.isEmpty {
                Text("No recurring rituals defined.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(seasonBlocks) { block in
                    HStack {
                        Text(block.dayName)
                            .font(.caption.bold())
                            .frame(width: 30, alignment: .leading)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text(block.roomName)
                                .font(.subheadline.bold())
                            Text(block.intent ?? "Ritual")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(block.timeString)
                            .font(.caption)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
    
    private var logsSection: some View {
        sectionContainer(title: "Session Logs") {
            if seasonSessions.isEmpty {
                Text("No completed sessions yet.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(seasonSessions) { session in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text(session.roomName)
                                .font(.subheadline.bold())
                            
                            if let notes = session.notes {
                                Text(notes)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(formatDateShort(session.scheduledDate))
                                .font(.caption.bold())
                            Text("\(session.duration) min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
    
    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private var seasonBlocks: [RecurringBlock] {
        firebaseManager.recurringBlocks.filter { $0.seasonId == season.id }
    }
    
    private var seasonSessions: [PlannedSession] {
        firebaseManager.plannedSessions.filter { 
            $0.seasonId == season.id && $0.isCompleted 
        }.sorted { $0.scheduledDate > $1.scheduledDate }
    }
    
    private var totalHours: Int {
        seasonSessions.reduce(0) { $0 + $1.duration } / 60
    }
    
    private var progress: Double {
        let now = Date()
        let total = season.endDate.timeIntervalSince(season.startDate)
        let elapsed = now.timeIntervalSince(season.startDate)
        return max(0, min(1, elapsed / total))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

extension Season.Wing {
    var uiColor: Color {
        switch self {
        case .foundation: return .blue
        case .administration: return .gray
        case .machineShop: return .orange
        case .wilderness: return .green
        case .forum: return .purple
        case .observatory: return .cyan
        }
    }
}
