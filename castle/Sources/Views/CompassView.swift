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
                QuickActionButton(
                    title: "Rest",
                    icon: "moon.fill",
                    color: .blue
                ) {
                    // Navigate to Foundation wing
                }
                
                QuickActionButton(
                    title: "Work",
                    icon: "hammer.fill",
                    color: .orange
                ) {
                    // Navigate to Machine Shop
                }
                
                QuickActionButton(
                    title: "Explore",
                    icon: "safari",
                    color: .green
                ) {
                    // Navigate to Wilderness
                }
                
                QuickActionButton(
                    title: "Connect",
                    icon: "person.2.fill",
                    color: .purple
                ) {
                    // Navigate to Forum
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func diagnose() async {
        let context = NavigatorContext(
            currentRoom: firebaseManager.activeRoom,
            timeInCurrentRoom: nil,
            recentRooms: []
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

struct QuickActionButton: View {
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

#Preview {
    CompassView()
}
