import SwiftUI

struct FilterView: View {
    @Binding var selectedLocationTypes: Set<RefillStation.LocationType>
    @Binding var selectedCostTypes: Set<RefillStation.RefillCost>
    @Binding var isPresented: Bool
    @Binding var searchRadius: Double

    // Access all cases for convenience
    private let allLocationTypes = RefillStation.LocationType.allCases
    private let allCostTypes = RefillStation.RefillCost.allCases

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Search Radius Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Search Radius")
                            Spacer()
                            // Display radius in miles, handling pluralization
                            Text("\(Int(searchRadius)) mile\(searchRadius == 1 ? "" : "s")")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $searchRadius, in: 1...10, step: 1)
                    }
                    .padding(.vertical, 4) // Add padding for better spacing
                }

                // MARK: - Location Type Section
                // Use custom header showing selection count
                Section(header: sectionHeader(title: "Location Type", count: selectedLocationTypes.count, total: allLocationTypes.count),
                        // Use custom footer with Select/Deselect All
                        footer: selectAllFooter(for: $selectedLocationTypes, allCases: allLocationTypes)) {
                    // Iterate through all possible location types (will include 'Pub' now)
                    ForEach(allLocationTypes, id: \.self) { type in
                        // Make the row tappable
                        Button(action: { toggleSelection(for: type, in: $selectedLocationTypes) }) {
                            HStack {
                                // Show type icon and name
                                Label(type.rawValue, systemImage: type.icon)
                                    .foregroundColor(.primary) // Ensure text is readable
                                Spacer()
                                // Show checkmark if selected
                                if selectedLocationTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain) // Use plain style for row taps
                    }
                }

                // MARK: - Cost Section
                // Use custom header showing selection count
                Section(header: sectionHeader(title: "Cost", count: selectedCostTypes.count, total: allCostTypes.count),
                        // Use custom footer with Select/Deselect All
                        footer: selectAllFooter(for: $selectedCostTypes, allCases: allCostTypes)) {
                    // Iterate through all possible cost types
                    ForEach(allCostTypes, id: \.self) { cost in
                        // Make the row tappable
                        Button(action: { toggleSelection(for: cost, in: $selectedCostTypes) }) {
                            HStack {
                                // Show cost name
                                Text(cost.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                // Show checkmark if selected
                                if selectedCostTypes.contains(cost) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain) // Use plain style for row taps
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline) // Keep title inline
            .toolbar {
                // Add a Reset button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        // Reset all filters to default state
                        selectedLocationTypes = Set(allLocationTypes)
                        selectedCostTypes = Set(allCostTypes)
                        searchRadius = 1.0 // Reset radius to default
                    }
                    .tint(.red) // Make reset button red for visual cue
                }
                // Keep the Done button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold) // Make Done slightly bolder
                }
            }
        }
    }

    // MARK: - Helper Functions (Unchanged)

    // Generic function to toggle selection in a Set
    private func toggleSelection<T: Hashable>(for item: T, in selectionSet: Binding<Set<T>>) {
        if selectionSet.wrappedValue.contains(item) {
            // Prevent deselecting the last item to ensure at least one filter is active
            if selectionSet.wrappedValue.count > 1 {
                selectionSet.wrappedValue.remove(item)
            }
        } else {
            selectionSet.wrappedValue.insert(item)
        }
    }

    // Generic function to select all items
    private func selectAll<T: Hashable & CaseIterable>(in selectionSet: Binding<Set<T>>, allCases: [T]) {
        selectionSet.wrappedValue = Set(allCases)
    }

    // Generic function to deselect all items (leaving at least one)
    private func deselectAll<T: Hashable & CaseIterable>(in selectionSet: Binding<Set<T>>, allCases: [T]) {
         // Keep at least one item selected if possible, otherwise clear the set
        if let firstItem = allCases.first {
             selectionSet.wrappedValue = [firstItem]
        } else {
            selectionSet.wrappedValue = [] // Clear if there are no cases (shouldn't happen with CaseIterable)
        }
    }


    // Creates a header view showing the count of selected items
    @ViewBuilder
    private func sectionHeader(title: String, count: Int, total: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            // Show selection count or "All selected"
            if count < total {
                Text("\(count) of \(total) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(nil) // Prevent header text from being uppercased
            } else {
                 Text("All selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(nil) // Prevent header text from being uppercased
            }
        }
    }

     // Creates a footer with Select All / Deselect All buttons
    @ViewBuilder
    private func selectAllFooter<T: Hashable & CaseIterable>(for selectionSet: Binding<Set<T>>, allCases: [T]) -> some View {
        HStack {
            Button("Select All") {
                selectAll(in: selectionSet, allCases: allCases)
            }
            // Disable button if all items are already selected
            .disabled(selectionSet.wrappedValue.count == allCases.count)

            Spacer()

            Button("Deselect All") {
                 deselectAll(in: selectionSet, allCases: allCases)
            }
             // Disable button if only one or zero items are selected (can't deselect the last one)
             .disabled(selectionSet.wrappedValue.count <= 1)
        }
        .font(.caption) // Use smaller font for footer buttons
        .buttonStyle(.borderless) // Use a less prominent button style
        .padding(.top, 4) // Add some space above the buttons
        .textCase(nil) // Prevent footer text from being uppercased
    }
}

// MARK: - Preview
#Preview {
    // Keep the preview setup for testing
    FilterView(
        selectedLocationTypes: .constant(Set(RefillStation.LocationType.allCases)),
        selectedCostTypes: .constant(Set(RefillStation.RefillCost.allCases)),
        isPresented: .constant(true),
        searchRadius: .constant(1.0)
    )
}
