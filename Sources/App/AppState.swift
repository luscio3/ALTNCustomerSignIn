import Foundation
import SwiftUI

/// Owns the in-progress sign-in request as the user steps through the flow.
/// Mirrors the Flutter app's progressive request-building chain:
/// franchise → location → category → options → person → complete.
///
/// Each page mutates the relevant slice and calls `advance()` to push the next page.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Navigation stack
    @Published var path: [Route] = []

    // MARK: - Durable settings
    @Published var storeNumber: String = UserSettings.storeNumber ?? ""
    @Published var franchise: Franchise? = UserSettings.franchise
    @Published var location: LocationRef? = UserSettings.location

    // MARK: - Services catalog (per franchise+location), cached for offline
    @Published var services: Services?

    /// Why the most recent catalog refresh failed. Nil after a successful refresh.
    /// Drives the EmptyCatalogNotice copy so an auth failure (stale baked-in token,
    /// e.g. an outdated app build after a key rotation) isn't misreported as "offline".
    @Published var catalogFailure: CatalogFailure?

    enum CatalogFailure {
        case offline        // transport error — no route to the server
        case unauthorized   // server rejected our token (401/403) — app build is stale
        case serverError    // reached the server, got a non-auth HTTP error
    }

    // MARK: - Franchise info (vitamin category name override)
    @Published var franchiseInfo: FranchiseInfo?

    // MARK: - In-progress request
    @Published var draft = SignInDraft()

    // MARK: - Navigation

    func startNewRequest() {
        draft = SignInDraft()
        path = [.category]
    }

    func push(_ route: Route) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }

    // MARK: - Persisted writes

    func saveFranchise(_ franchise: Franchise, location: LocationRef, rawStoreNumber: String) {
        self.franchise = franchise
        self.location = location
        self.storeNumber = rawStoreNumber
        UserSettings.storeNumber = rawStoreNumber
        UserSettings.franchise = franchise
        UserSettings.location = location
    }
}

/// Every route the flow can push.
enum Route: Hashable {
    case category
    case chooseInjection
    case chooseDrugsOrAlcohol
    case chooseDna
    case chooseLabTest
    case std
    case personInfo
    case fullPersonInfo
    case address
    case consent
    case finish
}

/// The accumulated answers for a single in-progress sign-in.
struct SignInDraft: Equatable {
    var category: CustomerCategory?
    var injection: ServiceInfo?
    var drugsOrAlcohol: DrugsOrAlcoholData?
    var dnaSelections: [ServiceInfo] = []
    var labTest: ServiceInfo?
    var stdSelection: StdSelection?
    var phone: String = ""
    var dateOfBirth: Date?
    var person: Person?      // populated after /client lookup (existing customer)
    var nameGender: NameGender?  // new-customer fields
    var address: Address?        // new-customer fields
}
