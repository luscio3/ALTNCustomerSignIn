import Foundation

/// Static configuration for the two backends the app talks to.
enum Endpoints {

    // MARK: - FastAPI (customer-facing: person lookup, services, franchise info, appointments)
    /// Production host. Flutter app had a sandbox toggle; we default to production.
    static let fastAPI = APIClient(
        baseURL: URL(string: "https://api.altn.cloud/api/v3")!
    )

    // MARK: - ALTNAdmin PHP v2 (consent form templates + signed-consent upload)
    /// Admin API, Bearer-token auth. Same token the macOS app uses.
    static let consentAPI = APIClient(
        baseURL: URL(string: "https://admin-api.altn.cloud/api/v2")!,
        defaultHeaders: [
            "Authorization": "Bearer \(Secrets.altnAdminBearerToken)"
        ]
    )
}

enum Secrets {
    /// Hard-coded same as ALTNAdmin macOS app. This is a kiosk on iPads you physically control,
    /// so baking the token in is acceptable per the current auth model.
    static let altnAdminBearerToken = "altn-v2-96lasxcudhb0ziy27bg50c9r"
}
