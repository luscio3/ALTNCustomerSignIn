import Foundation

/// Five consent form types — matches ALTNAdmin exactly.
enum ConsentFormType: String, Codable, CaseIterable, Identifiable, Hashable {
    case customerInfo = "customerInfo"
    case email        = "email"
    case marketing    = "marketing"
    case phone        = "phone"
    case vitamin      = "vitamin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .customerInfo: return Localization.t(.consentCustomerInfo)
        case .email:        return Localization.t(.consentEmail)
        case .marketing:    return Localization.t(.consentMarketing)
        case .phone:        return Localization.t(.consentPhone)
        case .vitamin:      return Localization.t(.consentVitamin)
        }
    }

    /// Whether the customer may decline (optional) vs. must agree (required).
    var isOptional: Bool {
        switch self {
        case .customerInfo, .vitamin:      return false
        case .email, .marketing, .phone:   return true
        }
    }

    /// The required forms for a given sign-in.
    /// Every customer signs these on every visit — returning customers get the
    /// same set as first-timers so consents stay current.
    ///   Always: customerInfo + email + phone (+ vitamin if applicable)
    static func requiredFor(category: CustomerCategory?, isNewCustomer: Bool) -> [ConsentFormType] {
        var required: [ConsentFormType] = [.customerInfo, .email, .phone]
        if category == .vitaminInjection {
            required.append(.vitamin)
        }
        return required
    }
}

/// A consent template as served by ALTNAdmin PHP v2 (`GET /consent-forms`).
struct ConsentForm: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let fileUrl: String
    let pagesCount: Int
    let updatedAt: Date?
    let createdAt: Date?

    var formType: ConsentFormType? { ConsentFormType(rawValue: name) }

    enum CodingKeys: String, CodingKey {
        case id, name
        case fileUrl    = "file_url"
        case pagesCount = "pages_count"
        case updatedAt  = "updated_at"
        case createdAt  = "created_at"
    }
}

/// A previously-uploaded signature record (history lookup).
struct ConsentFormSignature: Identifiable, Codable, Hashable {
    let id: Int
    let consentFormId: Int
    let customerId: Int
    let signedFileUrl: String?
    let emailAgreement: Bool
    let smsAgreement: Bool
    let marketingAgreement: Bool
    let signedAt: Date?
    let consentFormName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case consentFormId      = "consent_form_id"
        case customerId         = "customer_id"
        case signedFileUrl      = "signed_file_url"
        case emailAgreement     = "email_agreement"
        case smsAgreement       = "sms_agreement"
        case marketingAgreement = "marketing_agreement"
        case signedAt           = "signed_at"
        case consentFormName    = "consent_form_name"
    }
}
