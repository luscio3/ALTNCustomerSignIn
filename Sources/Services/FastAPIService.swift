import Foundation

/// High-level calls to the FastAPI backend at `api.altn.cloud/api/v3`.
///
/// What this covers:
///   - Fetch services catalog (prices + tests) per franchise+location
///   - Fetch franchise info (custom category name)
///   - Look up or create a customer
///   - Submit a completed sign-in appointment
///   - Upload signed consent PDFs via the legacy endpoint (no-op for us: we use ALTNAdmin v2 instead)
struct FastAPIService {

    // MARK: - Services / franchise

    /// Fetch the catalog through ALTNAdmin's admin-api proxy so the kiosk honors
    /// the display order the franchisee chose in Settings → iPad Sign-in App.
    /// The proxy fetches from FastAPI and merges in our local `sort_order`.
    func fetchServices(franchise: String, location: String) async throws -> Services {
        let flat: [ServiceInfo] = try await Endpoints.consentAPI.get(
            "/ipad-services",
            query: [
                URLQueryItem(name: "franchise", value: franchise),
                URLQueryItem(name: "location",  value: location),
            ]
        )
        return Services(flat: flat)
    }

    func fetchFranchiseInfo(franchiseId: String) async throws -> FranchiseInfo {
        struct FranchiseEnvelope: Codable { let info: FranchiseInfo? }
        let env: FranchiseEnvelope = try await Endpoints.fastAPI.get("/franchise/\(franchiseId)")
        return env.info ?? FranchiseInfo(customCategoryName: nil)
    }

    // MARK: - Customer lookup / creation

    /// Look up an existing customer. Returns nil on 404 (new customer).
    func fetchPerson(_ info: PersonInfo) async throws -> Person? {
        do {
            struct Resp: Codable { let client_id: Int }
            let resp: Resp = try await Endpoints.fastAPI.get("/client", query: info.apiQueryItems)
            return Person(clientId: resp.client_id)
        } catch APIClient.APIError.status(404, _) {
            return nil
        }
    }

    /// Create a new customer. Body is a merged JSON dict of PersonInfo + NameGender + Address fields.
    /// Tighter timeout than the default 60s so a dead connection during the
    /// final submit fails fast → enqueued for retry, instead of looking frozen
    /// to the customer. The offline queue's dedup safeguards
    /// (drain reentry guard + fetchPerson preflight) catch the "server
    /// committed but client timed out" duplicate-customer case.
    func createPerson(jsonBody: Data) async throws -> Person {
        struct Resp: Codable { let client_id: Int }
        let resp: Resp = try await Endpoints.fastAPI.post("/client", jsonBody: jsonBody, timeout: Self.submitTimeout)
        return Person(clientId: resp.client_id)
    }

    // MARK: - Appointment submission

    /// POST the completed appointment. FastAPI returns 201 on success.
    func submitAppointment(jsonBody: Data) async throws {
        try await Endpoints.fastAPI.post("/client/appointment", jsonBody: jsonBody, timeout: Self.submitTimeout)
    }

    /// Per-call timeout for the end-of-flow submit chain.
    private static let submitTimeout: TimeInterval = 30
}
