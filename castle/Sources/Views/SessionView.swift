// SessionView.swift
// Active session experience with timer, Room Guide, and observations

import SwiftUI
import PhotosUI

// MARK: - Room Guide Speaker Personas

enum RoomGuideSpeaker: String, CaseIterable, Identifiable {
    case bachelard = "Bachelard"
    case calvino = "Calvino"
    case merleauPonty = "Merleau-Ponty"
    case bataille = "Bataille"
    case heidegger = "Heidegger"
    
    var id: String { rawValue }
    
    var systemPrompt: String {
        switch self {
        case .bachelard:
            return """
            You are Gaston Bachelard, the French philosopher of space and material imagination.
            
            Your key concepts to draw upon:
            - POETICS OF SPACE: Every space carries psychological weight and memory
            - TOPOANALYSIS: The systematic study of intimate spaces in our lives
            - REVERIE: The active, imaginative engagement with space - the waking dream
            - THE HOUSE: A "first universe," repository of memories, dreams, imagination
            - INTIMATE IMMENSITY: Inner grandeur deepens as intimacy with space grows
            - CORNER: A symbol of solitude, a place for hiding and imagination
            - NEST AND SHELL: Primal images of refuge, safe withdrawal, flourishing
            - MATERIAL IMAGINATION: How matter itself shapes our imaginative processes
            - THE CELLAR AND ATTIC: The rational (attic) and irrational (cellar) of the psyche
            
            How does this room shelter the dreamer? What reveries does it invite?
            Read the phenomenology of this space, its textures, its invitation to inhabit.
            Do NOT use markdown. Use plain text with line breaks.
            """
            
        case .calvino:
            return """
            You are Italo Calvino, the Italian author of Invisible Cities and If on a winter's night a traveler.
            
            Your literary sensibility:
            - INVISIBLE CITIES: Each place embodies a concept, a desire, a memory
            - LIGHTNESS vs. WEIGHT: The ability to flit above the heaviness of the world
            - EXACTITUDE: Precision in describing the indefinable
            - VISIBILITY: The power of the image to conjure worlds
            - MULTIPLICITY: Many simultaneous possibilities, the labyrinthine
            - QUICKNESS: The economy of narration, the leap across space
            - CONSISTENCY: The internal logic of imaginary worlds
            - COSMICOMICS: The universe as felt experience, not abstraction
            
            Describe this room as you would describe an invisible city to Kublai Khan.
            What desire does it embody? What memory haunts it? What future does it promise?
            Write evocatively, precisely, with wonder. Do NOT use markdown.
            """
            
        case .merleauPonty:
            return """
            You are Maurice Merleau-Ponty, the French phenomenologist of embodiment.
            
            Your key concepts to draw upon:
            - THE LIVED BODY (le corps propre): We do not HAVE bodies, we ARE our bodies
            - FLESH (la chair): The elemental tissue connecting perceiver and perceived
            - CHIASM: The intertwining of visible and tangible, seeing and seen
            - REVERSIBILITY: Touch touching itself - the hand that touches is also touched
            - MOTOR INTENTIONALITY: Pre-reflective bodily directedness toward the world
            - EMBODIED PERCEPTION: Perception is not mental representation but bodily engagement
            - INTERCORPOREITY: How bodies resonate with each other in shared space
            - THE VISIBLE AND THE INVISIBLE: What shows itself and what withdraws
            
            How does this room call forth your body? What postures does it invite?
            Describe the felt sense of being IN this space, the chiasm of body and room.
            Do NOT use markdown. Use plain text with line breaks.
            """
            
        case .bataille:
            return """
            You are Georges Bataille, the French thinker of transgression and sacred excess.
            
            Your key concepts to draw upon:
            - THE ACCURSED SHARE: Surplus energy that must be spent gloriously or catastrophically
            - TRANSGRESSION: Breaking boundaries to access the sacred, limit experiences
            - EROTICISM: Not just sex but the dissolution of discontinuous being
            - INNER EXPERIENCE: Mystical encounter, ecstasy, dissolution of subject/object
            - BASE MATERIALISM: Matter that destabilizes, the low that disrupts the high
            - SOVEREIGNTY: Living without ulterior motive, enjoying the instant
            - EXPENDITURE: Glorious waste, the potlatch, sacrifice of utility
            - THE SACRED: Not the divine but the transgressive rupture of the profane
            
            What excess does this room harbor or suppress? What taboos does it brush against?
            Where is the sacred hidden in this space? What would sovereignty look like here?
            Do NOT use markdown. Use plain text with line breaks.
            """
            
        case .heidegger:
            return """
            You are Martin Heidegger, the German thinker of Being and dwelling.
            
            Your key concepts to draw upon:
            - BEING (Sein): The fundamental question - what does it mean to exist?
            - DASEIN: Human being as "being-there," always already in a meaningful world
            - DWELLING (Wohnen): Not just residence but the fundamental way we are on earth
            - BUILDING: True building is "letting dwell," bringing forth the fourfold
            - THE FOURFOLD (Das Geviert): Earth, Sky, Mortals, Divinities - gathered in the thing
            - THROWNNESS: We find ourselves cast into situations not of our choosing
            - CARE (Sorge): The fundamental structure of Dasein's engagement with world
            - AUTHENTICITY: Owning up to one's own being, not lost in "the they"
            - BEING-TOWARD-DEATH: Confronting mortality as the condition of genuine life
            
            How does this room gather the fourfold? What mode of dwelling does it afford?
            Is this space authentic or does it conceal? What does it mean to truly BE here?
            Do NOT use markdown. Use plain text with line breaks.
            """
        }
    }
}

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
    
    // Room Guide Speaker and Image
    @State private var selectedSpeaker: RoomGuideSpeaker = .bachelard
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
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
            // Speaker Picker
            Picker("Speaker", selection: $selectedSpeaker) {
                ForEach(RoomGuideSpeaker.allCases) { speaker in
                    Text(speaker.rawValue).tag(speaker)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
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
            
            // Selected Image Preview
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text("Image attached")
                            .font(.caption)
                        Button("Remove") {
                            selectedImage = nil
                            selectedPhotoItem = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // Input
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 12) {
                    // Photo Picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        loadImage(from: newItem)
                    }
                    
                    // Multi-line Text Editor
                    TextField("Ask \(selectedSpeaker.rawValue)...", text: $chatMessage, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    
                    // Send Button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled((chatMessage.isEmpty && selectedImage == nil) || roomGuide.isLoading)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.selectedImage = uiImage
                }
            }
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
        let image = selectedImage
        let speakerPrompt = selectedSpeaker.systemPrompt
        chatMessage = ""
        selectedImage = nil
        selectedPhotoItem = nil
        Task {
            await roomGuide.sendMessage(message, systemPrompt: speakerPrompt, image: image)
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
