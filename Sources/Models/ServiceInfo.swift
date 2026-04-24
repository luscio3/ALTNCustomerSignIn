import Foundation

/// A single offered service (injection, lab test, DNA test, drug/alcohol specimen, STD option/plan).
/// Matches the FastAPI `/api/v3/service` JSON row exactly.
struct ServiceInfo: Codable, Hashable, Identifiable {
    /// Stable server-side id for the service; used in appointment payloads.
    let apiValue: String

    let name: String
    let nameEs: String?
    let price: Double?
    let description: String?
    let descriptionEs: String?
    let category: CustomerCategory

    var id: String { apiValue }

    static let stdOrHivTestKey = "stdOrHiv"

    enum CodingKeys: String, CodingKey {
        case apiValue = "api_value"
        case name, price, description, category
        case nameEs        = "name_es"
        case descriptionEs = "description_es"
    }

    /// Permissive decoder: `api_value` falls back to `name`; category falls back to `.other`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawName = try c.decode(String.self, forKey: .name)
        self.name           = rawName
        self.apiValue       = (try c.decodeIfPresent(String.self, forKey: .apiValue)) ?? rawName
        self.nameEs         = try c.decodeIfPresent(String.self, forKey: .nameEs)
        self.price          = try c.decodeIfPresent(Double.self, forKey: .price)
        self.description    = try c.decodeIfPresent(String.self, forKey: .description)
        self.descriptionEs  = try c.decodeIfPresent(String.self, forKey: .descriptionEs)
        let rawCat          = try c.decode(String.self, forKey: .category)
        self.category       = CustomerCategory(rawValue: rawCat) ?? .other
    }

    /// Encoded back to the on-disk services cache in the same shape FastAPI returned.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(apiValue,      forKey: .apiValue)
        try c.encode(name,          forKey: .name)
        try c.encodeIfPresent(nameEs,        forKey: .nameEs)
        try c.encodeIfPresent(price,         forKey: .price)
        try c.encodeIfPresent(description,   forKey: .description)
        try c.encodeIfPresent(descriptionEs, forKey: .descriptionEs)
        try c.encode(category.rawValue,      forKey: .category)
    }

    /// Non-zero price → "$123.45", nil or 0 → nil.
    var displayPrice: String? {
        guard let p = price, p > 0 else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: p))
    }
}

/// All services for the current franchise+location, grouped by category.
struct Services: Codable, Hashable {
    let byCategory: [CustomerCategory: [ServiceInfo]]

    init(flat: [ServiceInfo]) {
        var grouped: [CustomerCategory: [ServiceInfo]] = [:]
        for s in flat { grouped[s.category, default: []].append(s) }
        self.byCategory = grouped
    }

    func tests(in category: CustomerCategory) -> [ServiceInfo] {
        byCategory[category] ?? []
    }

    /// The flat array form for persistence.
    var flat: [ServiceInfo] { byCategory.values.flatMap { $0 } }

    enum CodingKeys: String, CodingKey { case flat }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let flat = try c.decode([ServiceInfo].self, forKey: .flat)
        self.init(flat: flat)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(flat, forKey: .flat)
    }
}

// MARK: - STD selection (plans vs. options)

/// The STD/HIV page branches into either a preset plan (radio) or a list of individual options (multi-select).
enum StdSelection: Hashable {
    case plan(ServiceInfo)
    case options([ServiceInfo])
}

// MARK: - Drugs/Alcohol

struct DrugsOrAlcoholData: Hashable {
    let radio: DrugsRadio
    let specimens: [ServiceInfo]
    let whoSent: String
}
