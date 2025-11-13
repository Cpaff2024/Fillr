import SwiftUI
import CoreLocation

struct AddBusinessLocationView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var stationsViewModel: RefillStationsViewModel
    // NEW: Inject Toast Manager
    @EnvironmentObject var toastManager: ToastManager

    // Form state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var address: String = "" // Street, City, Postcode
    @State private var locationType: RefillStation.LocationType = .cafe
    @State private var cost: RefillStation.RefillCost = .purchaseRequired
    @State private var limitations: String = ""
    @State private var isCarAccessible: Bool = false
    
    @State private var isSaving = false
    // REMOVED: @State private var errorMessage: String?
    // REMOVED: @State private var showingError = false

    private let businessLocationTypes: [RefillStation.LocationType] = [
        .cafe, .restaurant, .shop, .pub, .other
    ]
    
    // --- THIS IS THE FIX ---
    // Explicitly defining the initializer removes the compiler's confusion.
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    // --- END OF FIX ---

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Business Details")) {
                    TextField("Business Name", text: $name)
                    Picker("Business Type", selection: $locationType) {
                        ForEach(businessLocationTypes, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section(header: Text("Location Address")) {
                    TextField("Full Address (e.g., 123 High St, London)", text: $address)
                    Text("We'll convert this to map coordinates.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Refill Service Details")) {
                    Picker("Refill Cost", selection: $cost) {
                        ForEach(RefillStation.RefillCost.allCases, id: \.self) { cost in
                            Text(cost.rawValue).tag(cost)
                        }
                    }
                    TextField("Limitations (e.g., Opening hours)", text: $limitations)
                    Toggle("Easily Car Accessible", isOn: $isCarAccessible)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                             Text("Describe your refill service...")
                                 .foregroundColor(.gray.opacity(description.isEmpty ? 0.6 : 0))
                                 .padding(.top, 8).padding(.leading, 5)
                                 .allowsHitTesting(false), alignment: .topLeading
                         )
                }
            }
            .navigationTitle("New Business Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveBusinessLocation)
                        .disabled(name.isEmpty || address.isEmpty || isSaving)
                }
            }
            .overlay(isSaving ? ProgressView("Saving...") : nil)
            // REMOVED: .alert modifier
        }
    }

    private func saveBusinessLocation() {
        isSaving = true
        
        // Convert address to coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                // UPDATED: Use ToastManager
                toastManager.show(message: "Could not find coordinates for address. Error: \(error.localizedDescription)", isError: true)
                self.isSaving = false
                return
            }
            
            guard let coordinate = placemarks?.first?.location?.coordinate else {
                // UPDATED: Use ToastManager
                toastManager.show(message: "Address found, but could not determine map coordinates.", isError: true)
                self.isSaving = false
                return
            }
            
            guard let userId = authManager.currentUser?.id else {
                // UPDATED: Use ToastManager
                toastManager.show(message: "You must be logged in.", isError: true)
                self.isSaving = false
                return
            }

            // Create RefillStation object
            let newStation = RefillStation(
                coordinate: coordinate,
                name: name,
                description: description,
                locationType: locationType,
                cost: cost,
                limitations: limitations,
                photoIDs: [], // No photos for MVP
                addedByUserID: userId,
                listingType: .business, // Set type to business
                isCarAccessible: isCarAccessible,
                isDraft: false, // Not a draft
                manualAddress: address // Store the address string
            )
            
            // Call ViewModel to save (with no photos)
            stationsViewModel.addStation(newStation, photos: []) { success, errorMsg in
                self.isSaving = false
                if success {
                    // UPDATED: Use ToastManager for success
                    toastManager.show(message: "Business location submitted for review!", isError: false)
                    isPresented = false // Dismiss sheet on success
                } else {
                    // UPDATED: Use ToastManager for error
                    toastManager.show(message: errorMsg ?? "An unknown error occurred while saving.", isError: true)
                }
            }
        }
    }
}
