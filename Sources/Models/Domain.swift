import Foundation

// MARK: - Franchise / Location

struct Franchise: Codable, Hashable {
    /// 4-digit franchise id (e.g. "0150").
    let id: String
}

struct LocationRef: Codable, Hashable {
    /// 2-digit store code within the franchise (e.g. "01" = Plano).
    let id: String
}

struct FranchiseInfo: Codable, Hashable {
    /// Locally customized name for the "Vitamin Injection" category (FastAPI /franchise/{id}).
    let customCategoryName: String?

    static let defaultCategoryName = "Vitamin Injection"
    var displayCategoryName: String { customCategoryName ?? Self.defaultCategoryName }

    enum CodingKeys: String, CodingKey {
        case customCategoryName = "custom_category_name"
    }
}

// MARK: - Category

enum CustomerCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case vitaminInjection  = "vitaminInjection"
    case drugOrAlcohol     = "drugOrAlcoholScreen"
    case dna               = "dna"
    case labTest           = "labTest"
    case stdOption         = "std_options"
    case stdPlans          = "std_plan"
    case other             = "other"

    var id: String { rawValue }

    var apiField: String { "category" }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable, Identifiable, Hashable {
    case male
    case female

    var id: String { rawValue }
    var apiValue: String { rawValue }
    static let apiField = "gender"

    var displayName: String {
        switch self {
        case .male:   return "Male"
        case .female: return "Female"
        }
    }
}

// MARK: - Drugs/Alcohol Radio

enum DrugsRadio: String, Codable, CaseIterable, Identifiable, Hashable {
    case havePaper     = "havePaper"
    case dontHavePaper = "dontHavePaper"
    case idk           = "idk"

    var id: String { rawValue }
    var apiValue: String { rawValue }
    static let apiField = "requisition"

    var displayName: String {
        switch self {
        case .havePaper:     return "I have a chain-of-custody form"
        case .dontHavePaper: return "I do not have a chain-of-custody form"
        case .idk:           return "I'm not sure"
        }
    }
}
