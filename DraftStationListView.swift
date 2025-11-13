import SwiftUI

struct DraftStationListView: View {
    // Keep existing State and EnvironmentObjects
    @State private var drafts: [RefillStation] = []
    @State private var selectedDraft: RefillStation?
    @State private var showingAddStationSheet = false
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager

    // Add StateObject for the ViewModel needed for submission
    @StateObject private var stationsViewModel = RefillStationsViewModel()

    // NEW: Inject Toast Manager
    @EnvironmentObject private var toastManager: ToastManager
    
    // Removed local toast state: showToast, toastMessage, toastIsError

    var body: some View {
        // Wrap ZStack for Toast Overlay
        ZStack {
            VStack { // Original content VStack
                if drafts.isEmpty {
                    // Nicer empty state view (Keep existing)
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("No Draft Stations")
                            .font(.title2)
                            .bold()
                        Text("Stations saved as drafts will appear here.\nTap a draft to complete and submit it.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 50)

                } else {
                    List {
                        Text("Tap a draft to add photos, confirm location, and submit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowSeparator(.hidden) // Hide separator for instruction text

                        ForEach(drafts) { draft in
                            Button {
                                selectedDraft = draft
                                showingAddStationSheet = true // Trigger sheet
                            } label: {
                                // List Row Content (Keep existing)
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(draft.name).font(.headline)
                                        Text(draft.manualDescription?.isEmpty == false ? draft.manualDescription! : (draft.manualAddress ?? "No location info"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Text("Draft saved: \(draft.dateAdded, style: .relative) ago")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteDraft)
                    }
                    .listStyle(.insetGrouped)
                }
            } // End Original VStack
            .navigationTitle("Draft Stations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
            .onAppear(perform: loadDrafts)
            .sheet(isPresented: $showingAddStationSheet, onDismiss: loadDrafts) {
                if let draftToComplete = selectedDraft {
                    // Present AddStationView, passing the REAL save closure
                    AddStationView(
                        isPresented: $showingAddStationSheet,
                        coordinate: nil, // AddStationView will handle fetching location if needed
                        draftToEdit: draftToComplete,
                        onSave: { station, photos in
                            // --- START: Implemented Save Logic (UPDATED for ToastManager) ---
                            print("✅ DraftListView: onSave closure triggered for submitting draft \(station.id)")

                            // Basic validation (should also be handled within AddStationView, but double check)
                            if station.coordinate == nil {
                                toastManager.show(message: "Location data is missing.", isError: true)
                                return
                            }
                            if photos.isEmpty {
                                toastManager.show(message: "Please add at least one photo.", isError: true)
                                return
                            }
                            guard let userId = authManager.currentUser?.id else {
                                toastManager.show(message: "Error: Not logged in.", isError: true)
                                return
                            }

                            // Ensure the station being submitted has the correct user ID and is not a draft
                            var finalStation = station
                            finalStation.addedByUserID = userId
                            finalStation.isDraft = false // Explicitly mark as not a draft

                            // Use the ViewModel to handle the Firebase submission
                            stationsViewModel.addStation(finalStation, photos: photos) { success, errorMsg in
                                if success {
                                    print("✅ DraftListView: Firebase submission successful for \(finalStation.id). Deleting local draft.")
                                    // ** Crucially, delete the draft locally ONLY AFTER successful Firebase save **
                                    DraftStorageManager.shared.deleteDraft(id: finalStation.id)

                                    // Dismiss the sheet and show success
                                    toastManager.show(message: "Station submitted successfully!", isError: false)
                                    showingAddStationSheet = false // Dismiss sheet on success

                                } else {
                                    print("🔴 DraftListView: Firebase submission failed for \(finalStation.id): \(errorMsg ?? "Unknown error")")
                                    // Show error, DO NOT delete local draft.
                                    toastManager.show(message: errorMsg ?? "Failed to submit station.", isError: true)
                                    showingAddStationSheet = false // Dismiss sheet even on error for now
                                }
                                // No separate toast trigger needed as it's handled inside the completion block
                            }
                            // --- END: Implemented Save Logic ---
                        }
                    )
                    .environmentObject(locationManager)
                    .environmentObject(authManager)
                    .environmentObject(toastManager) // Inject ToastManager
                }
            }

            // --- REMOVED: Toast Message Overlay as it is global now ---
            // The global ToastOverlay is typically placed in the root view (MapView in this case).

        } // End ZStack

    } // End body

    func loadDrafts() {
        drafts = DraftStorageManager.shared.loadDrafts().sorted { $0.dateAdded > $1.dateAdded }
    }

    func deleteDraft(at offsets: IndexSet) {
        let draftsToDelete = offsets.map { drafts[$0] }
        drafts.remove(atOffsets: offsets)
        draftsToDelete.forEach { draft in
            DraftStorageManager.shared.deleteDraft(id: draft.id)
            print("🗑️ Deleted draft \(draft.id) directly from list view.")
        }
        // OPTIONAL: Show a confirmation toast upon deletion
        toastManager.show(message: "Draft deleted.", isError: false)
    }
}

// Keep Preview
#Preview {
    NavigationView {
        DraftStationListView()
           .environmentObject(AuthManager.shared)
           .environmentObject(LocationManager())
           .environmentObject(ToastManager.shared)
    }
}
