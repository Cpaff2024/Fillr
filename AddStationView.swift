import SwiftUI
import CoreLocation
import PhotosUI

struct AddStationView: View {
    // Environment
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager // Need for user ID when saving draft/station
    @EnvironmentObject var toastManager: ToastManager // NEW: Inject Toast Manager
    @Environment(\.dismiss) private var dismiss

    // Input Parameters & Callbacks
    @Binding var isPresented: Bool // Controls modal presentation
    let initialCoordinate: CLLocationCoordinate2D? // Coordinate if starting "here now"
    let existingDraft: RefillStation? // Draft being edited/completed
    let onSaveSubmit: (RefillStation, [UIImage]) -> Void // Closure for FINAL Firebase submission

    // Internal State (initialized based on draft or new)
    @State private var stationId: UUID
    @State private var name: String
    @State private var description: String
    // --- MODIFIED: Default to a user-addable type ---
    @State private var locationType: RefillStation.LocationType = .waterFountain
    @State private var cost: RefillStation.RefillCost
    @State private var limitations: String
    @State private var isCarAccessible: Bool
    @State private var manualAddress: String
    @State private var manualLocationDescription: String

    // Location & Workflow State
    @State private var isHereNow: Bool // Toggled by user
    @State private var currentCoordinate: CLLocationCoordinate2D? // Fetched/assigned coord

    // Photos State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    // Saving Process State
    @State private var isSaving = false // Disables form during save
    // REMOVED: @State private var showingSaveErrorAlert = false
    // REMOVED: @State private var saveErrorMessage = ""

    // --- NEW: Define location types allowed for user addition ---
    private let userAddableLocationTypes: [RefillStation.LocationType] = [
        .waterFountain, .publicSpace, .other
    ]

    // Computed Properties for Validation
    private var canSubmitFinal: Bool { // Validation for submitting to Firebase
        !name.isEmpty && currentCoordinate != nil && !selectedImages.isEmpty && isHereNow
    }
    private var canSubmitDraft: Bool { // Validation for saving draft locally
        !name.isEmpty && !isHereNow // Name required, must be in manual mode
    }

    // Initializer
    init(isPresented: Binding<Bool>, coordinate: CLLocationCoordinate2D?, draftToEdit: RefillStation? = nil, onSave: @escaping (RefillStation, [UIImage]) -> Void) {
        self._isPresented = isPresented
        self.initialCoordinate = coordinate
        self.existingDraft = draftToEdit
        self.onSaveSubmit = onSave // Renamed for clarity

        // Initialize state based on draft or new station
        if let draft = draftToEdit {
            _stationId = State(initialValue: draft.id)
            _name = State(initialValue: draft.name)
            _description = State(initialValue: draft.description)
            // Ensure draft type is selectable, default to .other if not
            _locationType = State(initialValue: userAddableLocationTypes.contains(draft.locationType) ? draft.locationType : .other)
            _cost = State(initialValue: draft.cost)
            _limitations = State(initialValue: draft.limitations)
            _isCarAccessible = State(initialValue: draft.isCarAccessible ?? false)
            _manualAddress = State(initialValue: draft.manualAddress ?? "")
            _manualLocationDescription = State(initialValue: draft.manualDescription ?? "")
            _isHereNow = State(initialValue: false) // Start in manual mode when editing draft
            _currentCoordinate = State(initialValue: draft.coordinate)
        } else {
            _stationId = State(initialValue: UUID())
            _name = State(initialValue: "")
            _description = State(initialValue: "")
            // Default location type is already set to .waterFountain
            _cost = State(initialValue: .free)
            _limitations = State(initialValue: "")
            _isCarAccessible = State(initialValue: false)
            _manualAddress = State(initialValue: "")
            _manualLocationDescription = State(initialValue: "")
            _isHereNow = State(initialValue: true) // Default to "here now"
            _currentCoordinate = State(initialValue: coordinate)
        }
    }

