// StrategistView.swift
// Long-term planning with Seasons, Recurring Blocks, and Mastery tracking

import SwiftUI

struct StrategistView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomLoader = RoomLoader.shared
    @StateObject private var strategist = StrategistService.shared
    
    @State private var selectedTab = 0
    @State private var selectedMasteryInstance: RoomInstance?
    @State private var seasonFilter: String? = nil // nil = All
    @State private var selectedSeasonDetail: Season?

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Horizon").tag(0)
                    Text("Rhythm").tag(1)
                    Text("Mastery").tag(2)
                    Text("Chat").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch selectedTab {
                case 0:
                    horizonView
                case 1:
                    rhythmView
                case 2:
                    masteryView
                case 3:
                    strategistChat
                default:
                    horizonView
                }
            }
            .navigationTitle("Strategist")
            .task {
                await firebaseManager.fetchSeasons()
                await firebaseManager.fetchRecurringBlocks()
                await firebaseManager.fetchPlannedSessions()
                await firebaseManager.fetchRoomInstances()
            }
            .sheet(item: $selectedMasteryInstance) { instance in
                MasteryDetailSheet(instance: instance)
            }
            .sheet(item: $strategist.proposedSeason) { proposal in
                SeasonProposalSheet(proposal: proposal)
            }
            .sheet(item: $selectedSeasonDetail) { season in
                SeasonDetailView(season: season)
            }
        }
    }
    
    // MARK: - Horizon View (Seasons)
    
    @State private var showingSeasonEditor = false
    
    private var horizonView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Season Card
                if let season = firebaseManager.activeSeason {
                    activeSeasonCard(season)
                        .onTapGesture { selectedSeasonDetail = season }
                } else {
                    noActiveSeasonCard
                }
                
                // Season Timeline
                seasonTimeline
                
                // Add Season Button
                Button {
                    showingSeasonEditor = true
                } label: {
                    Label("Add Season", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingSeasonEditor) {
            SeasonEditorSheet()
        }
    }
    
    private func activeSeasonCard(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Active Season")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(season.durationDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(season.name)
                .font(.title2.bold())
            
            HStack {
                Label(season.primaryWing.displayName, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Progress
            let progress = seasonProgress(season)
            ProgressView(value: progress)
                .tint(.orange)
            
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var noActiveSeasonCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Active Season")
                .font(.headline)
            Text("Create a season to set your focus for the coming months")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var seasonTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Seasons")
                .font(.headline)
            
            if firebaseManager.seasons.isEmpty {
                Text("No seasons defined yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(firebaseManager.seasons) { season in
                    SeasonRow(season: season)
                        .onTapGesture { selectedSeasonDetail = season }
                }
            }
        }
    }
    
    private func seasonProgress(_ season: Season) -> Double {
        let now = Date()
        let total = season.endDate.timeIntervalSince(season.startDate)
        let elapsed = now.timeIntervalSince(season.startDate)
        return max(0, min(1, elapsed / total))
    }
    
// MARK: - Rhythm View (Recurring Blocks + Daily Calendar)

    @State private var showingBlockEditor = false
    @State private var showingAddSession = false
    @State private var selectedDate = Date()
    @State private var weekOffset = 0
    
    private var rhythmView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Filter
                HStack {
                    Text("Filter:")
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        Button("All Seasons") { seasonFilter = nil }
                        
                        if let active = firebaseManager.activeSeason {
                            Button("Active: \(active.name)") { seasonFilter = active.id }
                        }
                        
                        Divider()
                        
                        ForEach(firebaseManager.seasons) { season in
                            Button(season.name) { seasonFilter = season.id }
                        }
                    } label: {
                        Label(
                            seasonFilter == nil ? "All Seasons" : (firebaseManager.seasons.first(where: { $0.id == seasonFilter })?.name ?? "Selected"),
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Section 1: Recurring Rituals (The Ideal)
                VStack(spacing: 16) {
                    // Week grid
                    weekGrid
                    
                    // Block list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recurring Rituals")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingBlockEditor = true
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                        
                        if firebaseManager.recurringBlocks.isEmpty {
                            noBlocksView
                        } else {
                            ForEach(firebaseManager.recurringBlocks) { block in
                                RecurringBlockRow(block: block)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Section 2: Weekly Schedule (The Reality)
                VStack(spacing: 16) {
                    HStack {
                        Text("Schedule")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button {
                                withAnimation { weekOffset -= 1 }
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            
                            Text(weekRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 140) // Fixed width to prevent jitter
                                .multilineTextAlignment(.center)
                            
                            Button {
                                withAnimation { weekOffset += 1 }
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    
                    ForEach(weekDays, id: \.self) { date in
                        DaySection(
                            date: date,
                            sessions: sessionsFor(date),
                            onAddTap: {
                                selectedDate = date
                                showingAddSession = true
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingBlockEditor) {
            RecurringBlockEditorSheet()
        }
        .sheet(isPresented: $showingAddSession) {
            PlanSessionSheet(selectedDate: selectedDate)
        }
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let offsetDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) ?? startOfWeek
        
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: offsetDate) }
    }
    
    private var weekRangeText: String {
        guard let start = weekDays.first, let end = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    
    private func sessionsFor(_ date: Date) -> [PlannedSession] {
        firebaseManager.plannedSessions.filter { session in
            Calendar.current.isDate(session.scheduledDate, inSameDayAs: date) &&
            (seasonFilter == nil || session.seasonId == seasonFilter)
        }
    }
    
    private var weekGrid: some View {
        let dayHeaders = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        
        return VStack(spacing: 4) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(Array(dayHeaders.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Blocks by day
            HStack(alignment: .top, spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    VStack(spacing: 2) {
                        let dayBlocks = firebaseManager.recurringBlocks.filter { block in
                            block.dayOfWeek == day &&
                            (seasonFilter == nil || block.seasonId == seasonFilter)
                        }
                        ForEach(dayBlocks) { block in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(wingColor(for: block))
                                .frame(height: 24)
                                .overlay {
                                    Text(block.timeString)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white)
                                }
                        }
                        if dayBlocks.isEmpty {
                            RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.1)) // Lighter gray for empties
                            .frame(height: 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var noBlocksView: some View {
        VStack(spacing: 8) {
            Text("No recurring blocks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Schedule regular room sessions to build habits")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func wingColor(for block: RecurringBlock) -> Color {
        // Get room definition to determine wing color
        if let def = roomLoader.definition(for: block.definitionId) {
            // Simple wing detection from physics hint
            if def.physicsHint.contains("Low D") && def.physicsHint.contains("Low A") {
                return .blue // Foundation
            } else if def.physicsHint.contains("Low D") && def.physicsHint.contains("High A") {
                return .gray // Administration
            } else if def.physicsHint.contains("High D") && def.physicsHint.contains("High A") {
                return .orange // Machine Shop
            } else if def.physicsHint.contains("High D") && def.physicsHint.contains("Low A") {
                return .green // Wilderness
            }
        }
        return .purple // Default
    }
    
    // MARK: - Mastery View
    
    private var masteryView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary card
                masterySummary
                
                // Room mastery list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Room Mastery")
                        .font(.headline)
                    
                    ForEach(sortedByMastery) { instance in
                        MasteryRow(instance: instance, roomLoader: roomLoader)
                            .onTapGesture {
                                selectedMasteryInstance = instance
                            }
                    }
                }
            }
            .padding()
        }
    }
    
    private var masterySummary: some View {
        let totalHours = firebaseManager.roomInstances.reduce(0) { $0 + $1.totalMinutes } / 60
        let avgMastery = firebaseManager.roomInstances.isEmpty ? 0 :
            firebaseManager.roomInstances.reduce(0) { $0 + $1.masteryLevel } / firebaseManager.roomInstances.count
        
        return HStack(spacing: 24) {
            VStack {
                Text("\(totalHours)")
                    .font(.title.bold())
                Text("Hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack {
                Text("\(firebaseManager.roomInstances.count)")
                    .font(.title.bold())
                Text("Rooms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack {
                Text("Lvl \(avgMastery)")
                    .font(.title.bold())
                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var sortedByMastery: [RoomInstance] {
        firebaseManager.roomInstances
            .filter { $0.id != nil }
            .sorted { $0.totalMinutes > $1.totalMinutes }
    }
    
    // MARK: - Strategist Chat
    
    @State private var chatMessage = ""
    
    private var strategistChat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if strategist.messages.isEmpty {
                            strategistWelcome
                        }
                        
                        ForEach(strategist.messages) { message in
                            StrategistMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if strategist.isLoading {
                            HStack {
                                ProgressView()
                                Text("Planning...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: strategist.messages.count) {
                    if let last = strategist.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Input
            HStack(spacing: 12) {
                TextField("Ask the Strategist...", text: $chatMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let msg = chatMessage
                    chatMessage = ""
                    Task { await strategist.sendMessage(msg) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(chatMessage.isEmpty || strategist.isLoading)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private var strategistWelcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            
            Text("The Strategist")
                .font(.headline)
            
            Text("I help you plan for the long term - seasons, recurring rituals, and mastery progression. Ask me to schedule sessions, analyze your adherence, or plan the year ahead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                QuickPlanButton(title: "Plan my season", icon: "sun.max") {
                    Task { await strategist.sendMessage("Help me plan a season for the next 3 months") }
                }
                QuickPlanButton(title: "Analyze my rhythm", icon: "waveform.path") {
                    Task { await strategist.sendMessage("Analyze my recurring blocks for balance") }
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Season Row

struct SeasonRow: View {
    let season: Season
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(season.name)
                        .font(.subheadline.bold())
                    if season.isActive {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(season.primaryWing.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(season.startDate.formatted(date: .abbreviated, time: .omitted)) - \(season.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                Task { try? await firebaseManager.deleteSeason(season) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Recurring Block Row

struct RecurringBlockRow: View {
    let block: RecurringBlock
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.roomName)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text("\(block.dayNameFull) @ \(block.timeString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(block.durationMinutes)min")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Adherence
                HStack(spacing: 4) {
                    if block.isStruggling {
                        Label("Struggling", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(block.completedCount) done, \(block.missedCount) missed")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // Quick complete
            Button {
                Task { try? await firebaseManager.completeRecurringBlock(block) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            
            Button(role: .destructive) {
                Task { try? await firebaseManager.deleteRecurringBlock(block) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(block.isStruggling ? .orange.opacity(0.1) : Color.clear)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Mastery Row

struct MasteryRow: View {
    let instance: RoomInstance
    let roomLoader: RoomLoader
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.variantName.isEmpty ? "Instance" : instance.variantName)
                    .font(.subheadline.bold())
                if let def = roomLoader.definition(for: instance.definitionId) {
                    Text(def.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Lvl \(instance.masteryLevel)")
                    .font(.subheadline.bold())
                Text(instance.masteryLevelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: Double(instance.masteryLevel) / 10.0)
                    .stroke(masteryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            .frame(width: 32, height: 32)
            
            if !instance.masteryDimensions.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var masteryColor: Color {
        switch instance.masteryLevel {
        case 1...3: return .blue
        case 4...6: return .green
        case 7...9: return .orange
        case 10: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Supporting Views (DaySection, SessionCard, Bubble, QuickAction)

struct DaySection: View {
    let date: Date
    let sessions: [PlannedSession]
    let onAddTap: () -> Void
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline.bold())
                        .foregroundStyle(isToday ? .blue : .primary)
                    Text(date.formatted(.dateTime.day().month()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isToday {
                    Text("Today")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                
                Button(action: onAddTap) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Sessions
            if sessions.isEmpty {
                Text("No sessions planned")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions) { session in
                    PlannedSessionCard(session: session)
                }
            }
        }
        .padding()
        .background(isToday ? Color.blue.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PlannedSessionCard: View {
    let session: PlannedSession
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack {
                Text(session.scheduledDate.formatted(.dateTime.hour().minute()))
                    .font(.caption.bold())
                Text("\(session.duration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            
            // Room info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.roomName)
                    .font(.subheadline.bold())
                    .strikethrough(session.isCompleted)
                
                if let variant = session.variantName, !variant.isEmpty {
                    Text(variant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Complete button
            Button {
                Task {
                    try? await firebaseManager.completePlannedSession(session)
                }
            } label: {
                Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(session.isCompleted ? .green : .secondary)
            }
            
            Button(role: .destructive) {
                Task { try? await firebaseManager.deletePlannedSession(session) }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.5))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StrategistMessageBubble: View {
    let message: StrategistMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(LocalizedStringKey(message.content))
                .padding(12)
                .background(message.role == .user ? Color.blue : Color.purple.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == .strategist { Spacer() }
        }
    }
}

struct QuickPlanButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.purple.opacity(0.1))
            .foregroundStyle(.purple)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Plan Session Sheet

struct PlanSessionSheet: View {
    let selectedDate: Date
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomLoader = RoomLoader.shared
    
    @State private var selectedInstance: RoomInstance?
    @State private var scheduledTime = Date()
    @State private var duration = 30
    @State private var notes = ""
    @State private var seasonId: String?

    
    var body: some View {
        NavigationStack {
            Form {
                // Room selection
                Section("Room") {
                    Picker("Instance", selection: $selectedInstance) {
                        Text("Select a room").tag(nil as RoomInstance?)
                        ForEach(firebaseManager.roomInstances.filter { $0.id != nil }) { instance in
                            if let def = roomLoader.definition(for: instance.definitionId) {
                                Text("\(def.name) - \(instance.variantName)")
                                    .tag(instance as RoomInstance?)
                            }
                        }
                    }
                }
                
                // Time
                Section("Schedule") {
                    DatePicker("Time", selection: $scheduledTime, displayedComponents: [.hourAndMinute])
                    
                    Stepper("Duration: \(duration) min", value: $duration, in: 10...180, step: 10)
                }
                
                // Notes
                Section("Notes") {
                    TextField("Optional notes...", text: $notes)
                }
                
                Section("Season") {
                    Picker("Season", selection: $seasonId) {
                        Text("None").tag(nil as String?)
                        ForEach(firebaseManager.seasons) { season in
                            Text(season.name + (season.isActive ? " (Active)" : "")).tag(season.id as String?)
                        }
                    }
                }
            }
            .navigationTitle("Plan Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await createSession() }
                    }
                    .disabled(selectedInstance == nil)
                }
            }
            .onAppear {
                // Combine selected date with current time
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: Date())
                if let combined = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0,
                                                 of: selectedDate) {
                    scheduledTime = combined
                }
                seasonId = firebaseManager.activeSeason?.id
            }
        }
    }
    
    private func createSession() async {
        guard let instance = selectedInstance,
              let def = roomLoader.definition(for: instance.definitionId) else { return }
        
        // Combine date and time
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        let scheduledDate = calendar.date(from: combined) ?? selectedDate
        
        let session = PlannedSession(
            definitionId: instance.definitionId,
            instanceId: instance.id,
            roomName: def.name,
            variantName: instance.variantName,
            scheduledDate: scheduledDate,
            duration: duration,
            notes: notes.isEmpty ? nil : notes,
            seasonId: seasonId
        )
        
        try? await firebaseManager.createPlannedSession(session)
        dismiss()
    }
}

// MARK: - Season Editor Sheet

struct SeasonEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var name = ""
    @State private var primaryWing: Season.Wing = .foundation
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 90) // 90 days
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Season Details") {
                    TextField("Name", text: $name)
                    Picker("Primary Wing", selection: $primaryWing) {
                        ForEach(Season.Wing.allCases, id: \.self) { wing in
                            Text(wing.displayName).tag(wing)
                        }
                    }
                }
                
                Section("Duration") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createSeason() }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createSeason() async {
        let season = Season(
            name: name,
            primaryWing: primaryWing,
            startDate: startDate,
            endDate: endDate
        )
        try? await firebaseManager.createSeason(season)
        dismiss()
    }
}

// MARK: - Recurring Block Editor Sheet

struct RecurringBlockEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomLoader = RoomLoader.shared
    
    @State private var selectedInstance: RoomInstance?
    @State private var dayOfWeek = 2 // Monday
    @State private var startHour = 9
    @State private var duration = 60
    @State private var intent = ""
    @State private var seasonId: String?

    
    private let days = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"),
        (4, "Wednesday"), (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Room") {
                    Picker("Instance", selection: $selectedInstance) {
                        Text("Select a room").tag(nil as RoomInstance?)
                        ForEach(firebaseManager.roomInstances.filter { $0.id != nil }) { instance in
                            if let def = roomLoader.definition(for: instance.definitionId) {
                                Text("\(def.name) - \(instance.variantName)")
                                    .tag(instance as RoomInstance?)
                            }
                        }
                    }
                }
                
                Section("Schedule") {
                    Picker("Day", selection: $dayOfWeek) {
                        ForEach(days, id: \.0) { day in
                            Text(day.1).tag(day.0)
                        }
                    }
                    
                    Picker("Start Time", selection: $startHour) {
                        ForEach(5...23, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    
                    Stepper("Duration: \(duration) min", value: $duration, in: 15...240, step: 15)
                }
                
                Section("Intent (Optional)") {
                    TextField("What will you focus on?", text: $intent)
                }
                
                Section("Season") {
                    Picker("Season", selection: $seasonId) {
                        Text("None").tag(nil as String?)
                        ForEach(firebaseManager.seasons) { season in
                            Text(season.name + (season.isActive ? " (Active)" : "")).tag(season.id as String?)
                        }
                    }
                }
            }
            .navigationTitle("New Ritual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createBlock() }
                    }
                    .disabled(selectedInstance == nil)
                }
            }
            }
            .onAppear {
                seasonId = firebaseManager.activeSeason?.id
            }
        }
    
    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(period)"
    }
    
    private func createBlock() async {
        guard let instance = selectedInstance,
              let def = roomLoader.definition(for: instance.definitionId) else { return }
        
        let block = RecurringBlock(
            definitionId: instance.definitionId,
            instanceId: instance.id,
            roomName: def.name,
            variantName: instance.variantName,
            dayOfWeek: dayOfWeek,
            startHour: startHour,
            durationMinutes: duration,
            intent: intent.isEmpty ? nil : intent,
            seasonId: seasonId
        )
        try? await firebaseManager.createRecurringBlock(block)
        dismiss()
    }
}

// MARK: - Mastery Detail Sheet

struct MasteryDetailSheet: View {
    let instance: RoomInstance
    @Environment(\.dismiss) private var dismiss
    @StateObject private var roomLoader = RoomLoader.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RadarChart(
                        data: instance.masteryDimensions
                    )
                    .frame(height: 300)
                    .padding()
                    
                    if instance.masteryDimensions.isEmpty {
                        Text("No dimensions analyzed yet.")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    
                    // Stats
                    HStack(spacing: 40) {
                        statView(title: "Level", value: "\(instance.masteryLevel)")
                        statView(title: "Hours", value: "\(instance.totalMinutes / 60)")
                        statView(title: "Trend", value: "Flat") // Placeholder
                    }
                    
                    // Dimensions list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Breakdown")
                            .font(.headline)
                        
                        ForEach(instance.masteryDimensions) { dim in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dim.name)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(String(format: "%.1f/10", dim.level))
                                        .font(.caption.bold())
                                        .foregroundStyle(.purple)
                                }
                                
                                ProgressView(value: dim.level, total: 10.0)
                                    .tint(.purple)
                                
                                if !dim.description.isEmpty {
                                    Text(dim.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(instance.variantName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
