import Foundation
import MapKit
import Combine
import SwiftUI // For ObservableObject, Published (though not strictly needed for Equatable extensions)

// MARK: - Equatable Conformance for MapKit Types
// DEFINE THESE ONCE GLOBALLY - This is a good central place if MapView also needs them.

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension MKCoordinateSpan: Equatable {
    public static func == (lhs: MKCoordinateSpan, rhs: MKCoordinateSpan) -> Bool {
        return lhs.latitudeDelta == rhs.latitudeDelta && lhs.longitudeDelta == rhs.longitudeDelta
    }
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

class MapRegionDebouncer: ObservableObject {
    @Published var debouncedRegion: MKCoordinateRegion? = nil
    
    private var regionInputSubject = PassthroughSubject<MKCoordinateRegion, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .seconds(1.0)) {
        regionInputSubject
            .debounce(for: debounceInterval, scheduler: DispatchQueue.main)
            .removeDuplicates() // Requires MKCoordinateRegion to be Equatable
            .sink { [weak self] region in
                guard let self = self else { return }
                print("MapRegionDebouncer: Debounced region received: \(region.center)")
                self.debouncedRegion = region
            }
            .store(in: &cancellables)
        print("MapRegionDebouncer: Initialized.")
    }

    deinit {
        print("MapRegionDebouncer: Deinitialized.")
        cancellables.forEach { $0.cancel() }
    }

    public func regionDidChange(to newRegion: MKCoordinateRegion) {
        regionInputSubject.send(newRegion)
    }
}
