import UIKit
import Combine

/// Drives Autonomous Single App Mode (ASAM) so the iPad locks itself to this
/// app — customers can't reach Safari, Mail, Messages, Control Center, the app
/// switcher, or any other app.
///
/// Requirements for the lock to actually engage (all device-side, no code
/// entitlement):
///   1. The iPad is **supervised** (Apple Configurator or MDM).
///   2. A configuration profile whitelists this app's bundle id
///      (`cloud.altn.customer-signin`) for Autonomous Single App Mode.
///      See `Resources/Kiosk/ALTN-Kiosk-ASAM.mobileconfig`.
///
/// On a non-supervised / non-whitelisted device (e.g. a TestFlight build on a
/// personal iPad) `requestGuidedAccessSession` simply fails silently — the app
/// keeps working, it just won't lock. That makes this safe to ship enabled.
@MainActor
final class KioskMode: ObservableObject {

    static let shared = KioskMode()

    /// True while the device is actually locked into the app (ASAM/Guided Access on).
    @Published private(set) var isLocked: Bool = UIAccessibility.isGuidedAccessEnabled

    /// Persistent "this iPad is a locked kiosk" flag. Flip on once per device
    /// after supervising + installing the profile.
    @Published var isEnabled: Bool {
        didSet {
            UserSettings.kioskEnabled = isEnabled
            if isEnabled {
                lock()
            } else {
                staffExit()   // turning kiosk off is itself an authorized exit
            }
        }
    }

    /// Set when staff intentionally leaves the app, so the foreground/auto
    /// re-lock logic doesn't immediately re-engage while they're working.
    /// Cleared automatically when the app next backgrounds (staff left).
    private var staffExitActive = false

    private init() {
        self.isEnabled = UserSettings.kioskEnabled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusChanged),
            name: UIAccessibility.guidedAccessStatusDidChangeNotification,
            object: nil
        )
        if isEnabled { lock() }
    }

    // MARK: - Lifecycle hooks (call from the App scenePhase observer)

    /// App became active. Re-assert the lock unless staff just exited on purpose.
    func enforceOnForeground() {
        guard isEnabled, !staffExitActive else { return }
        if !UIAccessibility.isGuidedAccessEnabled { lock() }
    }

    /// App went to the background. If staff had exited, they've now left —
    /// re-arm so the next foreground re-locks the device automatically.
    func armOnBackground() {
        staffExitActive = false
    }

    // MARK: - Locking

    func lock() {
        UIAccessibility.requestGuidedAccessSession(enabled: true) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = UIAccessibility.isGuidedAccessEnabled
            }
        }
    }

    /// Authorized exit (staff PIN verified, or kiosk toggled off). Drops the
    /// lock and suppresses auto re-lock until the app next backgrounds.
    func staffExit() {
        staffExitActive = true
        UIAccessibility.requestGuidedAccessSession(enabled: false) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = UIAccessibility.isGuidedAccessEnabled
            }
        }
    }

    // MARK: - Notifications

    @objc private func statusChanged() {
        isLocked = UIAccessibility.isGuidedAccessEnabled
        // If the lock dropped while it should be on and staff didn't ask for an
        // exit, re-assert it. Guards against an accidental/edge-case disengage.
        if isEnabled, !isLocked, !staffExitActive {
            lock()
        }
    }

    // MARK: - Staff PIN

    /// Default PIN is the franchise number (0035) — memorable to staff, not
    /// obvious to a walk-up customer. Change it in Admin → Kiosk Lock.
    static let defaultPIN = "0035"

    var pin: String { UserSettings.kioskPIN ?? Self.defaultPIN }

    func verify(pin entered: String) -> Bool {
        entered == pin
    }

    func setPIN(_ newPIN: String) {
        UserSettings.kioskPIN = newPIN
    }
}
