import Foundation

/// Persistent (UserDefaults-backed) settings for the kiosk.
enum UserSettings {

    private static let d = UserDefaults.standard

    // MARK: - Franchise / location

    static var storeNumber: String? {
        get { d.string(forKey: "altn.storeNumber") }
        set { d.setValue(newValue, forKey: "altn.storeNumber") }
    }

    static var franchise: Franchise? {
        get {
            guard let id = d.string(forKey: "altn.franchiseId") else { return nil }
            return Franchise(id: id)
        }
        set { d.setValue(newValue?.id, forKey: "altn.franchiseId") }
    }

    static var location: LocationRef? {
        get {
            guard let id = d.string(forKey: "altn.locationId") else { return nil }
            return LocationRef(id: id)
        }
        set { d.setValue(newValue?.id, forKey: "altn.locationId") }
    }

    // MARK: - Kiosk lock (Autonomous Single App Mode)

    /// When true the app keeps the iPad locked to itself (ASAM). Set once per
    /// device after supervising + installing the ASAM profile.
    static var kioskEnabled: Bool {
        get { d.bool(forKey: "altn.kioskEnabled") }
        set { d.setValue(newValue, forKey: "altn.kioskEnabled") }
    }

    /// Staff PIN to exit the kiosk lock. Nil ⇒ use `KioskMode.defaultPIN`.
    static var kioskPIN: String? {
        get { d.string(forKey: "altn.kioskPIN") }
        set { d.setValue(newValue, forKey: "altn.kioskPIN") }
    }
}
