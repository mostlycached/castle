// WorkshopView.swift
// The Engineer's workspace - instance health, inventory, and AI-assisted creation

import SwiftUI

struct WorkshopView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomLoader = RoomLoader.shared
    @StateObject private var engineer = EngineerService.shared
    
    @State private var selectedTab = 0
    @State private var showingInstanceGenerator = false
    @State private var selectedDefinition: RoomDefinition?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Health").tag(0)
                    Text("Scouting").tag(1)
                    Text("Engineer").tag(2)
                    Text("Account").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                switch selectedTab {
                case 0:
                    healthDashboard
                case 1:
                    scoutingView
                case 2:
                    engineerChat
                case 3:
                    accountView
                default:
                    healthDashboard
                }
            }
            .navigationTitle("Workshop")
            .sheet(isPresented: $showingInstanceGenerator) {
                if let definition = selectedDefinition {
                    InstanceGeneratorSheet(definition: definition)
                }
            }
        }
    }
    
    // MARK: - Account View
    
    private var accountView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // User ID Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your User ID")
                        .font(.headline)
                    
                    if let uid = firebaseManager.currentUserId {
                        HStack {
                            Text(uid)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                UIPasteboard.general.string = uid
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("Share this ID with the admin to request access.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Signing in...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // App Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("The 72 Rooms")
                        .font(.headline)
                    Text("An attention management system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Health Dashboard
    
    private var healthDashboard: some View {
        ScrollView {
            if firebaseManager.roomInstances.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    // Sort by health (lowest first)
                    ForEach(sortedInstances) { instance in
                        if let definition = roomLoader.definition(for: instance.definitionId) {
                            NavigationLink {
                                InstanceDetailView(definition: definition, instance: instance)
                            } label: {
                                HealthCard(instance: instance, definition: definition)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var sortedInstances: [RoomInstance] {
        firebaseManager.roomInstances
            .filter { $0.id != nil }  // Only include instances with valid IDs
            .sorted { $0.computedHealth < $1.computedHealth }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Instances Yet")
                .font(.headline)
            
            Text("Create instances in the Blueprint tab or use the Scouting view to find locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Scouting View
    
    private var scoutingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Rooms without instances
                let roomsWithoutInstances = roomLoader.allRooms.filter { def in
                    firebaseManager.instances(for: def.id).isEmpty
                }
                
                if roomsWithoutInstances.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All rooms have instances!")
                            .font(.headline)
                    }
                    .padding(40)
                } else {
                    Text("\(roomsWithoutInstances.count) rooms need locations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(roomsWithoutInstances) { definition in
                        ScoutingCard(definition: definition) {
                            selectedDefinition = definition
                            showingInstanceGenerator = true
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Engineer Chat
    
    private var engineerChat: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if engineer.messages.isEmpty {
                            engineerWelcome
                        }
                        
                        ForEach(engineer.messages) { message in
                            EngineerMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if engineer.isLoading {
                            HStack {
                                ProgressView()
                                Text("Analyzing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: engineer.messages.count) {
                    if let lastMessage = engineer.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input
            chatInput
        }
    }
    
    private var engineerWelcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("The Engineer")
                .font(.headline)
            
            Text("I help you maintain your rooms, diagnose friction issues, and design new instances. Ask me anything about your setup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Quick actions
            VStack(spacing: 8) {
                QuickActionButton(title: "Analyze my lowest-health room", icon: "heart.text.square") {
                    if let weakest = sortedInstances.first {
                        Task {
                            await analyzeWeakestRoom(weakest)
                        }
                    }
                }
                
                QuickActionButton(title: "Suggest a new room to scout", icon: "binoculars") {
                    Task { await suggestRoomToScout() }
                }
            }
        }
        .padding(24)
    }
    
    @State private var chatMessage = ""
    
    private var chatInput: some View {
        HStack(spacing: 12) {
            TextField("Ask the Engineer...", text: $chatMessage)
                .textFieldStyle(.roundedBorder)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(chatMessage.isEmpty || engineer.isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let message = chatMessage
        chatMessage = ""
        Task {
            await engineer.sendMessage(message)
        }
    }
    
    private func analyzeWeakestRoom(_ instance: RoomInstance) async {
        if let definition = roomLoader.definition(for: instance.definitionId) {
            let diagnosis = await engineer.diagnoseFriction(instance: instance, definition: definition)
            engineer.messages.append(EngineerMessage(role: .engineer, content: "**\(instance.variantName)** Analysis:\n\n\(diagnosis)"))
        }
    }
    
    private func suggestRoomToScout() async {
        let roomsWithoutInstances = roomLoader.allRooms.filter { def in
            firebaseManager.instances(for: def.id).isEmpty
        }
        
        if let randomRoom = roomsWithoutInstances.randomElement() {
            let suggestions = await engineer.suggestLocations(for: randomRoom)
            let response = """
            **\(randomRoom.name)** needs a location!
            
            Function: \(randomRoom.function)
            
            Suggested locations:
            \(suggestions.map { "• \($0)" }.joined(separator: "\n"))
            """
            engineer.messages.append(EngineerMessage(role: .engineer, content: response))
        } else {
            engineer.messages.append(EngineerMessage(role: .engineer, content: "All rooms have instances! Great work."))
        }
    }
}

// MARK: - Health Card

struct HealthCard: View {
    let instance: RoomInstance
    let definition: RoomDefinition
    
    var body: some View {
        HStack(spacing: 12) {
            // Health indicator
            ZStack {
                Circle()
                    .stroke(healthColor.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: instance.computedHealth)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(instance.computedHealth * 100))")
                    .font(.caption.bold())
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.variantName.isEmpty ? definition.name : instance.variantName)
                    .font(.subheadline.bold())
                
                HStack {
                    Text(definition.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if instance.isActive {
                        Text("• Active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            // Issues indicator
            if !instance.inventory.isEmpty {
                let missingCount = instance.inventory.filter { $0.status != .operational }.count
                if missingCount > 0 {
                    Label("\(missingCount)", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var healthColor: Color {
        if instance.computedHealth > 0.7 { return .green }
        if instance.computedHealth > 0.4 { return .yellow }
        return .red
    }
}

// MARK: - Scouting Card

struct ScoutingCard: View {
    let definition: RoomDefinition
    let onScout: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.name)
                        .font(.subheadline.bold())
                    Text("Room \(definition.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("D:\(definition.dionysianLevel.rawValue.prefix(1))")
                    Text("A:\(definition.apollonianLevel.rawValue.prefix(1))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Text(definition.function)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Button(action: onScout) {
                Label("Create Instance", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Engineer Message Bubble

struct EngineerMessageBubble: View {
    let message: EngineerMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(LocalizedStringKey(message.content))
                .padding(12)
                .background(message.role == .user ? Color.blue : Color.orange.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == .engineer { Spacer() }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
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
            .background(.orange.opacity(0.1))
            .foregroundStyle(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Instance Generator Sheet

struct InstanceGeneratorSheet: View {
    let definition: RoomDefinition
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engineer = EngineerService.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var isGenerating = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Instance for")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(definition.name)
                        .font(.title2.bold())
                    Text(definition.function)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                if let generated = engineer.generatedInstance {
                    generatedView(generated)
                } else if isGenerating {
                    ProgressView("Engineer is designing...")
                        .padding(40)
                } else {
                    generatePrompt
                }
                
                Spacer()
            }
            .navigationTitle("Instance Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        engineer.clearMessages()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                engineer.clearMessages()
            }
        }
    }
    
    private var generatePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Let the Engineer design an instance for you")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Button {
                isGenerating = true
                Task {
                    await engineer.generateInstance(for: definition)
                    isGenerating = false
                }
            } label: {
                Label("Generate Suggestion", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding(24)
    }
    
    private func generatedView(_ data: GeneratedInstanceData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Location
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(data.variantName)
                        .font(.headline)
                }
                
                // Inventory
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inventory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(data.inventory, id: \.name) { item in
                        HStack {
                            Image(systemName: item.isCritical == true ? "star.fill" : "circle")
                                .foregroundStyle(item.isCritical == true ? .orange : .secondary)
                                .font(.caption)
                            Text(item.name)
                            if item.isCritical == true {
                                Text("Critical")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.subheadline)
                    }
                }
                
                // Mastery Dimensions
                if let dimensions = data.masteryDimensions, !dimensions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mastery Dimensions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(dimensions) { dim in
                            HStack {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                Text(dim.name)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(String(format: "Start: %.1f", dim.level))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !dim.description.isEmpty {
                                Text(dim.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                // Liturgy
                if let liturgy = data.liturgy {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Liturgy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Entry: \(liturgy.entry)")
                            .font(.subheadline)
                        
                        if let steps = liturgy.steps {
                            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                Text("Step \(idx + 1): \(step)")
                                    .font(.subheadline)
                            }
                        }
                        
                        Text("Exit: \(liturgy.exit)")
                            .font(.subheadline)
                    }
                }
                
                // Explanation
                if let explanation = data.explanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Create button
                Button {
                    Task { await createInstance(from: data) }
                } label: {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("Create Instance", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isCreating)
            }
            .padding()
        }
    }
    
    private func createInstance(from data: GeneratedInstanceData) async {
        isCreating = true
        
        let inventory = data.inventory.map { item in
            InventoryItem(name: item.name, status: .operational, isCritical: item.isCritical ?? false)
        }
        
        let liturgy: RoomLiturgy?
        if let litData = data.liturgy {
            liturgy = RoomLiturgy(
                entry: litData.entry,
                steps: litData.steps ?? [],
                exit: litData.exit
            )
        } else {
            liturgy = nil
        }
        
        do {
            try await firebaseManager.createInstance(
                definitionId: definition.id,
                variantName: data.variantName,
                inventory: inventory.map { $0.name },
                constraints: data.constraints ?? [],
                liturgy: liturgy,
                masteryDimensions: data.masteryDimensions ?? []
            )
            
            engineer.clearMessages()
            dismiss()
        } catch {
            print("Failed to create instance: \(error)")
            isCreating = false
        }
    }
}
