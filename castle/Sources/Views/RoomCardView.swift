// RoomCardView.swift
// Compact card for displaying a room in grids

import SwiftUI

struct RoomCardView: View {
    let definition: RoomDefinition
    let instance: RoomInstance?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(definition.number)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if instance?.isActive == true {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                }
            }
            
            // Name
            Text(definition.name)
                .font(.subheadline.bold())
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Function
            Text(definition.function)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                PhysicsBadge(
                    dionysian: definition.dionysianLevel,
                    apollonian: definition.apollonianLevel
                )
                
                Spacer()
                
                if let instance = instance {
                    FamiliarityIndicator(score: instance.familiarityScore)
                }
            }
        }
        .padding(12)
        .frame(minHeight: 140)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(instance?.isActive == true ? .green : .clear, lineWidth: 2)
        )
    }
    
    private var cardBackground: some ShapeStyle {
        if instance?.isActive == true {
            return AnyShapeStyle(.green.opacity(0.1))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}

// MARK: - Familiarity Indicator

struct FamiliarityIndicator: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < levelCount ? levelColor : .secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var levelCount: Int {
        if score >= 0.7 { return 3 }
        if score >= 0.3 { return 2 }
        if score > 0 { return 1 }
        return 0
    }
    
    private var levelColor: Color {
        if score >= 0.7 { return .green }
        if score >= 0.3 { return .yellow }
        return .orange
    }
}

#Preview {
    HStack {
        RoomCardView(
            definition: RoomDefinition(
                number: "013",
                name: "The Morning Chapel",
                physicsHint: "Low D, High A. Signal calibration.",
                function: "Setting the trajectory. Zero external input."
            ),
            instance: nil
        )
        
        RoomCardView(
            definition: RoomDefinition(
                number: "025",
                name: "The Cockpit",
                physicsHint: "High D, High A. Velocity.",
                function: "God-mode technical execution."
            ),
            instance: RoomInstance(
                definitionId: "025",
                variantName: "Standing Desk",
                familiarityScore: 0.8,
                isActive: true
            )
        )
    }
    .padding()
}
