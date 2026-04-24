import Foundation

/// Builds the two JSON bodies that get sent when a customer completes the flow:
///
///   1. `appointmentBody` — POST to `/api/v3/client/appointment`.
///      Includes `client_id` if we already have one; otherwise the offline queue
///      will fill it in after the new-customer POST succeeds.
///   2. `newCustomerBody` — POST to `/api/v3/client`.
///      Only present for new customers.
enum AppointmentPayloadBuilder {

    /// Build both payloads from the in-progress draft.
    /// The three agreement booleans reflect the customer's consent choices
    /// (signing = agreeing, skipping = declining) and are required by
    /// `POST /api/v3/client` when creating a new customer.
    static func build(
        draft: SignInDraft,
        franchise: Franchise,
        location: LocationRef,
        emailAgreement: Bool,
        smsAgreement: Bool,
        marketingAgreement: Bool
    ) throws -> (appointment: Data, newCustomer: Data?) {
        guard let category = draft.category else {
            throw NSError(domain: "AppointmentPayload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing category."])
        }
        guard !draft.phone.isEmpty, let dob = draft.dateOfBirth else {
            throw NSError(domain: "AppointmentPayload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing phone or DOB."])
        }

        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: dob)
        let dobStr = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"

        // Base fields for every appointment.
        var appt: [String: Any] = [
            "franchise":      franchise.id,
            "location":       location.id,
            "category":       category.rawValue,
            "phone_number":   draft.phone,
            "date_of_birth":  dobStr,
            "created_at":     ISO8601DateFormatter().string(from: Date()),
        ]
        if let person = draft.person {
            appt["client_id"] = person.clientId
        }

        // Category-specific payload. The server requires `services: [String]`.
        var services: [String] = []
        switch category {
        case .vitaminInjection:
            if let inj = draft.injection {
                services = [inj.apiValue]
            }
        case .drugOrAlcohol:
            if let d = draft.drugsOrAlcohol {
                services = d.specimens.map(\.apiValue)
                appt["who_sent_you"] = d.whoSent
                appt[DrugsRadio.apiField] = d.radio.apiValue
            }
        case .dna:
            services = draft.dnaSelections.map(\.apiValue)
        case .labTest:
            if let lab = draft.labTest {
                services = [lab.apiValue]
            }
            if let std = draft.stdSelection {
                switch std {
                case .plan(let p):       appt["std_plan"]    = p.apiValue
                case .options(let opts): appt["std_options"] = opts.map(\.apiValue)
                }
            }
        case .stdOption, .stdPlans, .other:
            break
        }
        appt["services"] = services

        // New-customer payload, if applicable.
        var newCustomerBody: Data?
        if draft.person == nil, let ng = draft.nameGender, let addr = draft.address {
            var info: [String: Any] = [
                "franchise":            franchise.id,
                "location":             location.id,
                "phone_number":         draft.phone,
                "date_of_birth":        dobStr,
                "first_name":           ng.firstName,
                "last_name":            ng.lastName,
                "email":                ng.email,
                Gender.apiField:        ng.gender.apiValue,
                "address":              addr.address,
                "zip_code":             addr.zipCode,
                "email_agreement":      emailAgreement,
                "sms_agreement":        smsAgreement,
                "marketing_agreement":  marketingAgreement,
            ]
            if let middle = ng.middleName { info["middle_name"] = middle }
            newCustomerBody = try JSONSerialization.data(withJSONObject: info)

            // Mirror name/address onto the appointment too so downstream processing has everything.
            appt["first_name"]  = ng.firstName
            appt["last_name"]   = ng.lastName
            appt["email"]       = ng.email
            appt[Gender.apiField] = ng.gender.apiValue
            appt["address"]     = addr.address
            appt["zip_code"]    = addr.zipCode
            if let middle = ng.middleName { appt["middle_name"] = middle }
        }

        let appointmentBody = try JSONSerialization.data(withJSONObject: appt, options: [.sortedKeys])
        return (appointmentBody, newCustomerBody)
    }
}
