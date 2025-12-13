import SwiftUI

struct SeasonProposalSheet: View {
    let proposal: StrategistService.FullSeasonProposal
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var isApplying = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Season Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed Season")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(proposal.season.name)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                        
                        HStack {
                            Image(systemName: "flag.fill")
                            Text(proposal.season.primaryWing)
                            
                            Spacer()
                            
                            Image(systemName: "clock")
                            Text("\(proposal.season.durationWeeks) weeks")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Text(proposal.season.description)
                        .font(.body)
                        .italic()
                        .padding(.horizontal)
                    
                    Divider()
                    
                    // Recurring Blocks
                    Text("Weekly Rhythm")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(proposal.blocks) { block in
                        HStack(alignment: .top) {
                            Text(dayName(for: block.dayOfWeek))
                                .font(.caption)
                                .bold()
                                .frame(width: 40, alignment: .leading)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(block.roomName ?? "Unknown Room")
                                    .font(.system(.body, design: .serif))
                                
                                Text("\(formatTime(hour: block.startHour)) (\(block.duration) min)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(block.intent)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: applyStrategy) {
                        if isApplying {
                            ProgressView()
                        } else {
                            Text("Apply Strategy")
                                .bold()
                        }
                    }
                    .disabled(isApplying)
                }
            }
        }
    }
    
    private func applyStrategy() {
        isApplying = true
        
        Task {
            // 1. Create Season
            let now = Date()
            let endDate = Calendar.current.date(byAdding: .weekOfYear, value: proposal.season.durationWeeks, to: now) ?? now
            
            let season = Season(
                name: proposal.season.name,
                primaryWing: Season.Wing(rawValue: proposal.season.primaryWing) ?? .foundation,
                startDate: now,
                endDate: endDate,
                focusRooms: [], // Could be inferred
                notes: proposal.season.description
            )
            
            do {
                let seasonId = try await firebaseManager.createSeason(season)
                
                // 2. Create Blocks linked to Season
                for blockProp in proposal.blocks {
                    let block = RecurringBlock(
                        definitionId: blockProp.definitionId,
                        instanceId: blockProp.instanceId,
                        roomName: blockProp.roomName ?? "Room",
                        variantName: blockProp.variantName,
                        dayOfWeek: blockProp.dayOfWeek,
                        startHour: blockProp.startHour,
                        startMinute: 0,
                        durationMinutes: blockProp.duration,
                        intent: blockProp.intent,
                        seasonId: seasonId
                    )
                    try await firebaseManager.createRecurringBlock(block)
                }
                
                // Success
                StrategistService.shared.proposedSeason = nil // Clear proposal
                dismiss()
                
            } catch {
                print("Failed to apply strategy: \(error)")
                isApplying = false
            }
        }
    }
    
    // Helpers
    
    private func dayName(for day: Int) -> String {
        let days = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return (day >= 1 && day <= 7) ? days[day] : "?"
    }
    
    private func formatTime(hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let p = hour < 12 ? "AM" : "PM"
        return "\(h) \(p)"
    }
}
