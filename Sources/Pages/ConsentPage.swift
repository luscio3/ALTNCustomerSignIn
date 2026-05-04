import SwiftUI
import PencilKit

/// Shows each required consent on its own page. The customer reviews the PDF, signs, and taps Next.
///
/// Behavior per consent:
///   - **Required** (`customerInfo`, `vitamin`): must sign before advancing.
///   - **Optional** (`email`, `marketing`, `phone`): can sign OR tap "Skip" — skipping means they decline.
///
/// After the last consent, instead of advancing we submit:
///   1. Build the appointment JSON payload.
///   2. If online AND (existing customer OR `/client` create succeeds): upload signed PDFs + submit appointment.
///   3. If anything fails: enqueue the full submission so OfflineQueue.drain() retries later.
struct ConsentPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue

    @State private var currentIndex = 0
    @State private var signedPDFs:  [ConsentFormType: Data] = [:]
    @State private var canvas = PKCanvasView()
    @State private var hasSignature = false
    @State private var pdfURL: URL?
    @State private var isSubmitting = false
    @State private var error: String?

    // MARK: - Derived

    private var isNewCustomer: Bool { appState.draft.person == nil }
    private var requiredTypes: [ConsentFormType] {
        ConsentFormType.requiredFor(category: appState.draft.category, isNewCustomer: isNewCustomer)
    }
    private var currentType: ConsentFormType { requiredTypes[currentIndex] }
    private var isLast: Bool { currentIndex == requiredTypes.count - 1 }

    private var canAdvance: Bool {
        if isSubmitting { return false }
        // Required forms: must have a signature.
        // Optional forms: Next always enabled (either signed or skipped).
        return currentType.isOptional || hasSignature
    }

    private var advanceTitle: String {
        if isSubmitting { return "Submitting…" }
        if isLast       { return "Save & Send" }
        // Optional form with no signature: treat Next as "Skip this consent".
        if currentType.isOptional && !hasSignature { return "Skip" }
        return "Next"
    }

    var body: some View {
        PageContainer(
            title: "\(currentType.displayName) — \(currentIndex + 1) of \(requiredTypes.count)",
            canAdvance: canAdvance,
            advanceTitle: advanceTitle,
            onAdvance: advance
        ) {
            VStack(alignment: .leading, spacing: 20) {
                progressStrip
                header
                pdfSection
                signatureSection
                ErrorBanner(text: error)
                if currentType.isOptional {
                    optionalHint
                }
            }
        }
        // Reset page-local state whenever the current consent changes.
        // Clear the drawing in-place — do NOT replace the PKCanvasView instance,
        // because the UIViewRepresentable is still showing the original one.
        .task(id: currentIndex) {
            canvas.drawing = PKDrawing()
            hasSignature = false
            pdfURL = await ConsentPDFCache.shared.pdfURL(currentType)
        }
    }

    // MARK: - Subviews

    private var progressStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let total = max(1, requiredTypes.count)
                let w = geo.size.width * CGFloat(currentIndex + 1) / CGFloat(total)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(Color(red: 0.10, green: 0.31, blue: 0.58))
                        .frame(width: max(0, w))
                        .animation(.easeInOut(duration: 0.25), value: currentIndex)
                }
            }
            .frame(height: 8)
        }
    }

    private var header: some View {
        HStack {
            Label(currentType.displayName, systemImage: systemImageFor(currentType))
                .font(.title3.weight(.semibold))
            Spacer()
            if currentType.isOptional {
                badge("Optional", color: .gray)
            } else {
                badge("Required", color: .red)
            }
        }
    }

    private var pdfSection: some View {
        Group {
            if let pdfURL {
                PDFViewer(url: pdfURL)
                    .frame(minHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
            } else {
                ProgressView("Loading…").frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Sign here to agree")
            SignaturePad(canvas: $canvas, onChange: {
                hasSignature = !canvas.drawing.strokes.isEmpty
            })
            .frame(height: 220)
            HStack {
                Button("Clear") {
                    canvas.drawing = PKDrawing()
                    hasSignature = false
                }
                .buttonStyle(.bordered)
                .disabled(!hasSignature)
                Spacer()
                if !connectivity.isOnline {
                    Label("Offline — will sync automatically", systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var optionalHint: some View {
        Text("This consent is optional. Sign to accept, or tap \"Skip\" to decline.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: - Advance / skip / submit

    private func advance() {
        error = nil
        // If the current page has a signature, capture + stamp the PDF now.
        if hasSignature {
            do {
                try captureCurrentSignature()
            } catch let e {
                error = e.localizedDescription
                return
            }
        } else if !currentType.isOptional {
            // Defensive — canAdvance guards this, but double-check.
            error = "Please sign before continuing."
            return
        }

        if isLast {
            submit()
        } else {
            currentIndex += 1
        }
    }

    private func captureCurrentSignature() throws {
        guard let pngData = SignaturePad.exportPNG(from: canvas) else {
            throw NSError(domain: "ConsentPage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read signature."])
        }
        // Load the template off the cache (still sync on the main actor — it's small).
        let typeSnapshot = currentType
        let urlSnapshot = pdfURL
        guard let url = urlSnapshot, let templateData = try? Data(contentsOf: url) else {
            throw NSError(domain: "ConsentPage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Consent PDF not available. Reconnect briefly to download it."])
        }
        let signedPDF = try PDFSigner.embedSignature(templateData: templateData, signaturePNG: pngData)
        signedPDFs[typeSnapshot] = signedPDF
    }

    private func submit() {
        isSubmitting = true
        error = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await performSubmit()
                appState.path = [.finish]
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func performSubmit() async throws {
        // 1. Build the list of signed consents to upload. Order is stable (requiredTypes order).
        var signed: [(type: ConsentFormType, formId: Int, pdf: Data)] = []
        for type in requiredTypes {
            guard let pdf = signedPDFs[type] else { continue } // skipped by the customer
            guard let entry = await ConsentPDFCache.shared.entry(type) else { continue }
            signed.append((type, entry.id, pdf))
        }

        // 2. Agreement booleans — signing = agreeing.
        let emailOK = signedPDFs[.email]     != nil
        let smsOK   = signedPDFs[.phone]     != nil
        let mktOK   = signedPDFs[.marketing] != nil

        // 3. Build the appointment JSON body + optional new-customer body.
        let (appointmentBody, newCustomerBody) = try AppointmentPayloadBuilder.build(
            draft: appState.draft,
            franchise: appState.franchise!,
            location: appState.location!,
            emailAgreement: emailOK,
            smsAgreement: smsOK,
            marketingAgreement: mktOK
        )

        // 4. Try online. On any failure, queue for later retry.
        do {
            try await submitOnline(
                appointmentBody: appointmentBody,
                newCustomerBody: newCustomerBody,
                signed: signed,
                emailOK: emailOK, smsOK: smsOK, mktOK: mktOK
            )
        } catch {
            let queueItems = signed.map { s in
                (type: s.type,
                 pdf: s.pdf,
                 consentFormId: s.formId,
                 emailAgreement:     s.type == .email     ? emailOK : false,
                 smsAgreement:       s.type == .phone     ? smsOK   : false,
                 marketingAgreement: s.type == .marketing ? mktOK   : false,
                 customerId: appState.draft.person?.clientId)
            }
            try offlineQueue.enqueue(
                appointmentBody: appointmentBody,
                newCustomerBody: newCustomerBody,
                signedConsents: queueItems,
                commPrefs: CommPrefs(email: emailOK, sms: smsOK)
            )
        }
    }

    private func submitOnline(
        appointmentBody: Data,
        newCustomerBody: Data?,
        signed: [(type: ConsentFormType, formId: Int, pdf: Data)],
        emailOK: Bool, smsOK: Bool, mktOK: Bool
    ) async throws {
        var customerId: Int
        var finalAppointmentBody = appointmentBody
        if let person = appState.draft.person {
            customerId = person.clientId
        } else {
            guard let body = newCustomerBody else {
                throw NSError(domain: "ConsentPage", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing customer details."])
            }
            let person = try await FastAPIService().createPerson(jsonBody: body)
            customerId = person.clientId
            if var obj = try JSONSerialization.jsonObject(with: appointmentBody) as? [String: Any] {
                obj["client_id"] = customerId
                finalAppointmentBody = try JSONSerialization.data(withJSONObject: obj)
            }
        }

        let api = ConsentFormsAPI()
        for s in signed {
            _ = try await api.uploadSigned(
                consentFormId: s.formId,
                customerId: customerId,
                pdfData: s.pdf,
                fileName: "\(s.type.rawValue).pdf",
                emailAgreement:     s.type == .email     ? emailOK : false,
                smsAgreement:       s.type == .phone     ? smsOK   : false,
                marketingAgreement: s.type == .marketing ? mktOK   : false
            )
        }

        // Record the customer's email/SMS opt-in decision so the marketing
        // dispatcher honors it on future campaigns.
        try await api.updateCommunicationPrefs(customerId: customerId, email: emailOK, sms: smsOK)

        try await FastAPIService().submitAppointment(jsonBody: finalAppointmentBody)
    }

    // MARK: - Helpers

    private func systemImageFor(_ t: ConsentFormType) -> String {
        switch t {
        case .customerInfo: return "person.text.rectangle"
        case .email:        return "envelope"
        case .marketing:    return "megaphone"
        case .phone:        return "phone"
        case .vitamin:      return "syringe"
        }
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}
