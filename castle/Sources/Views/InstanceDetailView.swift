// InstanceDetailView.swift
// Detail view for a specific room instance with sessions and entry

import SwiftUI
import FirebaseFunctions

struct InstanceDetailView: View {
    let definition: RoomDefinition
    let initialInstance: RoomInstance  // Renamed to clarify it's initial data
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var musicService = MusicService.shared
    
    // Get live instance from firebaseManager (updates when data changes)
    private var instance: RoomInstance {
        firebaseManager.roomInstances.first { $0.id == initialInstance.id } ?? initialInstance
    }
    @State private var sessions: [Session] = []
    @State private var isLoadingSessions = true
    @State private var showingSession = false
    @State private var activeSession: Session?
    @State private var showingMusicConfig = false
    @State private var generatingTrackNumber: Int? = nil
    @State private var downloadProgress: (Int, Int)? = nil
    @State private var savedMusicContext: MusicContext? = nil
    @State private var isNarrativeExpanded = false
    @State private var isGeneratingNarrative = false
    @State private var showingAddObservation = false
    @State private var newObservationText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Enter Button (moved to top)
                enterButton
                
                // Instance Observations (prominently displayed)
                observationsSection
                
                // Session History with Observations
                sessionObservationsSection
                
                // Music Player
                playlistSection
                
                // Room Narrative (collapsible)
                narrativeSection
                
