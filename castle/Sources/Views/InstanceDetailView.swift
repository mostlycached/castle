// InstanceDetailView.swift
// Detail view for a specific room instance with sessions and entry

import SwiftUI

struct InstanceDetailView: View {
    let definition: RoomDefinition
    let instance: RoomInstance
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var musicService = MusicService.shared
    @State private var sessions: [Session] = []
    @State private var isLoadingSessions = true
    @State private var showingSession = false
    @State private var activeSession: Session?
    @State private var showingMusicConfig = false
    @State private var generatingTrackNumber: Int? = nil
    @State private var downloadProgress: (Int, Int)? = nil
    @State private var savedMusicContext: MusicContext? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Enter Button (moved to top)
                enterButton
                
                // Music Player
                playlistSection
                
                // Liturgy
                if let liturgy = instance.liturgy {
                    liturgySection(liturgy)
                }
                
                // Constraints
                if !instance.constraints.isEmpty {
                    constraintsSection
                }
                
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
                
                // Track List
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
        musicService.downloadPlaylist(tracks) { completed, total in
            downloadProgress = (completed, total)
        } completion: { updatedTracks in
            downloadProgress = nil
            Task {
                try? await firebaseManager.updatePlaylistDownload(instance, tracks: updatedTracks)
            }
        }
    }
    
    private func generateTrack(index: Int) async {
        guard let context = savedMusicContext ?? instance.musicContext else { return }
        generatingTrackNumber = index
        do {
            try await firebaseManager.generateTrack(
                for: instance,
                roomName: definition.name,
                context: context,
                trackNumber: index
            )
        } catch {
            print("Failed to generate track \(index): \(error)")
        }
        generatingTrackNumber = nil
    }
    
    private func startPlaylistGeneration(context: MusicContext) {
        savedMusicContext = context
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
    
    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Constraints")
                .font(.headline)
            
            ForEach(instance.constraints, id: \.self) { constraint in
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(constraint)
                        .font(.subheadline)
                }
            }
        }
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

// MARK: - Music Context Editor

struct MusicContextEditor: View {
    let definition: RoomDefinition
    let instance: RoomInstance
    let onGenerate: (MusicContext) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sceneSetting: SceneSetting = .solo
    @State private var narrativeArc = ""
    @State private var somaticElements: [String] = []
    @State private var locationInspiration = ""
    @State private var instruments: [String] = []
    @State private var mood = ""
    @State private var tempo = "moderate"
    @State private var foundSounds: [String] = []
    
    // Input fields
    @State private var newSomatic = ""
    @State private var newInstrument = ""
    @State private var newFoundSound = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Scene Setting") {
                    Picker("Setting", selection: $sceneSetting) {
                        ForEach(SceneSetting.allCases, id: \.self) { setting in
                            Text(setting.rawValue.capitalized).tag(setting)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Atmosphere") {
                    TextField("Location Inspiration (e.g., ocean, volcano, forest)", text: $locationInspiration)
                    TextField("Mood (e.g., contemplative, energizing)", text: $mood)
                    Picker("Tempo", selection: $tempo) {
                        Text("Slow").tag("slow")
                        Text("Moderate").tag("moderate")
                        Text("Upbeat").tag("upbeat")
                    }
                }
                
                Section("Narrative (Optional)") {
                    TextField("Story arc (e.g., journey of discovery)", text: $narrativeArc)
                }
                
                Section("Instruments") {
                    chipEditor(items: $instruments, newItem: $newInstrument, placeholder: "Add instrument...")
                }
                
                Section("Somatic Elements") {
                    chipEditor(items: $somaticElements, newItem: $newSomatic, placeholder: "Add element (heartbeat, breath)...")
                }
                
                Section("Found Sounds") {
                    chipEditor(items: $foundSounds, newItem: $newFoundSound, placeholder: "Add sound (rain, pen clicks)...")
                }
            }
            .navigationTitle("Configure Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        let context = MusicContext(
                            sceneSetting: sceneSetting,
                            narrativeArc: narrativeArc.isEmpty ? nil : narrativeArc,
                            somaticElements: somaticElements,
                            locationInspiration: locationInspiration,
                            instruments: instruments,
                            mood: mood,
                            tempo: tempo,
                            foundSounds: foundSounds
                        )
                        onGenerate(context)
                        dismiss()
                    }
                    .disabled(locationInspiration.isEmpty || mood.isEmpty)
                }
            }
            .onAppear {
                prefillFromRoom()
            }
        }
    }
    
    private func chipEditor(items: Binding<[String]>, newItem: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(items.wrappedValue, id: \.self) { item in
                    HStack(spacing: 4) {
                        Text(item)
                        Button {
                            items.wrappedValue.removeAll { $0 == item }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            HStack {
                TextField(placeholder, text: newItem)
                    .textFieldStyle(.roundedBorder)
                Button {
                    if !newItem.wrappedValue.isEmpty {
                        items.wrappedValue.append(newItem.wrappedValue)
                        newItem.wrappedValue = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newItem.wrappedValue.isEmpty)
            }
        }
    }
    
    private func prefillFromRoom() {
        // Prefill based on room definition
        if let physics = instance.physics {
            locationInspiration = physics.dionysianEnergy.lowercased().contains("high") ? "volcano, storm" : "calm lake, garden"
            tempo = physics.dionysianEnergy.lowercased().contains("high") ? "upbeat" : "slow"
        }
        
        mood = definition.function.contains("Rest") ? "serene" : 
               definition.function.contains("Work") ? "focused" : "contemplative"
        
        // Default instruments based on energy levels
        let d = definition.dionysianLevel
        let a = definition.apollonianLevel
        
        switch (d, a) {
        case (.low, .low): // Foundation
            instruments = ["ambient pads", "gentle piano"]
            somaticElements = ["breath", "heartbeat"]
        case (.low, .high): // Administration
            instruments = ["minimal piano", "soft strings"]
            somaticElements = ["focus", "clarity"]
        case (.high, .high): // Machine Shop
            instruments = ["synth", "electronic beats"]
            somaticElements = ["energy", "flow"]
        case (.high, .low): // Wilderness
            instruments = ["organic textures", "world percussion"]
            somaticElements = ["movement", "exploration"]
        case (.medium, _), (_, .medium): // Forum
            instruments = ["acoustic guitar", "warm bass"]
            somaticElements = ["connection", "presence"]
        case (.meta, _), (_, .meta): // Observatory
            instruments = ["ethereal synths", "glass bells"]
            somaticElements = ["awareness", "stillness"]
        default:
            instruments = ["ambient pads"]
            somaticElements = ["presence"]
        }
    }
}
