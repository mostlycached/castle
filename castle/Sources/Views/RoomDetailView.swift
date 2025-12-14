// RoomDetailView.swift
// Full room view with physics and list of user instances

import SwiftUI

struct RoomDetailView: View {
    let definition: RoomDefinition
    
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showingAddInstance = false
    @State private var selectedInstance: RoomInstance?
    
    /// All instances for this room class
    private var instances: [RoomInstance] {
        firebaseManager.instances(for: definition.id).filter { $0.id != nil }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Room Class Info
                headerSection
                
                // Evocative Why (The Soul)
                evocativeSection
                
                // Physics
                physicsSection
                
                // Constraints (The Architecture)
                constraintsSection
                
                // Altar (Material Artifacts)
                altarSection
                
                // Liturgy
                liturgySection
                
                // Trap (Failure Mode)
                trapSection
                
                // Instances Section
                instancesSection
            }
            .padding()
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddInstance = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddInstance) {
            AddInstanceSheet(definition: definition)
        }
        .sheet(item: $selectedInstance) { instance in
            EditInstanceSheet(definition: definition, instance: instance)
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room \(definition.number)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(definition.function)
                .font(.title3)
            
            Text(definition.physicsHint)
                .font(.caption)
                .foregroundStyle(.secondary)
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
            
            // Physics details
            if let desc = definition.physicsDescription {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let equation = definition.equation {
                Text(equation)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Input/Output Logic
            if let input = definition.inputLogic {
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
            if let output = definition.outputLogic {
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
    
    // MARK: - Evocative Section
    
    @ViewBuilder
    private var evocativeSection: some View {
        if definition.evocativeQuote != nil || definition.evocativeDescription != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Evocative Why")
                    .font(.headline)
                
                if let quote = definition.evocativeQuote {
                    Text("\"\(quote)\"")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                
                if let desc = definition.evocativeDescription {
                    Text(desc)
                        .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Constraints Section
    
    @ViewBuilder
    private var constraintsSection: some View {
        if let constraints = definition.constraints, !constraints.isEmpty {
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
    
    // MARK: - Altar Section
    
    @ViewBuilder
    private var altarSection: some View {
        if let altar = definition.altar, !altar.isEmpty {
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
    
    // MARK: - Liturgy Section
    
    @ViewBuilder
    private var liturgySection: some View {
        if let liturgy = definition.liturgy {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Liturgy")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Image(systemName: "door.left.hand.open")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Entry")
                                .font(.caption.bold())
                            Text(liturgy.entry)
                                .font(.caption)
                        }
                    }
                    
                    ForEach(Array(liturgy.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top) {
                            Image(systemName: "\(index + 1).circle")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Step \(index + 1)")
                                    .font(.caption.bold())
                                Text(step)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "door.right.hand.open")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading) {
                            Text("Exit")
                                .font(.caption.bold())
                            Text(liturgy.exit)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Trap Section
    
    @ViewBuilder
    private var trapSection: some View {
        if let trap = definition.trap {
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
    
    private var instancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Instances")
                    .font(.headline)
                Spacer()
                Text("\(instances.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if instances.isEmpty {
                emptyInstancesView
            } else {
                ForEach(instances) { instance in
                    NavigationLink {
                        InstanceDetailView(definition: definition, initialInstance: instance)
                    } label: {
                        InstanceCard(
                            instance: instance,
                            onTap: { selectedInstance = instance },
                            onEnter: { Task { await enterRoom(instance) } },
                            onDelete: { Task { await deleteInstance(instance) } }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Add Instance Button
            Button {
                showingAddInstance = true
            } label: {
                Label("Add New Instance", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var emptyInstancesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No instances yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add a location where you practice this room")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Colors
    
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
    
    // MARK: - Actions
    
    private func enterRoom(_ instance: RoomInstance) async {
        try? await firebaseManager.activateRoom(instance)
    }
    
    private func deleteInstance(_ instance: RoomInstance) async {
        try? await firebaseManager.deleteInstance(instance)
    }
}

// MARK: - Instance Card

struct InstanceCard: View {
    let instance: RoomInstance
    let onTap: () -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(instance.variantName.isEmpty ? "Unnamed" : instance.variantName)
                            .font(.subheadline.bold())
                        if instance.isActive {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(Int(instance.familiarityScore * 100))%", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(instance.currentFriction.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(frictionColor.opacity(0.2))
                            .foregroundStyle(frictionColor)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: onEnter) {
                        Image(systemName: instance.isActive ? "checkmark.circle.fill" : "arrow.right.circle")
                            .foregroundStyle(instance.isActive ? .green : .blue)
                    }
                    
                    Button(action: onTap) {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.title3)
            }
            
            if !instance.requiredInventory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(instance.requiredInventory, id: \.self) { item in
                            Text(item)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(instance.isActive ? .green : .clear, lineWidth: 2)
        )
    }
    
    private var frictionColor: Color {
        switch instance.currentFriction {
        case .zero: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - Add Instance Sheet

struct AddInstanceSheet: View {
    let definition: RoomDefinition
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var variantName = ""
    @State private var inventory = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("e.g., 'Standing Desk Home', 'Office Corner'", text: $variantName)
                }
                
                Section("Inventory") {
                    TextField("Required items (comma-separated)", text: $inventory)
                }
                
                Section {
                    Text("You can have multiple instances of \"\(definition.name)\" in different locations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Instance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addInstance() }
                    }
                    .disabled(variantName.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func addInstance() async {
        isLoading = true
        let items = inventory.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        try? await firebaseManager.createInstance(
            definitionId: definition.id,
            variantName: variantName,
            inventory: items
        )
        
        dismiss()
    }
}

// MARK: - Edit Instance Sheet

struct EditInstanceSheet: View {
    let definition: RoomDefinition
    let instance: RoomInstance
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var variantName = ""
    @State private var inventory = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Variant Name", text: $variantName)
                }
                
                Section("Inventory") {
                    TextField("Required items (comma-separated)", text: $inventory)
                }
                
                Section("Stats") {
                    LabeledContent("Familiarity", value: "\(Int(instance.familiarityScore * 100))%")
                    LabeledContent("Health", value: "\(Int(instance.healthScore * 100))%")
                    LabeledContent("Friction", value: instance.currentFriction.rawValue)
                }
                
                if let liturgy = instance.liturgy {
                    Section("Liturgy") {
                        Text("Entry: \(liturgy.entry)")
                        ForEach(Array(liturgy.steps.enumerated()), id: \.offset) { idx, step in
                            Text("Step \(idx + 1): \(step)")
                        }
                        Text("Exit: \(liturgy.exit)")
                    }
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
                variantName = instance.variantName
                inventory = instance.requiredInventory.joined(separator: ", ")
            }
        }
    }
    
    private func save() async {
        var updated = instance
        updated.variantName = variantName
        updated.requiredInventory = inventory.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        try? await firebaseManager.saveRoomInstance(updated)
        dismiss()
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

#Preview {
    NavigationStack {
        RoomDetailView(
            definition: RoomDefinition(
                number: "025",
                name: "The Cockpit",
                physicsHint: "High D, High A. Velocity.",
                function: "God-mode technical execution."
            )
        )
    }
}