                // Prior Sessions
                sessionsSection
            }
            .padding()
        }
        .navigationTitle(instance.variantName.isEmpty ? definition.name : instance.variantName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSessions()
        }
        .fullScreenCover(isPresented: $showingSession) {
            if let session = activeSession {
                SessionView(
                    session: session,
                    definition: definition,
                    instance: instance,
                    onEnd: {
                        showingSession = false
                        activeSession = nil
                        Task { await loadSessions() }
                    }
                )
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.name)
                        .font(.headline)
                    Text("Room \(definition.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(instance.familiarityScore * 100))%")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    Text("Familiarity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let evocativeWhy = instance.evocativeWhy {
                Text(evocativeWhy)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            
            // Physics summary
            HStack(spacing: 16) {
                PhysicsChip(label: "D", value: definition.dionysianLevel.rawValue.capitalized)
                PhysicsChip(label: "A", value: definition.apollonianLevel.rawValue.capitalized)
                
                if let physics = instance.physics {
                    Spacer()
                    Text("\(physics.inputLogic) → \(physics.outputLogic)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Inventory
            if !instance.requiredInventory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Required Inventory")
                        .font(.subheadline.bold())
                    
                    FlowLayout(spacing: 6) {
                        ForEach(instance.requiredInventory, id: \.self) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                Text(item)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    private func liturgySection(_ liturgy: RoomLiturgy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liturgy")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                LiturgyRow(icon: "door.left.hand.open", label: "Entry", text: liturgy.entry)
                
                ForEach(Array(liturgy.steps.enumerated()), id: \.offset) { index, step in
                    LiturgyRow(icon: "\(index + 1).circle", label: "Step \(index + 1)", text: step)
                }
                
                LiturgyRow(icon: "door.right.hand.open", label: "Exit", text: liturgy.exit)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Playlist Section
    
    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Room Playlist")
                    .font(.headline)
                Spacer()
                
                if instance.isPlaylistExpired {
                    Label("Expired", systemImage: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            if instance.hasPlaylist, let tracks = instance.playlist {
                // Mini Player
                if musicService.currentInstanceId == instance.id {
                    miniPlayer
                }
                
                // Track List - long press any track to delete entire playlist
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index,
                        isPlaying: musicService.currentTrackIndex == index && musicService.currentInstanceId == instance.id,
                        onPlay: {
                            if musicService.currentInstanceId != instance.id {
                                musicService.loadPlaylist(tracks, instanceId: instance.id ?? "")
                            }
                            musicService.playTrack(at: index)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                try? await firebaseManager.deletePlaylist(instance)
                            }
                        } label: {
                            Label("Delete Entire Playlist", systemImage: "trash")
                        }
                    }
                }
                
                // Download All Button
                HStack {
                    if let progress = downloadProgress {
                        ProgressView(value: Double(progress.0), total: Double(progress.1))
                        Text("\(progress.0)/\(progress.1)")
                            .font(.caption)
                    } else {
                        Button {
                            downloadAllTracks(tracks)
                        } label: {
                            Label("Download Playlist", systemImage: "arrow.down.circle")
                        }
                        .disabled(tracks.allSatisfy { $0.isDownloaded })
                    }
                    
                    Spacer()
                    
                    // Delete Playlist Button
                    Button {
                        print("🗑️ Delete button tapped for instance: \(instance.id ?? "nil")")
                        Task {
                            print("🗑️ Deleting playlist...")
                            try? await firebaseManager.deletePlaylist(instance)
                            print("🗑️ Delete complete")
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    
                    // Regenerate Button
                    if instance.isPlaylistExpired {
                        Button {
                            showingMusicConfig = true
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
            } else {
                // No playlist - show generate button
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No tracks generated yet")
                        .foregroundStyle(.secondary)
                    
                    Text("Generate tracks one at a time (~2 min each)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button {
                        showingMusicConfig = true
                    } label: {
                        if generatingTrackNumber != nil {
                            HStack {
                                ProgressView()
                                Text("Generating Track \(generatingTrackNumber!)...")
                            }
                            .padding(.horizontal)
                        } else {
                            Label("Configure & Generate Track 1", systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(generatingTrackNumber != nil)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            
            // Generate next track button (when some tracks exist but not all 8)
            if let tracks = instance.playlist, !tracks.isEmpty && tracks.count < 8 {
                Button {
                    Task { await generateTrack(index: tracks.count + 1) }
                } label: {
                    if let generating = generatingTrackNumber {
                        HStack {
                            ProgressView()
                            Text("Generating Track \(generating)...")
                        }
                    } else {
                        Label("Generate Track \(tracks.count + 1)", systemImage: "plus.circle")
                    }
                }
                .disabled(generatingTrackNumber != nil)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingMusicConfig) {
            MusicContextEditor(
                definition: definition,
                instance: instance,
                onGenerate: { context in
                    startPlaylistGeneration(context: context)
                }
            )
        }
    }
    
    private var miniPlayer: some View {
        HStack(spacing: 16) {
            Button(action: musicService.playPrevious) {
                Image(systemName: "backward.fill")
            }
            
            Button(action: musicService.togglePlayback) {
                Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            
            Button(action: musicService.playNext) {
                Image(systemName: "forward.fill")
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(musicService.currentTrack?.title ?? "")
                    .font(.caption.bold())
                    .lineLimit(1)
                Text("\(musicService.formattedCurrentTime) / \(musicService.formattedDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func downloadAllTracks(_ tracks: [RoomTrack]) {
        downloadProgress = (0, tracks.count)
        let roomName = instance.variantName.isEmpty ? definition.name : instance.variantName
        musicService.downloadPlaylist(tracks, roomName: roomName) { completed, total in
            downloadProgress = (completed, total)
        } completion: { updatedTracks in
            downloadProgress = nil
            Task {
                try? await firebaseManager.updatePlaylistDownload(instance, tracks: updatedTracks)
            }
        }
    }
    
    private func generateTrack(index: Int) async {
        generatingTrackNumber = index
        do {
            try await firebaseManager.generateTrack(
                for: instance,
                trackNumber: index
            )
        } catch {
            print("Failed to generate track \(index): \(error)")
        }
        generatingTrackNumber = nil
    }
    
    private func startPlaylistGeneration(context: MusicContext) {
        savedMusicContext = context
        // Set generating state immediately so the UI shows the loader
        generatingTrackNumber = 1
        Task {
            // First, generate album concept for diverse track descriptions
            do {
                try await firebaseManager.generateAlbumConcept(
                    for: instance,
                    roomName: definition.name,
                    context: context
                )
            } catch {
                print("Failed to generate album concept: \(error)")
                // Continue anyway - track generation will use fallback prompts
            }
            // Then start generating first track
            await generateTrack(index: 1)
        }
    }
    
    // MARK: - Observations Section
    
    private var observationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Observations")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddObservation = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            
            if instance.observations.isEmpty {
                Text("No observations yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(instance.observations, id: \.self) { observation in
                    HStack(alignment: .top) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        Text(observation)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Add Observation", isPresented: $showingAddObservation) {
            TextField("What did you observe?", text: $newObservationText)
            Button("Cancel", role: .cancel) {
                newObservationText = ""
            }
            Button("Add") {
                guard !newObservationText.isEmpty else { return }
                Task {
                    try? await firebaseManager.addObservation(newObservationText, to: instance)
                    newObservationText = ""
                }
            }
        }
    }
    
    // MARK: - Session Observations Section
    
    private var sessionObservationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Observations")
                .font(.headline)
            Text("What was observed in past sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if sessions.isEmpty && !isLoadingSessions {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(sessions.filter { !$0.observations.isEmpty }.prefix(5)) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.bold())
                            if let endedAt = session.endedAt {
                                Text("(\(Int(endedAt.timeIntervalSince(session.startedAt) / 60)) min)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ForEach(session.observations, id: \.self) { observation in
                            HStack(alignment: .top) {
                                Image(systemName: "quote.opening")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                Text(observation)
                                    .font(.caption)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Evocative Section (The Soul)
    
    @ViewBuilder
    private var evocativeSection: some View {
        let quote = definition.evocativeQuote
        let description = definition.evocativeDescription ?? instance.evocativeWhy
        
        if quote != nil || description != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Evocative Why")
                    .font(.headline)
                
                if let quote = quote {
                    Text("\"\(quote)\"")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                
                if let desc = description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Physics Section
    
    @ViewBuilder
    private var physicsSection: some View {
        let hasPhysics = definition.physicsDescription != nil || 
                         definition.inputLogic != nil || 
                         definition.outputLogic != nil ||
                         instance.physics != nil
        
        if hasPhysics {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("The Physics")
                        .font(.headline)
                    Spacer()
                    if let archetype = definition.archetype {
                        Text(archetype)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.2))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
                
                // Physics chips
                HStack(spacing: 16) {
                    PhysicsChip(label: "D", value: definition.dionysianLevel.rawValue.capitalized)
                    PhysicsChip(label: "A", value: definition.apollonianLevel.rawValue.capitalized)
                }
                
                // Description
                if let desc = definition.physicsDescription {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Equation
                if let equation = definition.equation {
                    Text(equation)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Input/Output Logic
                let inputLogic = definition.inputLogic ?? instance.physics?.inputLogic
                let outputLogic = definition.outputLogic ?? instance.physics?.outputLogic
                
                if inputLogic != nil || outputLogic != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        if let input = inputLogic {
                            HStack(alignment: .top) {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Input")
                                        .font(.caption.bold())
                                    Text(input)
                                        .font(.caption)
                                }
                            }
                        }
                        if let output = outputLogic {
                            HStack(alignment: .top) {
                                Image(systemName: "arrow.left.circle")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Output")
                                        .font(.caption.bold())
                                    Text(output)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Constraints Section (The Architecture)
    
    @ViewBuilder
    private var constraintsSection: some View {
        let constraints = definition.constraints ?? (instance.constraints.isEmpty ? nil : instance.constraints.map { RoomConstraint(name: $0, description: "") })
        
        if let constraints = constraints, !constraints.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Architecture")
                    .font(.headline)
                Text("If any of these walls are breached, the room collapses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                
                ForEach(constraints) { constraint in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(constraint.name)
                                .font(.subheadline.bold())
                        }
                        if !constraint.description.isEmpty {
                            Text(constraint.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Altar Section (Material Artifacts)
    
    @ViewBuilder
    private var altarSection: some View {
        let altar = definition.altar ?? instance.altar
        
        if let altar = altar, !altar.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Altar")
                    .font(.headline)
                
                ForEach(altar) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(item.name)
                                .font(.subheadline.bold())
                        }
                        if !item.description.isEmpty {
                            Text(item.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Trap Section (Failure Mode)
    
    @ViewBuilder
    private var trapSection: some View {
        let trap = definition.trap ?? instance.trap
        
        if let trap = trap {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Trap")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Leak")
                                .font(.caption.bold())
                            Text(trap.leak)
                                .font(.caption)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Result")
                                .font(.caption.bold())
                            Text(trap.result)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse toggle
            Button {
                withAnimation { isNarrativeExpanded.toggle() }
            } label: {
                HStack {
                    Text("Room Narrative")
                        .font(.headline)
                    Spacer()
                    if instance.narrative != nil {
                        Image(systemName: isNarrativeExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Content
            if let narrative = instance.narrative {
                // Narrative exists - show collapsible text
                if isNarrativeExpanded {
                    Text(narrative)
                        .font(.body)
                        .lineSpacing(4)
                        .padding()
                        .background(.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Regenerate button
                    Button {
                        Task { await generateNarrative() }
                    } label: {
                        if isGeneratingNarrative {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Regenerating...")
                            }
                        } else {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                    }
                    .font(.caption)
                    .disabled(isGeneratingNarrative)
                } else {
                    // Preview when collapsed
                    Text(narrative.prefix(150) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else {
                // No narrative yet - show generate button
                VStack(spacing: 12) {
                    Text("Generate a literary narrative for this room")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        Task { await generateNarrative() }
                    } label: {
                        if isGeneratingNarrative {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Generating narrative...")
                            }
                        } else {
                            Label("Generate Narrative", systemImage: "text.book.closed")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGeneratingNarrative)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prior Sessions")
                    .font(.headline)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No sessions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(sessions) { session in
                    SessionLogCard(session: session)
                }
            }
        }
    }
    
    private var enterButton: some View {
        Button {
            Task { await enterRoom() }
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Enter \(instance.variantName.isEmpty ? "Room" : instance.variantName)")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Actions
    
    private func loadSessions() async {
        isLoadingSessions = true
        if let instanceId = instance.id {
            sessions = await firebaseManager.fetchSessions(for: instanceId)
        }
        isLoadingSessions = false
    }
    
    private func enterRoom() async {
        do {
            let session = try await firebaseManager.startSession(
                instance: instance,
                roomName: definition.name
            )
            activeSession = session
            showingSession = true
        } catch {
            print("Failed to start session: \(error)")
        }
    }
    
    private func generateNarrative() async {
        isGeneratingNarrative = true
        do {
            try await firebaseManager.generateNarrative(for: instance, definition: definition)
        } catch {
            print("Failed to generate narrative: \(error)")
        }
        isGeneratingNarrative = false
    }
}

// MARK: - Supporting Views

struct PhysicsChip: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.secondary.opacity(0.2))
        .clipShape(Capsule())
    }
}

struct LiturgyRow: View {
    let icon: String
    let label: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
            }
        }
    }
}

struct SessionLogCard: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.startedAt, style: .date)
                    .font(.subheadline.bold())
                Spacer()
                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            

            
            if !session.observations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.observations.prefix(3), id: \.self) { obs in
                        Text("• \(obs)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if session.observations.count > 3 {
                        Text("+ \(session.observations.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: RoomTrack
    let index: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isPlaying ? Color.blue : Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(isPlaying ? .white : .secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(formatDuration(track.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if track.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Album Concept Picker (Simplified Music Configuration)

struct MusicContextEditor: View {
    let definition: RoomDefinition
    let instance: RoomInstance
    let onGenerate: (MusicContext) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConcept: AlbumConcept?
    @State private var customPrompt = ""
    @State private var useCustom = false
    @State private var albumConcepts: [AlbumConcept] = []
    @State private var isLoadingConcepts = true
    @State private var loadError: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoadingConcepts {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generating album concepts...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await loadAlbumConcepts() }
                        }
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose an Album Concept")
                                    .font(.headline)
                                Text("Based on \(definition.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Album concept cards
                            VStack(spacing: 12) {
                                ForEach(albumConcepts) { concept in
                                    AlbumConceptCard(
                                        concept: concept,
                                        isSelected: selectedConcept?.id == concept.id && !useCustom,
                                        onTap: {
                                            selectedConcept = concept
                                            useCustom = false
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Custom prompt option
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Or describe your own")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if useCustom {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                TextEditor(text: $customPrompt)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .background(.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        useCustom = true
                                    }
                                    .onChange(of: customPrompt) { _, newValue in
                                        // Automatically switch to custom mode when user types
                                        if !newValue.isEmpty {
                                            useCustom = true
                                        }
                                    }
                                
                                Text("Describe the atmosphere, instruments, mood, tempo, sounds...")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Generate Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        let context: MusicContext
                        if useCustom && !customPrompt.isEmpty {
                            context = MusicContext(
                                sceneSetting: .solo,
                                narrativeArc: customPrompt,
                                somaticElements: [],
                                locationInspiration: customPrompt,
                                instruments: [],
                                mood: "custom",
                                tempo: "moderate",
                                foundSounds: []
                            )
                        } else if let concept = selectedConcept {
                            context = concept.toMusicContext()
                        } else {
                            return
                        }
                        onGenerate(context)
                        dismiss()
                    }
                    .disabled(isLoadingConcepts)
                    .disabled(!useCustom && selectedConcept == nil)
                    .disabled(useCustom && customPrompt.isEmpty)
                }
            }
            .task {
                await loadAlbumConcepts()
            }
        }
    }
    
    // MARK: - LLM Album Concept Generation
    
    private func loadAlbumConcepts() async {
        isLoadingConcepts = true
        loadError = nil
        
        let prompt = """
        Generate 5 WILDLY DIVERSE album concept recommendations for \(definition.name).
        
        ROOM CONTEXT:
        - Room: \(definition.name) (Room \(definition.number))
        - Function: \(definition.function)
        - Physics: \(definition.physicsHint)
        - Evocative: \(definition.evocativeDescription ?? "N/A")
        - Archetype: \(definition.archetype ?? "N/A")
        - Instance: \(instance.variantName.isEmpty ? "Default" : instance.variantName)
        
        CREATIVE CONCEPTS (each album should have a specific sonic identity like these):
        - "French New Wave film score" - sparse, dissonant piano, Nouvelle Vague awkwardness
        - "Brutalist techno" - cold, industrial, concrete sound, Berlin warehouse at 4am
        - "Soap opera organ" - Hammond B3 daytime TV drama scoring, tremolo strings
        - "Musique concrète" - processed field recordings, no traditional instruments
        - "Deep Listening drone" - extremely slow, meditation on attention, sustained tones
        - "70s AM radio warmth" - soft rock, Laurel Canyon vibes, analog tape hiss
        - "A Cappella human chorus" - all sounds from human voice, beatbox, throat singing
        - "Solo Cello exploration" - one instrument, different techniques (sul ponticello, harmonics, pizzicato)
        - "Gamelan water ritual" - Indonesian percussion with aquatic found sounds
        - "Free jazz collision" - multiple groups playing simultaneously, clashing harmonies
        
        GENRE PALETTE (pick from these or combine creatively):
        - Vocal: acapella, Gregorian chant, Byzantine chant, throat singing, polyphonic choir, Qawwali
        - Contemporary: lo-fi R&B, neo-soul, chillhop, trip-hop, downtempo, vaporwave
        - Electronic: dark ambient, industrial, IDM, glitch, synthwave, electro swing, techno
        - Rock/Metal: post-rock, shoegaze, doom metal, gothic rock, progressive rock
        - Classical: baroque, romantic orchestral, minimalist, contemporary classical
        - World: gamelan, Carnatic, Hindustani raga, flamenco, Afrobeat, bossa nova, Ethiopian jazz
        - Experimental: noise, musique concrète, free jazz, drone, field recordings
        - Traditional: folk, bluegrass, sea shanties, work songs, lullabies
        
        PHYSICAL ATMOSPHERES (for "location" field):
        - Volcanic: active volcano, lava tubes, geothermal springs, sulfur vents
        - Aquatic: deep ocean floor, coral reef, underwater cave, stormy sea, frozen lake
        - Underground: limestone cave, salt mine, catacombs, subway tunnel, bunker
        - Wilderness: Amazon rainforest, Siberian taiga, African savanna, bamboo forest, mangrove swamp
        - Extreme: glacier, desert at night, thunderstorm, tornado, northern lights
        - Industrial: abandoned factory, steel mill, shipyard, server room, construction site
        - Sacred: Gothic cathedral, Shinto shrine, ancient temple ruins, sacred grove
        
        UNUSUAL INSTRUMENTS (for "instruments" field):
        - Tibetan singing bowls, crystal bowls, gongs, tam-tams
        - Didgeridoo, jaw harp, mouth harp
        - Gamelan (metallophone, kendang), kalimba, mbira
        - Hang drum, steel pan, tabla, djembe, frame drums
        - Kora, oud, sitar, erhu, shamisen, balalaika
        - Hurdy-gurdy, accordion, bandoneon, harmonium
        - Prepared piano, bowed vibraphone, waterphone
        - Theremin, ondes Martenot, modular synths
        
        FOUND SOUNDS (for "foundSounds" field):
        - Natural: volcano rumble, dripping cave water, whale song, cicadas, thunder, crackling fire
        - Industrial: machinery hum, metal clangs, train rhythms, factory pulses
        - Human: heartbeat, breath, footsteps, crowd murmur, children playing
        - Urban: traffic, construction, subway, market chatter
        
        REQUIREMENTS:
        Each concept must be DISTINCTLY DIFFERENT in genre, atmosphere, and emotional quality.
        Be creative, unexpected, even weird. Match the room's energy but through surprising musical lenses.
        
        Respond ONLY with valid JSON array:
        [
          {"title": "...", "description": "...", "mood": "...", "tempo": "...", "instruments": [...], "location": "...", "narrative": "...", "foundSounds": [...]}
        ]
        """
        
        do {
            let functions = Functions.functions()
            let result = try await functions.httpsCallable("callGemini").call([
                "prompt": prompt,
                "systemPrompt": "You are a creative music director. Generate diverse album concepts. Respond ONLY with valid JSON array, no markdown.",
                "model": "gemini-2.0-flash"
            ])
            
            if let data = result.data as? [String: Any],
               let text = data["text"] as? String {
                
                // Extract JSON from response
                if let jsonData = extractConceptsJSON(from: text) {
                    let concepts = try JSONDecoder().decode([AlbumConceptData].self, from: jsonData)
                    albumConcepts = concepts.enumerated().map { index, data in
                        AlbumConcept(
                            id: "concept_\(index)",
                            title: data.title,
                            description: data.description,
                            mood: data.mood,
                            tempo: data.tempo,
                            instruments: data.instruments,
                            location: data.location,
                            narrative: data.narrative,
                            foundSounds: data.foundSounds
                        )
                    }
                } else {
                    loadError = "Could not parse album concepts"
                }
            } else {
                loadError = "Invalid response from AI"
            }
        } catch {
            loadError = "Failed to generate: \(error.localizedDescription)"
        }
        
        isLoadingConcepts = false
    }
    
    private func extractConceptsJSON(from text: String) -> Data? {
        // Try to find JSON array
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]") {
            let jsonString = String(text[start...end])
            return jsonString.data(using: .utf8)
        }
        return nil
    }
}

// MARK: - Album Concept Data (for JSON decoding from LLM)

struct AlbumConceptData: Codable {
    let title: String
    let description: String
    let mood: String
    let tempo: String
    let instruments: [String]
    let location: String
    let narrative: String
    let foundSounds: [String]
}

// MARK: - Album Concept Model

struct AlbumConcept: Identifiable {
    let id: String
    let title: String
    let description: String
    let mood: String
    let tempo: String
    let instruments: [String]
    let location: String
    let narrative: String
    let foundSounds: [String]
    
    func toMusicContext() -> MusicContext {
        MusicContext(
            sceneSetting: .solo,
            narrativeArc: narrative,
            somaticElements: ["breath", "presence"],
            locationInspiration: location,
            instruments: instruments,
            mood: mood,
            tempo: tempo,
            foundSounds: foundSounds
        )
    }
}

// MARK: - Album Concept Card

struct AlbumConceptCard: View {
    let concept: AlbumConcept
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(concept.title)
                        .font(.subheadline.bold())
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                Text(concept.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(concept.instruments.prefix(3), id: \.self) { instrument in
                        Text(instrument)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Text(concept.mood)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? .blue.opacity(0.1) : .secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
