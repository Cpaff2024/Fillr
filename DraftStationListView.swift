import SwiftUI

struct DraftStationListView: View {
    // Keep existing State and EnvironmentObjects
    @State private var drafts: [RefillStation] = []
    @State private var selectedDraft: RefillStation?
    @State private var showingAddStationSheet = false
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager

    // Add StateObject for the ViewModel needed for submission
    // We might need this to call the addStation method which handles Firebase logic
    @StateObject private var stationsViewModel = RefillStationsViewModel()

    // State for showing toast messages
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

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
                            // --- START: Implemented Save Logic ---
                            print("✅ DraftListView: onSave closure triggered for submitting draft \(station.id)")

                            // Basic validation (should also be handled within AddStationView, but double check)
                            if station.coordinate == nil {
                                toastMessage = "Location data is missing."
                                toastIsError = true; withAnimation { showToast = true }; return
                            }
                            if photos.isEmpty {
                                toastMessage = "Please add at least one photo."
                                toastIsError = true; withAnimation { showToast = true }; return
                            }
                            guard let userId = authManager.currentUser?.id else {
                                toastMessage = "Error: Not logged in."
                                toastIsError = true; withAnimation { showToast = true }; return
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
                                    toastMessage = "Station submitted successfully!"
                                    toastIsError = false
                                    showingAddStationSheet = false // Dismiss sheet on success

                                } else {
                                    print("🔴 DraftListView: Firebase submission failed for \(finalStation.id): \(errorMsg ?? "Unknown error")")
                                    // Show error, DO NOT delete local draft, keep sheet open? Or dismiss? Let's dismiss.
                                    toastMessage = errorMsg ?? "Failed to submit station."
                                    toastIsError = true
                                    showingAddStationSheet = false // Dismiss sheet even on error for now
                                }
                                // Show toast message regardless of success/failure
                                withAnimation { showToast = true }
                            }
                            // --- END: Implemented Save Logic ---
                        }
                    )
                    .environmentObject(locationManager)
                    .environmentObject(authManager)
                    // We might need to pass stationsViewModel down too if AddStationView needs it directly,
                    // but for now, DraftStationListView uses its own instance.
                }
            }

            // --- Toast Message Overlay ---
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .padding()
                        .background(toastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                        .foregroundColor(.white).cornerRadius(10).shadow(radius: 3)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { // Longer duration
                                withAnimation { showToast = false }
                            }
                        }
                        .padding(.bottom)
                }
            }
            .padding(.horizontal)
            // --- End Toast Overlay ---

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
    }
}

// Keep Preview
#Preview {
    NavigationView {
        DraftStationListView()
           .environmentObject(AuthManager.shared)
           .environmentObject(LocationManager())
    }
}
