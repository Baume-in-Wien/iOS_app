import Foundation
import CoreLocation
import Combine

@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isTracking = false
    var heading: CLHeading?

    var totalDistanceTraveled: Double = 0
    private var lastLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }

        isTracking = true
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func resetDistanceTracking() {
        totalDistanceTraveled = 0
        lastLocation = nil
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: target)
    }

    func bearing(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }

        let lat1 = current.coordinate.latitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let lon1 = current.coordinate.longitude * .pi / 180
        let lon2 = coordinate.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }

    func isWithinRange(of tree: Tree, range: Double = 20) -> Bool {
        guard let distance = distance(to: tree.coordinate) else { return false }
        return distance <= range
    }

    func getCurrentLocation() async -> CLLocation? {
        if let location = currentLocation {
            return location
        }

        if !isTracking {
            startTracking()
        }

        for _ in 0..<50 {
            if let location = currentLocation {
                return location
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return currentLocation
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        guard location.horizontalAccuracy < 50 else { return }

        if let last = lastLocation {
            let distance = location.distance(from: last)
            if distance > 0 && distance < 100 {
                totalDistanceTraveled += distance

                let savedDistance = UserDefaults.standard.double(forKey: "totalDistanceWalked")
                UserDefaults.standard.set(savedDistance + distance, forKey: "totalDistanceWalked")
            }
        }
        lastLocation = location

        currentLocation = location
        AppState.shared.userLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        AppState.shared.locationAuthorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
