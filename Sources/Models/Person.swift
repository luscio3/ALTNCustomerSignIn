import Foundation

/// A customer known to the backend. Populated after `/client` lookup
/// or `/client` create.
struct Person: Codable, Hashable {
    /// The server-assigned customer id. Goes into appointment payloads as `client_id`.
    let clientId: Int

    static let apiField = "client_id"
}

/// Phone + date-of-birth + franchise for existing-customer lookup.
/// Sent as GET query params to `/api/v3/client`.
struct PersonInfo: Hashable {
    let phone: String
    let dob: Date
    let franchise: Franchise

    /// Format dob as the server expects: `YYYY-M-D` (not zero-padded — matches Flutter).
    var apiQueryItems: [URLQueryItem] {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: dob)
        let dobStr = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        return [
            URLQueryItem(name: "phone_number",  value: phone),
            URLQueryItem(name: "date_of_birth", value: dobStr),
            URLQueryItem(name: "franchise",     value: franchise.id),
        ]
    }
}

/// New-customer identity: name + gender + email.
struct NameGender: Codable, Hashable {
    let firstName: String
    let middleName: String?
    let lastName: String
    let email: String
    let gender: Gender
}

/// New-customer postal address.
struct Address: Codable, Hashable {
    let address: String
    let zipCode: String

    enum CodingKeys: String, CodingKey {
        case address
        case zipCode = "zip_code"
    }
}