    // --- Body ---
    var body: some View {
        NavigationView {
            ZStack { // ZStack for potential saving overlay
                Form {
                    // --- Location Section ---
                    Section(header: Text("Location")) {
                        Toggle("I'm at the station now", isOn: $isHereNow)
                            .onChange(of: isHereNow) { _, newValue in
                                handleLocationToggle(isNowHere: newValue)
                            }

                        if isHereNow {
                            LocationDisplayView(coordinate: $currentCoordinate, initialCoordinate: initialCoordinate)
                        } else {
                            ManualLocationInputView(manualAddress: $manualAddress, manualDescription: $manualLocationDescription)
                        }
                    } // End Location Section

                    // --- Photos Section (Conditional) ---
                    if isHereNow {
                        Section(header: Text("Photos (Required for submission)")) {
                            PhotoSelectionView(selectedItems: $selectedItems, selectedImages: $selectedImages, showingPhotoOptions: $showingPhotoOptions)
                        }
                    } // End Photos Section

                    // --- Details Section ---
                    Section(header: Text("Details")) {
                        TextField("Station Name (Required)", text: $name)
                            .autocapitalization(.words)

                        // --- MODIFIED: Picker only shows user-addable types ---
                        Picker("Type", selection: $locationType) {
                            ForEach(userAddableLocationTypes, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        }
                        // --- END MODIFICATION ---

                        Picker("Cost", selection: $cost) {
                            ForEach(RefillStation.RefillCost.allCases, id: \.self) { cost in
                                Text(cost.rawValue).tag(cost)
                            }
                        }
                        Toggle(isOn: $isCarAccessible) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Easily Car Accessible")
                                Text("e.g., Roadside, park with parking") // Adjusted example
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }.padding(.vertical, 4)
                    } // End Details Section

                    // --- Description Section ---
                    Section(header: Text("Description")) {
                        TextEditor(text: $description)
                            .frame(minHeight: 80, maxHeight: 150)
                            .overlay(
                                Text("Describe how to find/use this refill point...") // Adjusted placeholder
                                    .foregroundColor(.gray.opacity(description.isEmpty ? 0.6 : 0))
                                    .padding(.top, 8).padding(.leading, 5)
                                    .allowsHitTesting(false), alignment: .topLeading
                            )
                    } // End Description Section

                    // --- Limitations Section ---
                    Section(header: Text("Limitations (Optional)")) {
                        TextField("e.g., Operating hours, accessibility notes", text: $limitations) // Adjusted placeholder
                    } // End Limitations Section

                } // End Form
                .navigationTitle(existingDraft == nil ? "Add Refill Point" : "Complete Refill Point") // Renamed title
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: handleSaveAction) {
                            Text(isHereNow ? "Submit Point" : "Save Draft") // Renamed button text
                        }
                        .disabled(isSaving || (isHereNow ? !canSubmitFinal : !canSubmitDraft))
                    }
                }
                .onChange(of: selectedItems) { _, newItems in loadImagesFromPicker(from: newItems) }
                .disabled(isSaving)
                // REMOVED: .alert(logic) as toast is used for user feedback
                
