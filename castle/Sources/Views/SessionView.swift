// SessionView.swift
// Active session experience with timer, Room Guide, and observations

import SwiftUI

struct SessionView: View {
    let session: Session
    let definition: RoomDefinition
    let instance: RoomInstance
    let onEnd: () -> Void
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomGuide = RoomGuideService.shared
    @StateObject private var musicService = MusicService.shared
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var observations: [String] = []
    @State private var newObservation = ""
    @State private var chatMessage = ""
    @State private var selectedTab: SessionTab = .liturgy
    @State private var isPaused = false
    
    enum SessionTab {
        case guide
        case notes
        case liturgy
    }
    
    // Transition State
    @State private var sessionState: SessionState = .initializing
    @State private var transitionText: String = ""
    
    enum SessionState {
        case initializing
        case showingEntry
        case active
        case generatingExit
        case showingExit
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main Session Content
                VStack(spacing: 0) {
                    // Header with timer
                    sessionHeader
                    
                    // Music Player (if playlist exists)
                    if instance.hasPlaylist {
                        sessionMusicPlayer
                    }
                    
                    // Main content
                    TabView(selection: $selectedTab) {
                        // Liturgy Tab (First)
                        liturgyTab
                            .tabItem {
                                Label("Liturgy", systemImage: "list.bullet.clipboard")
                            }
                            .tag(SessionTab.liturgy)
                        
                        // Presence Tab - Room Guide Chat
                        presenceTab
                            .tabItem {
                                Label("Guide", systemImage: "bubble.left.and.bubble.right")
                            }
                            .tag(SessionTab.guide)
                        
                        // Observations Tab
                        observationsTab
                            .tabItem {
                                Label("Notes", systemImage: "note.text")
                            }
                            .tag(SessionTab.notes)
                    }
                }
                .disabled(sessionState != .active)
                .opacity(sessionState == .active ? 1 : 0)
                
                // Bottom Controls Removed

                
                // Transitions
                if sessionState == .initializing || sessionState == .showingEntry {
                    RoomTransitionView(
                        text: transitionText.isEmpty ? "Preparing space..." : transitionText,
                        roomName: definition.name,
                        color: Color(white: 0.1), // Placeholder or room color
                        type: .entry,
                        onContinue: startActiveSession
                    )
                    .transition(.opacity)
                }
                
