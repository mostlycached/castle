// BlueprintView.swift
// Card view of all 72 Room Classes organized by Wing

import SwiftUI

struct BlueprintView: View {
    @StateObject private var roomLoader = RoomLoader.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @State private var searchText = ""
    @State private var selectedWing: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Wing Filter
                    wingFilterSection
                    
                    // Rooms Grid
                    ForEach(filteredWings) { wing in
                        wingSection(wing)
                    }
                }
                .padding()
            }
            .navigationTitle("Blueprint")
            .searchable(text: $searchText, prompt: "Search rooms...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            try? await firebaseManager.seedRooms()
                        }
                    } label: {
                        Label("Seed Rooms", systemImage: "arrow.down.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredWings: [Wing] {
        roomLoader.wings.filter { wing in
            if let selected = selectedWing, selected != wing.wing {
                return false
            }
            if searchText.isEmpty {
                return true
            }
            return wing.rooms.contains { room in
                room.name.localizedCaseInsensitiveContains(searchText) ||
                room.function.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func filteredRooms(in wing: Wing) -> [RoomDefinition] {
        if searchText.isEmpty {
            return wing.rooms
        }
        return wing.rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.function.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Components
    
    private var wingFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", isSelected: selectedWing == nil) {
                    selectedWing = nil
                }
                
                ForEach(roomLoader.wings) { wing in
                    FilterChip(
                        title: wingShortName(wing.wing),
                        isSelected: selectedWing == wing.wing
                    ) {
                        selectedWing = wing.wing
                    }
                }
            }
        }
    }
    
    private func wingSection(_ wing: Wing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(wing.wing)
                    .font(.headline)
                Spacer()
                Text("\(wing.rooms.count) rooms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filteredRooms(in: wing)) { room in
                    NavigationLink {
                        RoomDetailView(definition: room)
                    } label: {
                        RoomCardView(
                            definition: room,
                            instance: firebaseManager.instance(for: room.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func wingShortName(_ full: String) -> String {
        // Extract roman numeral + short name: "I. Foundation (Restoration)" -> "I. Foundation"
        let parts = full.components(separatedBy: " (")
        return parts.first ?? full
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? .blue : .secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    BlueprintView()
}
