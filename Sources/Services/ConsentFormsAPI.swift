import Foundation

/// Consent-form data source — the ALTNAdmin PHP v2 backend, NOT the legacy FastAPI.
/// Admin staff uploads the five form PDFs via the macOS app; we fetch them and upload signed copies.
struct ConsentFormsAPI {

    /// All templates. Response is already ordered by the server.
    func fetchTemplates() async throws -> [ConsentForm] {
        try await Endpoints.consentAPI.get("/consent-forms")
    }

    /// Download a template PDF by absolute URL (the URL comes back in `ConsentForm.fileUrl`).
    func downloadTemplatePdf(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIClient.APIError.invalidURL
        }
        return try await Endpoints.consentAPI.download(url)
    }

    /// Upload a signed consent PDF and the three agreement flags.
    /// Returns the new signature record id.
    func uploadSigned(
        consentFormId: Int,
        customerId: Int,
        pdfData: Data,
        fileName: String,
        emailAgreement: Bool,
        smsAgreement: Bool,
        marketingAgreement: Bool,
        signaturePNG: Data? = nil
    ) async throws -> Int {
        struct Resp: Decodable { let id: Int }
        // The raw signature PNG lets the server flatten name/phone/signature/date
        // onto the template at the correct positions (server-side compositing).
        // The `file` PDF is still sent for back-compat / forms without a layout.
        let data = try await Endpoints.consentAPI.uploadMultipart(
            "/consent-forms/signatures",
            fileData: pdfData,
            fileName: fileName,
            extraFileField: signaturePNG != nil ? "signature_png" : nil,
            extraFileData: signaturePNG,
            extraFileName: "signature.png",
            extraFileMime: "image/png",
            fields: [
                "consent_form_id":     String(consentFormId),
                "customer_id":         String(customerId),
                "email_agreement":     emailAgreement     ? "1" : "0",
                "sms_agreement":       smsAgreement       ? "1" : "0",
                "marketing_agreement": marketingAgreement ? "1" : "0",
            ],
            timeout: 30
        )
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return resp.id
    }

    /// Optional: the customer's signature history (across all template types).
    /// Uses the endpoint we just added to consent_forms.php.
    func fetchSignatures(customerId: Int) async throws -> [ConsentFormSignature] {
        try await Endpoints.consentAPI.get("/customer-consent-forms/\(customerId)")
    }

    /// Record the customer's latest email/SMS opt-in decision. Called on every sign-in
    /// so ALTNAdmin's marketing dispatcher (which reads `marketing_optouts`) respects
    /// the customer's most recent answer.
    ///
    /// - `email: true` = they signed the email consent — remove any prior opt-out.
    /// - `email: false` = they skipped — record an opt-out row.
    /// - Same for `sms`.
    func updateCommunicationPrefs(customerId: Int, email: Bool, sms: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "sms":   sms,
        ])
        try await Endpoints.consentAPI.post("/customer-communication-prefs/\(customerId)", jsonBody: body, timeout: 30)
    }
}