                if sessionState == .generatingExit || sessionState == .showingExit {
                    RoomTransitionView(
                        text: transitionText.isEmpty ? "Sealing the work..." : transitionText,
                        roomName: definition.name,
                        color: Color(white: 0.1),
                        type: .exit,
                        onContinue: finalizeSession
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle(sessionState == .active ? (instance.variantName.isEmpty ? definition.name : instance.variantName) : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Removed End button
            }
            .toolbar {
                // Removed End button
            }
            .onAppear {
                if sessionState == .initializing {
                    prepareEntryTransition()
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedTime)
                    .font(.title2)
                    .fontWeight(.light)
                    .monospacedDigit()
                
                Text(definition.function)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: togglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.body)
                        .padding(10)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                }
                .foregroundStyle(isPaused ? .green : .primary)
                
                Button(action: {
                    Task { await endSession() }
                }) {
                    Text("Complete")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Music Player
    
    private var sessionMusicPlayer: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button {
                if musicService.currentInstanceId != instance.id, let tracks = instance.playlist {
                    musicService.loadPlaylist(tracks, instanceId: instance.id ?? "")
                    musicService.play()
                } else {
                    musicService.togglePlayback()
                }
            } label: {
                Image(systemName: musicService.isPlaying && musicService.currentInstanceId == instance.id ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                if let track = musicService.currentTrack, musicService.currentInstanceId == instance.id {
                    Text(track.title)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text("\(musicService.formattedCurrentTime) / \(musicService.formattedDuration)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Room Playlist")
                        .font(.caption.bold())
                    Text("\(instance.playlist?.count ?? 0) tracks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Skip Controls
            if musicService.currentInstanceId == instance.id {
                Button(action: musicService.playPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.caption)
                }
                Button(action: musicService.playNext) {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onAppear {
            // Auto-start music when session begins
            if let tracks = instance.playlist, !tracks.isEmpty {
                musicService.loadPlaylist(tracks, instanceId: instance.id ?? "")
            }
        }
    }
    
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        if minutes < 10 {
            return "< 10 min"
        } else {
            let rounded = (minutes / 10) * 10
            return "\(rounded) min"
        }
    }
    
    // MARK: - Presence Tab (Room Guide)
    
    private var presenceTab: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(roomGuide.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if roomGuide.isLoading {
                            HStack {
                                ProgressView()
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: roomGuide.messages.count) {
                    if let lastMessage = roomGuide.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input
            HStack(spacing: 12) {
                TextField("Talk to Room Guide...", text: $chatMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(chatMessage.isEmpty || roomGuide.isLoading)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Observations Tab
    
    private var observationsTab: some View {
        VStack(spacing: 0) {
            // List of observations
            List {
                if observations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No observations yet")
                            .foregroundStyle(.secondary)
                        Text("Capture thoughts, insights, or anything notable")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(observations.enumerated()), id: \.offset) { index, obs in
                        Text(obs)
                    }
                    .onDelete { indexSet in
                        observations.remove(atOffsets: indexSet)
                    }
                }
            }
            
            // Add observation
            HStack(spacing: 12) {
                TextField("Add observation...", text: $newObservation)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    addObservation()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newObservation.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Liturgy Tab
    
    private var liturgyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let liturgy = instance.liturgy {
                    LiturgyCheckItem(text: liturgy.entry, label: "Entry")
                    
                    ForEach(Array(liturgy.steps.enumerated()), id: \.offset) { index, step in
                        LiturgyCheckItem(text: step, label: "Step \(index + 1)")
                    }
                    
                    LiturgyCheckItem(text: liturgy.exit, label: "Exit")
                } else {
                    Text("No liturgy defined for this instance")
                        .foregroundStyle(.secondary)
                }
                
                // Constraints reminder
                if !instance.constraints.isEmpty {
                    Divider()
                    
                    Text("Remember")
                        .font(.headline)
                    
                    ForEach(instance.constraints, id: \.self) { constraint in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(constraint)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - End Session Sheet Removed
    
    // MARK: - End Session Sheet Removed
    // Logic moved to direct action

    
    // MARK: - Actions
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !isPaused {
                elapsedTime += 1
            }
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
        // If resuming, timer is already running but skipping.
        // Or we could invalidate/restart. Current logic is fine.
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func sendMessage() {
        let message = chatMessage
        chatMessage = ""
        Task {
            await roomGuide.sendMessage(message)
        }
    }
    
    private func addObservation() {
        observations.append(newObservation)
        firebaseManager.addObservation(newObservation)
        newObservation = ""
    }
    
    private func endSession() async {
        do {
            try await firebaseManager.endSession(session, observations: observations)
            
            // Start Exit Transition
            sessionState = .generatingExit
            stopTimer()
            
            // Generate exit text
            Task {
                let text = try? await roomGuide.generateTransition(
                    type: .exit,
                    instance: instance,
                    definition: definition,
                    season: firebaseManager.activeSeason,
                    timeOfDay: getTimeOfDayString(),
                    recentLogs: observations
                )
                
                await MainActor.run {
                    transitionText = text ?? "Session complete."
                    sessionState = .showingExit
                }
            }
            
        } catch {
            print("Failed to end session: \(error)")
            onEnd() // Fallback
        }
    }
    
    private func prepareEntryTransition() {
        Task {
            let text = try? await roomGuide.generateTransition(
                type: .entry,
                instance: instance,
                definition: definition,
                season: firebaseManager.activeSeason,
                timeOfDay: getTimeOfDayString()
            )
            
            await MainActor.run {
                transitionText = text ?? "Welcome."
                withAnimation {
                    sessionState = .showingEntry
                }
            }
        }
    }
    
    private func startActiveSession() {
        withAnimation {
            sessionState = .active
        }
        startTimer()
        roomGuide.startGuiding(instance: instance, definition: definition)
    }
    
    private func finalizeSession() {
        roomGuide.endGuiding()
        onEnd()
    }
    
    private func getTimeOfDayString() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning" }
        if hour < 17 { return "Afternoon" }
        return "Evening"
    }
}

// MARK: - Supporting Views

struct MessageBubble: View {
    let message: GuideMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == .guide { Spacer() }
        }
    }
}

struct LiturgyCheckItem: View {
    let text: String
    let label: String
    @State private var isChecked = false
    
    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(text)
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
