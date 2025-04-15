import SwiftUI
import CoreLocation
import PhotosUI

struct AddStationView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var isPresented: Bool
    @State var coordinate: CLLocationCoordinate2D
    let onSave: (RefillStation, [UIImage]) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var locationType = RefillStation.LocationType.waterFountain
    @State private var cost = RefillStation.RefillCost.free
    @State private var limitations = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var isHereNow = true
    @State private var manualAddress = ""
    @State private var manualLocationDescription = "" // New state for description
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Location")) {
                        Toggle("I'm here now", isOn: $isHereNow)
                            .onChange(of: isHereNow) { newValue in
                                if newValue {
                                    locationManager.requestLocation()
                                    if let currentLocation = locationManager.location?.coordinate {
                                        coordinate = currentLocation
                                    }
                                }
                            }
                        
                        if isHereNow {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Latitude: \(String(format: "%.6f", coordinate.latitude))")
                                    Text("Longitude: \(String(format: "%.6f", coordinate.longitude))")
                                }
                                .font(.caption)
                            }
                        } else {
                            TextField("Enter address (optional)", text: $manualAddress)
                            TextEditor(text: $manualLocationDescription)
                                .frame(height: 80)
                                .border(Color.gray)
                                .padding(.vertical, 4)
                                .overlay(
                                    Text("Describe the location (e.g., near a landmark)")
                                        .foregroundColor(.gray)
                                        .opacity(manualLocationDescription.isEmpty ? 0.5 : 0)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 8),
                                    alignment: .topLeading
                                )
                        }
                    }
                    
                    Section(header: Text("Photos")) {
                        Button(action: {
                            showingPhotoOptions = true
                        }) {
                            Label("Add Photos", systemImage: "camera")
                        }
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(0..<selectedImages.count, id: \.self) { index in
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                    if index < selectedItems.count {
                                                        selectedItems.remove(at: index)
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Color.black.opacity(0.6))
                                                        .clipShape(Circle())
                                                }
                                                    .padding(4),
                                                alignment: .topTrailing
                                            )
                                    }
                                }
                            }
                            .frame(height: 120)
                        }
                    }
                    
                    Section(header: Text("Details")) {
                        TextField("Name", text: $name)
                            .autocapitalization(.words)
                        Picker("Type", selection: $locationType) {
                            ForEach(RefillStation.LocationType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        Picker("Cost", selection: $cost) {
                            ForEach(RefillStation.RefillCost.allCases, id: \.self) { cost in
                                Text(cost.rawValue).tag(cost)
                            }
                        }
                    }
                    
                    Section(header: Text("Description")) {
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .overlay(
                                Group {
                                    if description.isEmpty {
                                        Text("Describe where to find this refill station...")
                                            .foregroundColor(.gray)
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )
                    }
                    
                    Section(header: Text("Limitations (Optional)")) {
                        TextField("e.g., hours, conditions", text: $limitations)
                    }
                }
                .navigationTitle("Add Refill Station")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            print("DEBUG: Canceling add station")
                            isPresented = false
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveStation()
                        }
                        .disabled(name.isEmpty || selectedImages.isEmpty || isSaving)
                    }
                }
                .onChange(of: selectedItems) { oldValue, newValue in
                    print("DEBUG: Selected items changed, count: \(newValue.count)")
                    loadImagesFromPicker(from: newValue)
                }
                .disabled(isSaving)
                
                if isSaving {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Saving station...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImages)
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images
            )
            .confirmationDialog(
                "Add Photos",
                isPresented: $showingPhotoOptions,
                titleVisibility: .visible
            ) {
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose from Photo Library") {
                    showingPhotoPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            print("DEBUG: AddStationView appeared with coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        }
    }
    
    private func loadImagesFromPicker(from items: [PhotosPickerItem]) {
        print("DEBUG: Loading \(items.count) images from picker")
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            print("DEBUG: Successfully loaded image")
                            selectedImages.append(image)
                        }
                    case .failure(let error):
                        print("DEBUG: Failed to load image: \(error.localizedDescription)")
                    }
                }
            }
        }
    

    private func isOnline() -> Bool {
        // For simplicity, we'll just return true for now.
        // In a real app, you would check the network status here.
        return true
    }

    private func saveStation() {
        let finalCoordinate = isHereNow ? coordinate : CLLocationCoordinate2D(latitude: 0, longitude: 0) // Placeholder for now
        let newStation = RefillStation(id: UUID(),
                                        coordinate: finalCoordinate,
                                        name: name,
                                        description: description,
                                        locationType: locationType,
                                        cost: cost,
                                        limitations: limitations,
                                        photos: selectedImages,
                                        photoIDs: [],
                                        dateAdded: Date(),
                                        addedByUserID: "",
                                        manualAddress: isHereNow ? nil : manualAddress, // Save manual address
                                        manualDescription: isHereNow ? nil : manualLocationDescription) // Save manual description
        print("DEBUG: Calling onSave with station: \(newStation.name) at \(newStation.coordinate.latitude), \(newStation.coordinate.longitude) with manual address: \(newStation.manualAddress ?? "nil") and description: \(newStation.manualDescription ?? "nil")")

        if isOnline() {
            onSave(newStation, selectedImages) // Save to Firebase if online
        } else {
            // Save locally using UserDefaults
            var offlineStations = UserDefaults.standard.array(forKey: "offlineStations") as? [[String: Any]] ?? []
            let stationData: [String: Any] = [
                "name": newStation.name,
                "description": newStation.description,
                "locationType": newStation.locationType.rawValue,
                "cost": newStation.cost.rawValue,
                "limitations": newStation.limitations,
                "manualAddress": newStation.manualAddress ?? "",
                "manualDescription": newStation.manualDescription ?? "",
                "latitude": newStation.coordinate.latitude,
                "longitude": newStation.coordinate.longitude,
                "dateAdded": newStation.dateAdded.timeIntervalSince1970,
                "addedByUserID": newStation.addedByUserID,
                "photoCount": newStation.photos.count // We'll handle photos later
            ]
            offlineStations.append(stationData)
            UserDefaults.standard.set(offlineStations, forKey: "offlineStations")
            print("DEBUG: Station saved locally for offline use.")
            isPresented = false // Dismiss the view after saving locally
        }
        isSaving = false
    }
}

// Camera view for taking photos directly
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: [UIImage]
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                print("DEBUG: Camera captured new image")
                parent.image.append(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddStationView(
        isPresented: .constant(true),
        coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        onSave: { _, _ in }
    )
}
