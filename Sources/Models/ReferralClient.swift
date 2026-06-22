import Foundation

/// A B2B account ("Client") from the ALTNAdmin Clients module — i.e. the
/// employers / schools / courts / clinics that "send" customers in for a
/// drug screen. Surfaced as autocomplete suggestions under the
/// "Who sent you?" field so a typed referrer can be matched to a real account
/// and the resulting appointment auto-linked to it.
///
/// Decoded from `GET /api/v2/clients?search=` on the ALTNAdmin admin API.
struct ReferralClient: Codable, Hashable, Identifiable {
    let id: Int
    let companyName: String
    let franchise: String?
    let location: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case companyName = "company_name"
        case franchise
        case location
        case isActive    = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id can arrive as Int or String depending on the row.
        if let i = try? c.decode(Int.self, forKey: .id) {
            id = i
        } else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) {
            id = i
        } else {
            id = 0
        }
        companyName = (try? c.decode(String.self, forKey: .companyName)) ?? ""
        franchise   = try? c.decodeIfPresent(String.self, forKey: .franchise)
        location    = try? c.decodeIfPresent(String.self, forKey: .location)
        isActive    = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
    }

    // Manual init for previews / tests.
    init(id: Int, companyName: String, franchise: String? = nil, location: String? = nil, isActive: Bool = true) {
        self.id = id
        self.companyName = companyName
        self.franchise = franchise
        self.location = location
        self.isActive = isActive
    }
}
