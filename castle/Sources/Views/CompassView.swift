// CompassView.swift
// Main dashboard showing the D/A phase space and Navigator chat

import SwiftUI

struct CompassView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var navigator = NavigatorService.shared
    @StateObject private var roomLoader = RoomLoader.shared
    
    @State private var somaticState = SomaticState.default
    @State private var showingChat = false
    @State private var chatMessage = ""
    @State private var selectedTransitionType: TransitionType? = nil
    @State private var currentLocation: NavigatorContext.LocationContext = .home
    
    enum TransitionType: String, Identifiable {
        case rest, work, explore, connect
        var id: String { rawValue }
        
        var wingFilter: String {
            switch self {
            case .rest: return "I. The Foundation (Restoration)"
            case .work: return "III. The Machine Shop (Production)"
            case .explore: return "IV. The Wilderness (Exploration)"
            case .connect: return "V. The Forum (Exchange)"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Position Card
                    currentPositionCard
                    
                    // Somatic Input
                    somaticInputSection
                    
                    // Navigator Response
                    if let response = navigator.lastResponse {
                        navigatorResponseCard(response)
                    }
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Compass")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingChat = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showingChat) {
                NavigatorChatView()
            }
            .sheet(item: $selectedTransitionType) { type in
                QuickTransitionSheet(
                    transitionType: type,
                    instances: instancesForTransition(type),
                    roomLoader: roomLoader
                )
            }
        }
    }
    
    private func instancesForTransition(_ type: TransitionType) -> [RoomInstance] {
        let wingRooms = roomLoader.rooms(inWing: type.wingFilter)
        let wingRoomIds = Set(wingRooms.map { $0.id })
        return firebaseManager.roomInstances.filter { instance in
            wingRoomIds.contains(instance.definitionId)
        }
    }
    
    // MARK: - Components
    
    private var currentPositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("You Are Here")
                    .font(.headline)
            }
            
            if let activeRoom = firebaseManager.activeRoom,
               let definition = roomLoader.room(byId: activeRoom.definitionId) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(definition.name)
                            .font(.title2.bold())
                        Text(activeRoom.variantName)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PhysicsBadge(
                        dionysian: definition.dionysianLevel,
                        apollonian: definition.apollonianLevel
                    )
                }
            } else {
                Text("No active room")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var somaticInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update Your State")
                .font(.headline)
            
            // Energy Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Energy")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Energy", selection: $somaticState.energy) {
                    ForEach(SomaticState.Level.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Tension Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Tension")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Tension", selection: $somaticState.tension) {
                    ForEach(SomaticState.Level.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Mood
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SomaticState.Mood.allCases, id: \.self) { mood in
                            Button {
                                somaticState.mood = mood
                            } label: {
                                Text(mood.rawValue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(somaticState.mood == mood ? .blue : .secondary.opacity(0.2))
                                    .foregroundStyle(somaticState.mood == mood ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("I'm at")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Location", selection: $currentLocation) {
                    Text("🏠 Home").tag(NavigatorContext.LocationContext.home)
                    Text("🏢 Office").tag(NavigatorContext.LocationContext.office)
                    Text("📍 Elsewhere").tag(NavigatorContext.LocationContext.elsewhere)
                }
                .pickerStyle(.segmented)
            }
            
            // Diagnose Button
            Button {
                Task {
                    await diagnose()
                }
            } label: {
                HStack {
                    if navigator.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                    }
                    Text("Diagnose")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(navigator.isProcessing)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func navigatorResponseCard(_ response: NavigatorResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("The Navigator")
                    .font(.headline)
            }
            
            Text(response.diagnosis)
                .font(.body)
            
            if let roomId = response.recommendedRoom,
               let room = roomLoader.room(byId: roomId) {
                NavigationLink {
                    RoomDetailView(definition: room)
                } label: {
                    HStack {
                        Text("Go to \(room.name)")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .padding()
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Transitions")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CompassQuickAction(
                    title: "Rest",
                    icon: "moon.fill",
                    color: .blue
                ) {
                    selectedTransitionType = .rest
                }
                
                CompassQuickAction(
                    title: "Work",
                    icon: "hammer.fill",
                    color: .orange
                ) {
                    selectedTransitionType = .work
                }
                
                CompassQuickAction(
                    title: "Explore",
                    icon: "safari",
                    color: .green
                ) {
                    selectedTransitionType = .explore
                }
                
                CompassQuickAction(
                    title: "Connect",
                    icon: "person.2.fill",
                    color: .purple
                ) {
                    selectedTransitionType = .connect
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func diagnose() async {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening"
        
        // Get today's rituals
        let weekday = Calendar.current.component(.weekday, from: Date())
        let todaysBlocks = firebaseManager.recurringBlocks.filter { $0.dayOfWeek == weekday }
        
        let context = NavigatorContext(
            currentRoom: firebaseManager.activeRoom,
            timeInCurrentRoom: nil,
            recentRooms: [],
            availableInstances: firebaseManager.roomInstances,
            activeSeason: firebaseManager.activeSeason,
            todaysRituals: todaysBlocks,
            timeOfDay: timeOfDay,
            currentLocation: currentLocation
        )
        
        do {
            _ = try await navigator.diagnose(somaticState: somaticState, context: context)
        } catch {
            print("Diagnosis error: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct PhysicsBadge: View {
    let dionysian: RoomDefinition.EnergyLevel
    let apollonian: RoomDefinition.EnergyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Text("D:\(dionysian.rawValue.prefix(1).uppercased())")
                .font(.caption.bold())
            Text("A:\(apollonian.rawValue.prefix(1).uppercased())")
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.secondary.opacity(0.2))
        .clipShape(Capsule())
    }
}

struct CompassQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Navigator Chat View

struct NavigatorChatView: View {
    @StateObject private var navigator = NavigatorService.shared
    @State private var message = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(navigator.conversationHistory.enumerated()), id: \.offset) { _, msg in
                            ChatBubble(message: msg)
                        }
                    }
                    .padding()
                }
                
                HStack {
                    TextField("Ask The Navigator...", text: $message)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(message.isEmpty || navigator.isProcessing)
                }
                .padding()
            }
            .navigationTitle("The Navigator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func sendMessage() async {
        let text = message
        message = ""
        _ = try? await navigator.chat(message: text)
    }
}

struct ChatBubble: View {
    let message: NavigatorMessage
    
    var body: some View {
        HStack {
            switch message {
            case .user(let text):
                Spacer()
                Text(text)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            case .navigator(let text):
                Text(text)
                    .padding()
                    .background(.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
        }
    }
}

// MARK: - Quick Transition Sheet

struct QuickTransitionSheet: View {
    let transitionType: CompassView.TransitionType
    let instances: [RoomInstance]
    let roomLoader: RoomLoader
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if instances.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No \(transitionType.wingFilter) rooms set up")
                            .font(.headline)
                        Text("Add instances from the Blueprint tab first")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(instances) { instance in
                        if let definition = roomLoader.room(byId: instance.definitionId) {
                            NavigationLink {
                                InstanceDetailView(definition: definition, instance: instance)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(definition.name)
                                            .font(.headline)
                                        Text(instance.variantName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if instance.isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(transitionType.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CompassView()
}
