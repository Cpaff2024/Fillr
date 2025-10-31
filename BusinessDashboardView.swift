import SwiftUI

struct BusinessDashboardView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var stationsViewModel = RefillStationsViewModel()
    @State private var showingAddLocation = false

    var body: some View {
        ZStack {
            if stationsViewModel.isLoading {
                ProgressView("Loading Your Locations...")
            } else if stationsViewModel.userStations.isEmpty {
                emptyStateView
            } else {
                stationListView
            }
        }
        .navigationTitle("Business Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddLocation = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddLocation, onDismiss: loadBusinessStations) {
            // This is the form we will build in the next step
            AddBusinessLocationView(isPresented: $showingAddLocation)
                .environmentObject(authManager)
                .environmentObject(stationsViewModel) // Pass the ViewModel
        }
        .onAppear(perform: loadBusinessStations)
    }

    private var stationListView: some View {
        List {
            ForEach(stationsViewModel.userStations) { station in
                StationRow(station: station)
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "mappin.slash.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Business Locations Added")
                .font(.title2)
                .bold()
            Text("Tap the '+' button to add your first business location.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func loadBusinessStations() {
        guard let userId = authManager.currentUser?.id else { return }
        // --- UPDATED to call the new function ---
        stationsViewModel.loadUserBusinessStations(userId: userId)
    }
}

#Preview {
    NavigationView {
        BusinessDashboardView()
            .environmentObject(AuthManager.shared)
    }
}
