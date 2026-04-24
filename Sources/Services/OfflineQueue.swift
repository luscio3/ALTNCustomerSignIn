import Foundation

/// Disk-backed queue of sign-ins that couldn't reach the server at submission time.
///
/// Layout mirrors the Flutter app's approach:
/// ```
/// <Application Support>/PendingRequests/<timestamp-ms>/
///     ├─ request.json    (appointment POST body; may lack client_id for new customers)
///     ├─ info.json       (new-customer POST body; removed once client_id is assigned)
///     └─ <formType>.pdf  (one signed consent per required form)
/// ```
///
/// Drained at launch and whenever ConnectivityMonitor sees a reconnect.
@MainActor
final class OfflineQueue: ObservableObject {

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastDrainError: String?

    private let fm = FileManager.default
    private let fastAPI = FastAPIService()
    private let consentAPI = ConsentFormsAPI()

    private var rootDir: URL {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("PendingRequests", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() { refreshCount() }

    // MARK: - Enqueue

    /// Save a failed submission to disk for later retry.
    /// If the customer is new (no Person yet), pass `newCustomerBody` so we can call
    /// `POST /client` on replay to get a `client_id`.
    func enqueue(
        appointmentBody: Data,
        newCustomerBody: Data?,
        signedConsents: [(type: ConsentFormType, pdf: Data, consentFormId: Int,
                          emailAgreement: Bool, smsAgreement: Bool, marketingAgreement: Bool,
                          customerId: Int?)],
        commPrefs: CommPrefs
    ) throws {
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let dir = rootDir.appendingPathComponent(stamp, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        try appointmentBody.write(to: dir.appendingPathComponent("request.json"), options: .atomic)
        if let body = newCustomerBody {
            try body.write(to: dir.appendingPathComponent("info.json"), options: .atomic)
        }
        // Persist the customer's opt-in decision so replay can hit /customer-communication-prefs.
        try JSONEncoder().encode(commPrefs).write(to: dir.appendingPathComponent("commprefs.json"), options: .atomic)

        // Write a small sidecar per consent so replay can upload them with the right metadata.
        for c in signedConsents {
            let pdfURL  = dir.appendingPathComponent("\(c.type.rawValue).pdf")
            let metaURL = dir.appendingPathComponent("\(c.type.rawValue).meta.json")
            try c.pdf.write(to: pdfURL, options: .atomic)
            let meta = PendingConsentMeta(
                consentFormId:       c.consentFormId,
                emailAgreement:      c.emailAgreement,
                smsAgreement:        c.smsAgreement,
                marketingAgreement:  c.marketingAgreement,
                customerId:          c.customerId
            )
            try JSONEncoder().encode(meta).write(to: metaURL, options: .atomic)
        }
        refreshCount()
    }

    // MARK: - Drain

    /// Walk every pending folder. For each one, upload consents + submit appointment.
    /// Successful folders are deleted; failures stay for the next drain.
    func drain() async {
        lastDrainError = nil
        guard let dirs = try? fm.contentsOfDirectory(at: rootDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        for d in dirs.filter({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) {
            do {
                if try await replay(folder: d) {
                    try? fm.removeItem(at: d)
                }
            } catch {
                lastDrainError = error.localizedDescription
            }
        }
        refreshCount()
    }

    private func replay(folder: URL) async throws -> Bool {
        let reqURL  = folder.appendingPathComponent("request.json")
        let infoURL = folder.appendingPathComponent("info.json")

        guard var reqObj = try? JSONSerialization.jsonObject(with: Data(contentsOf: reqURL)) as? [String: Any] else {
            return false
        }

        // Re-create customer if needed, then inject client_id.
        var clientId: Int? = reqObj["client_id"] as? Int
        if clientId == nil, fm.fileExists(atPath: infoURL.path) {
            let infoData = try Data(contentsOf: infoURL)
            do {
                let person = try await fastAPI.createPerson(jsonBody: infoData)
                clientId = person.clientId
                reqObj["client_id"] = person.clientId
                try JSONSerialization.data(withJSONObject: reqObj).write(to: reqURL, options: .atomic)
                try? fm.removeItem(at: infoURL)
            } catch {
                return false
            }
        }
        guard let cid = clientId else { return false }

        // Upload each signed consent to ALTNAdmin.
        let pdfFiles = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "pdf" } ?? []
        for pdfURL in pdfFiles {
            let metaURL = pdfURL.deletingPathExtension().appendingPathExtension("meta.json")
            guard let metaData = try? Data(contentsOf: metaURL),
                  let meta = try? JSONDecoder().decode(PendingConsentMeta.self, from: metaData),
                  let pdf = try? Data(contentsOf: pdfURL)
            else { continue }
            _ = try await consentAPI.uploadSigned(
                consentFormId:      meta.consentFormId,
                customerId:         cid,
                pdfData:            pdf,
                fileName:           pdfURL.lastPathComponent,
                emailAgreement:     meta.emailAgreement,
                smsAgreement:       meta.smsAgreement,
                marketingAgreement: meta.marketingAgreement
            )
        }

        // Record communication prefs (opt-outs) if we saved them at enqueue time.
        let prefsURL = folder.appendingPathComponent("commprefs.json")
        if let prefsData = try? Data(contentsOf: prefsURL),
           let prefs = try? JSONDecoder().decode(CommPrefs.self, from: prefsData) {
            try await consentAPI.updateCommunicationPrefs(customerId: cid, email: prefs.email, sms: prefs.sms)
        }

        // Finally, submit the appointment body to FastAPI.
        let finalBody = try JSONSerialization.data(withJSONObject: reqObj)
        try await fastAPI.submitAppointment(jsonBody: finalBody)
        return true
    }

    // MARK: - Counting

    private func refreshCount() {
        let dirs = (try? fm.contentsOfDirectory(at: rootDir, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true } ?? []
        pendingCount = dirs.count
    }
}

// MARK: - Persisted sidecar

private struct PendingConsentMeta: Codable {
    let consentFormId: Int
    let emailAgreement: Bool
    let smsAgreement: Bool
    let marketingAgreement: Bool
    let customerId: Int?
}

/// The customer's latest email/SMS agreement, persisted alongside each queued submission.
struct CommPrefs: Codable {
    let email: Bool
    let sms: Bool
}
