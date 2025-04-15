import SwiftUI

struct FilterView: View {
    @Binding var selectedLocationTypes: Set<RefillStation.LocationType>
    @Binding var selectedCostTypes: Set<RefillStation.RefillCost>
    @Binding var isPresented: Bool
    @Binding var searchRadius: Double // Added search radius binding
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search Radius")) {
                    VStack(alignment: .leading) {
                        Text("Show stations within \(Int(searchRadius)) mile\(searchRadius == 1 ? "" : "s")")
                            .font(.subheadline)
                        
                        Slider(value: $searchRadius, in: 1...10, step: 1)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Location Type")) {
                    ForEach(RefillStation.LocationType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { selectedLocationTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedLocationTypes.insert(type)
                                } else if selectedLocationTypes.count > 1 {
                                    selectedLocationTypes.remove(type)
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Cost")) {
                    ForEach(RefillStation.RefillCost.allCases, id: \.self) { cost in
                        Toggle(cost.rawValue, isOn: Binding(
                            get: { selectedCostTypes.contains(cost) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCostTypes.insert(cost)
                                } else if selectedCostTypes.count > 1 {
                                    selectedCostTypes.remove(cost)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarItems(
                leading: Button("Reset") {
                    selectedLocationTypes = Set(RefillStation.LocationType.allCases)
                    selectedCostTypes = Set(RefillStation.RefillCost.allCases)
                    searchRadius = 1.0 // Reset radius to default
                },
                trailing: Button("Done") { isPresented = false }
            )
        }
    }
}

#Preview {
    FilterView(
        selectedLocationTypes: .constant(Set(RefillStation.LocationType.allCases)),
        selectedCostTypes: .constant(Set(RefillStation.RefillCost.allCases)),
        isPresented: .constant(true),
        searchRadius: .constant(1.0)
    )
}
