// RoomDetailView.swift
// Full room view with physics, liturgy, constraints, and instance state

import SwiftUI

struct RoomDetailView: View {
    let definition: RoomDefinition
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var roomLoader = RoomLoader.shared
    @State private var showingInstanceEditor = false
    
    private var instance: RoomInstance? {
        firebaseManager.instance(for: definition.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Physics
                physicsSection
                
                // Instance State (if exists)
                if let instance = instance {
                    instanceSection(instance)
                }
                
                // Liturgy (if instance has it)
                if let liturgy = instance?.liturgy {
                    liturgySection(liturgy)
                }
                
                // Constraints
                if let constraints = instance?.constraints, !constraints.isEmpty {
                    constraintsSection(constraints)
                }
                
                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingInstanceEditor = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingInstanceEditor) {
            RoomInstanceEditor(definition: definition, instance: instance)
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Room \(definition.number)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if instance?.isActive == true {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Text(definition.function)
                .font(.title3)
            
            if let variant = instance?.variantName, !variant.isEmpty {
                Label(variant, systemImage: "mappin.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let evocativeWhy = instance?.evocativeWhy {
                Text(evocativeWhy)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
    
    private var physicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Physics")
                .font(.headline)
            
            HStack(spacing: 16) {
                PhysicsCard(
                    title: "Dionysian",
                    level: definition.dionysianLevel.rawValue.capitalized,
                    color: dionysianColor
                )
                
                PhysicsCard(
                    title: "Apollonian",
                    level: definition.apollonianLevel.rawValue.capitalized,
                    color: apollonianColor
                )
            }
            
            if let physics = instance?.physics {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Input")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(physics.inputLogic)
                            .font(.subheadline.bold())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(physics.outputLogic)
                            .font(.subheadline.bold())
                    }
                }
                .padding()
                .background(.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func instanceSection(_ instance: RoomInstance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Instance")
                .font(.headline)
            
            HStack {
                StatCard(
                    title: "Familiarity",
                    value: "\(Int(instance.familiarityScore * 100))%",
                    color: .blue
                )
                
                StatCard(
                    title: "Health",
                    value: "\(Int(instance.healthScore * 100))%",
                    color: .green
                )
                
                StatCard(
                    title: "Friction",
                    value: instance.currentFriction.rawValue,
                    color: frictionColor(instance.currentFriction)
                )
            }
            
            if !instance.requiredInventory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Required Inventory")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(instance.requiredInventory, id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.2))
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
                LiturgyStep(label: "Entry", text: liturgy.entry, icon: "door.left.hand.open")
                
                ForEach(Array(liturgy.steps.enumerated()), id: \.offset) { index, step in
                    LiturgyStep(label: "Step \(index + 1)", text: step, icon: "\(index + 1).circle")
                }
                
                LiturgyStep(label: "Exit", text: liturgy.exit, icon: "door.right.hand.open")
            }
        }
    }
    
    private func constraintsSection(_ constraints: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Constraints")
                .font(.headline)
            
            ForEach(constraints, id: \.self) { constraint in
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(constraint)
                }
                .font(.subheadline)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if instance?.isActive != true {
                Button {
                    Task { await activateRoom() }
                } label: {
                    Label("Enter This Room", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    Task { await deactivateRoom() }
                } label: {
                    Label("Exit This Room", systemImage: "arrow.left.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var dionysianColor: Color {
        switch definition.dionysianLevel {
        case .low: return .blue
        case .medium: return .purple
        case .high: return .orange
        case .meta: return .teal
        }
    }
    
    private var apollonianColor: Color {
        switch definition.apollonianLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        case .meta: return .teal
        }
    }
    
    private func frictionColor(_ level: FrictionLevel) -> Color {
        switch level {
        case .zero: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    // MARK: - Actions
    
    private func activateRoom() async {
        guard var instance = instance else {
            // Create new instance
            let newInstance = RoomInstance(definitionId: definition.id, isActive: true)
            try? await firebaseManager.saveRoomInstance(newInstance)
            return
        }
        
        try? await firebaseManager.activateRoom(instance)
    }
    
    private func deactivateRoom() async {
        guard var instance = instance else { return }
        instance.isActive = false
        try? await firebaseManager.saveRoomInstance(instance)
    }
}

// MARK: - Supporting Views

struct PhysicsCard: View {
    let title: String
    let level: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(level)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LiturgyStep: View {
    let label: String
    let text: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Instance Editor

struct RoomInstanceEditor: View {
    let definition: RoomDefinition
    let instance: RoomInstance?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var variantName: String = ""
    @State private var inventory: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Variant Name (e.g., 'Balcony Chair')", text: $variantName)
                }
                
                Section("Inventory") {
                    TextField("Required items (comma-separated)", text: $inventory)
                }
            }
            .navigationTitle("Edit Instance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                }
            }
            .onAppear {
                variantName = instance?.variantName ?? ""
                inventory = instance?.requiredInventory.joined(separator: ", ") ?? ""
            }
        }
    }
    
    private func save() async {
        var updatedInstance = instance ?? RoomInstance(definitionId: definition.id)
        updatedInstance.variantName = variantName
        updatedInstance.requiredInventory = inventory
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        try? await firebaseManager.saveRoomInstance(updatedInstance)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RoomDetailView(
            definition: RoomDefinition(
                number: "013",
                name: "The Morning Chapel",
                physicsHint: "Low D, High A. Signal calibration.",
                function: "Setting the trajectory. Zero external input."
            )
        )
    }
}
