import CoreLocation
import Foundation

/// Где ты сейчас.
///
/// Разрешение спрашивается не при запуске, а по явному действию: диалог,
/// выскочивший на первом кадре без объяснений, половина людей закрывает
/// не читая — и второго шанса система уже не даст.
///
/// Координаты никуда не уходят: они нужны только чтобы найти страну
/// в уже загруженной геометрии и поставить метку на карте.
final class LocationService: NSObject, ObservableObject {

    enum Access: Equatable {
        /// Ещё не спрашивали.
        case notDetermined
        case granted
        case denied
        /// Геолокация выключена целиком или запрещена родительским контролем.
        case unavailable
    }

    @Published private(set) var access: Access = .notDetermined
    @Published private(set) var coordinate: Coordinate?
    @Published private(set) var isLocating = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Точность города более чем достаточна: нам нужна страна, а не адрес.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        access = Self.access(for: manager.authorizationStatus)
    }

    /// Спросить разрешение и, если оно есть, определить местоположение.
    func locate() {
        switch access {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .granted:
            requestFix()
        case .denied, .unavailable:
            break
        }
    }

    private func requestFix() {
        guard !isLocating else { return }
        isLocating = true
        manager.requestLocation()
    }

    private static func access(for status: CLAuthorizationStatus) -> Access {
        switch status {
        case .notDetermined:              return .notDetermined
        case .authorizedWhenInUse,
             .authorizedAlways:           return .granted
        case .denied:                     return .denied
        case .restricted:                 return .unavailable
        @unknown default:                 return .unavailable
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        access = Self.access(for: manager.authorizationStatus)
        if access == .granted {
            requestFix()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        guard let location = locations.last else { return }
        coordinate = Coordinate(
            longitude: location.coordinate.longitude,
            latitude: location.coordinate.latitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Молча: без координат приложение полностью работоспособно.
        isLocating = false
    }
}