                // Saving overlay
                if isSaving {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text(isHereNow ? "Submitting..." : "Saving Draft...")
                            .font(.headline).foregroundColor(.white).padding(.top)
                    }
                }
            } // End ZStack
            .sheet(isPresented: $showingCamera) { CameraView(selectedImages: $selectedImages) }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 5, matching: .images)
            .confirmationDialog("Add Photos", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Photo Library") { showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .onReceive(locationManager.$location) { location in
                if isHereNow, let newCoordinate = location?.coordinate {
                    currentCoordinate = newCoordinate
                }
            }
            .onAppear {
                if isHereNow {
                    // **FIX #1**
                    locationManager.requestLocationPermissionAndUpdates()
                    currentCoordinate = locationManager.location?.coordinate ?? initialCoordinate
                }
                // Ensure the selected type is valid if loading a draft
                if let draft = existingDraft, !userAddableLocationTypes.contains(draft.locationType) {
                    locationType = .other // Default to other if draft had an invalid type for user editing
                }
            }
        } // End NavigationView
    } // End Body

    // --- Helper Functions ---

    private func handleLocationToggle(isNowHere: Bool) {
        // (Keep existing logic)
        if isNowHere {
            locationManager.requestLocationPermissionAndUpdates()
            currentCoordinate = locationManager.location?.coordinate ?? initialCoordinate
        } else {
            currentCoordinate = nil
        }
    }

    private func handleSaveAction() {
        isSaving = true
        guard let userId = authManager.currentUser?.id else {
             // UPDATED to use ToastManager
             toastManager.show(message: "You must be logged in to save.", isError: true)
             isSaving = false
             return
        }

        if isHereNow {
            // --- FINAL SUBMISSION (ALWAYS USER TYPE) ---
            guard currentCoordinate != nil else {
                // UPDATED to use ToastManager
                showError("Could not get current location.")
                return
            }
            guard !selectedImages.isEmpty else {
                // UPDATED to use ToastManager
                showError("Please add at least one photo.")
                return
            }

            let finalStation = RefillStation(
                id: stationId,
                coordinate: currentCoordinate, // Use currentCoordinate directly
                name: name, description: description,
                locationType: locationType, // Uses the selected user-addable type
                cost: cost, limitations: limitations,
                photoIDs: [], // Handled by FirebaseManager
                dateAdded: existingDraft?.dateAdded ?? Date(),
                addedByUserID: userId,
                listingType: .user, // --- SET EXPLICITLY ---
                isCarAccessible: isCarAccessible, isDraft: false,
                manualAddress: manualAddress,
                manualDescription: manualLocationDescription
            )
            print("DEBUG: AddStationView attempting FINAL submission for USER station \(finalStation.id)")
            onSaveSubmit(finalStation, selectedImages)
            // isSaving = false // Handled by callback

        } else {
            // --- SAVE DRAFT (ALWAYS USER TYPE) ---
            let draftStation = RefillStation(
                id: stationId, coordinate: nil, // No coord needed for draft
                name: name, description: description,
                locationType: locationType, // Uses the selected user-addable type
                cost: cost, limitations: limitations,
                photoIDs: [], dateAdded: Date(), addedByUserID: userId,
                listingType: .user, // --- SET EXPLICITLY ---
                isCarAccessible: isCarAccessible, isDraft: true, // Mark as draft
                manualAddress: manualAddress, manualDescription: manualLocationDescription
            )
            print("DEBUG: AddStationView saving USER draft \(draftStation.id)")
            DraftStorageManager.shared.saveDraft(draftStation)
            isSaving = false
            // UPDATED to use ToastManager
            toastManager.show(message: "Draft saved locally.", isError: false)
            dismiss() // Dismiss after saving draft locally
        }
    }

    // UPDATED: Simple wrapper to use ToastManager
    private func showError(_ message: String) {
         toastManager.show(message: message, isError: true)
         isSaving = false
     }

    private func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedItems.count { selectedItems.remove(at: index) }
    }

    private func loadImagesFromPicker(from items: [PhotosPickerItem]) {
        Task {
            var loadedImages: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                     loadedImages.append(image)
                 }
            }
             DispatchQueue.main.async {
                 self.selectedImages = loadedImages
             }
        }
    }

    // --- Nested Helper Views (Keep LocationDisplayView, ManualLocationInputView, PhotoSelectionView, CameraView as they were) ---
    struct LocationDisplayView: View {
         @Binding var coordinate: CLLocationCoordinate2D?
         let initialCoordinate: CLLocationCoordinate2D?
         @EnvironmentObject var locationManager: LocationManager

         var body: some View {
             HStack {
                 Image(systemName: "location.circle.fill").foregroundColor(.blue)
                 if let coord = coordinate {
                     VStack(alignment: .leading, spacing: 2) {
                         Text("Lat: \(String(format: "%.6f", coord.latitude))")
                         Text("Lon: \(String(format: "%.6f", coord.longitude))")
                     }.font(.caption)
                 } else {
                     Text("Getting location...")
                         .font(.caption).italic().foregroundColor(.secondary)
                 }
                 Spacer()
                 Button {
                     // **FIX #2**
                     locationManager.requestLocationPermissionAndUpdates()
                     coordinate = locationManager.location?.coordinate ?? initialCoordinate
                 } label: { Image(systemName: "arrow.clockwise.circle").foregroundColor(.blue) }
             }
         }
     }

     struct ManualLocationInputView: View {
         @Binding var manualAddress: String
         @Binding var manualDescription: String

         var body: some View {
             VStack(alignment: .leading) {
                 TextField("Address or Area (optional)", text: $manualAddress)
                 Text("Describe location (e.g., 'near park entrance')")
                     .font(.caption)
                     .foregroundColor(.secondary)
                     .padding(.top, 5)
                 TextEditor(text: $manualDescription)
                     .frame(minHeight: 60, maxHeight: 100)
                     .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
             }
         }
     }

    struct PhotoSelectionView: View {
        @Binding var selectedItems: [PhotosPickerItem]
        @Binding var selectedImages: [UIImage]
        @Binding var showingPhotoOptions: Bool

        private func removeImage(at index: Int) {
            guard index >= 0 && index < selectedImages.count else { return }
            selectedImages.remove(at: index)
            if index < selectedItems.count { selectedItems.remove(at: index) }
        }

        var body: some View {
            VStack(alignment: .leading) {
                Button(action: { showingPhotoOptions = true }) {
                    Label("Add Photos", systemImage: "camera")
                }
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable().scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        Button(action: { removeImage(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, Color.black.opacity(0.6))
                                                .font(.title2)
                                        }
                                        .padding(1),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(height: 110)
                } else {
                     Text("Tap 'Add Photos' to include pictures.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 5)
                }
            }
        }
    }

     // Nested Camera View
    struct CameraView: UIViewControllerRepresentable {
        @Binding var selectedImages: [UIImage]
        @Environment(\.presentationMode) private var presentationMode

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = .camera
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(self) }

        class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let parent: CameraView
            init(_ parent: CameraView) { self.parent = parent }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                if let image = info[.originalImage] as? UIImage {
                    parent.selectedImages.append(image)
                }
                parent.presentationMode.wrappedValue.dismiss()
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }

} // End AddStationView struct

// --- Preview ---
#Preview {
     AddStationView(
         isPresented: .constant(true),
         coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
         draftToEdit: nil, // Previewing a new station
         onSave: { _, _ in print("Preview Save Tapped") }
     )
     .environmentObject(LocationManager())
     .environmentObject(AuthManager.shared)
     .environmentObject(ToastManager.shared) // Inject ToastManager to Preview
}
