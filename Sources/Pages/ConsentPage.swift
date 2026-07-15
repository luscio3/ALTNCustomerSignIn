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
    @EnvironmentObject var loc: Localization

    @State private var currentIndex = 0
    @State private var signedPDFs:  [ConsentFormType: Data] = [:]
    /// Raw signature PNGs, kept alongside the stamped PDFs so the server can
    /// composite the fields onto the template (server-side overlay).
    @State private var signaturePNGs: [ConsentFormType: Data] = [:]
    @State private var canvas = PKCanvasView()
    @State private var hasSignature = false
    @State private var pdfURL: URL?
    @State private var isSubmitting = false
    @State private var isAdvancing = false   // covers the off-main embed window so a double-tap can't double-stamp / double-advance
    @State private var submitPhase: String?
    @State private var error: String?

    // MARK: - Derived

    private var isNewCustomer: Bool { appState.draft.person == nil }
    private var requiredTypes: [ConsentFormType] {
        ConsentFormType.requiredFor(category: appState.draft.category, isNewCustomer: isNewCustomer)
    }
    private var currentType: ConsentFormType { requiredTypes[currentIndex] }
    private var isLast: Bool { currentIndex == requiredTypes.count - 1 }

    private var canAdvance: Bool {
        if isSubmitting || isAdvancing { return false }
        // Required forms: must have a signature.
        // Optional forms: Next always enabled (either signed or skipped).
        return currentType.isOptional || hasSignature
    }

    private var advanceTitle: String {
        if isSubmitting { return submitPhase ?? loc.t(.submitting) }
        if isLast       { return loc.t(.saveAndSend) }
        // Optional form with no signature: treat Next as "Skip this consent".
        if currentType.isOptional && !hasSignature { return loc.t(.skip) }
        return loc.t(.next)
    }

    var body: some View {
        PageContainer(
            title: "\(currentType.displayName) — \(currentIndex + 1) \(loc.t(.ofCounter)) \(requiredTypes.count)",
            canAdvance: canAdvance,
            advanceTitle: advanceTitle,
            onAdvance: advance,
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    progressStrip
                    header
                    pdfSection
                }
            },
            fixedContent: {
                // SignaturePad lives OUTSIDE the outer ScrollView so the scroll's
                // pan gesture can't steal finger touches from PencilKit.
                VStack(alignment: .leading, spacing: 10) {
                    signatureSection
                    ErrorBanner(text: error)
                    if currentType.isOptional {
                        optionalHint
                    }
                }
            }
        )
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
                badge(loc.t(.optional), color: .gray)
            } else {
                badge(loc.t(.required), color: .red)
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
                ProgressView(loc.t(.loading)).frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: loc.t(.signHereToAgree))
            SignaturePad(canvas: $canvas, onChange: {
                hasSignature = !canvas.drawing.strokes.isEmpty
            })
            .frame(height: 220)
            HStack {
                Button(loc.t(.clear)) {
                    canvas.drawing = PKDrawing()
                    hasSignature = false
                }
                .buttonStyle(.bordered)
                .disabled(!hasSignature)
                Spacer()
                if !connectivity.isOnline {
                    Label(loc.t(.offlineWillSync), systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var optionalHint: some View {
        Text(loc.t(.optionalConsentHint))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: - Advance / skip / submit

    private func advance() {
        // Reentry guard: a fast double-tap previously sneaked a second tap
        // through SwiftUI's render cycle before the button disabled itself.
        // The new off-main embed widens that window, so guard explicitly.
        if isSubmitting || isAdvancing { return }
        error = nil
        isAdvancing = true

        // Validate up front; for the final consent flip `isSubmitting` BEFORE
        // any heavy work so the button label changes immediately. Previously
        // captureCurrentSignature() ran synchronously on the main thread for
        // ~0.5–2s (PDFKit PDF flatten + signature draw) before the submit task
        // was even created — that hitch read on screen as a freeze right after
        // the customer tapped "Save & Send".
        let pngSnapshot: Data?
        if hasSignature {
            guard let png = SignaturePad.exportPNG(from: canvas) else {
                error = loc.t(.couldNotReadSignature)
                isAdvancing = false
                return
            }
            pngSnapshot = png
        } else if currentType.isOptional {
            pngSnapshot = nil
        } else {
            // Defensive — canAdvance guards this, but double-check.
            error = loc.t(.pleaseSignBeforeContinuing)
            isAdvancing = false
            return
        }

        let typeSnapshot = currentType
        let urlSnapshot = pdfURL
        let wasLast = isLast

        if wasLast {
            isSubmitting = true
            submitPhase = loc.t(.submitting)
        }

        Task {
            defer { isAdvancing = false }

            // Stamp the signature on the PDF off the main thread (CPU-heavy
            // PDFKit work). PencilKit's PNG export must run on main, hence
            // the split.
            if let png = pngSnapshot {
                do {
                    let signed = try await Self.embedOffMain(png: png, templateURL: urlSnapshot)
                    signedPDFs[typeSnapshot] = signed
                    signaturePNGs[typeSnapshot] = png
                } catch {
                    self.error = error.localizedDescription
                    isSubmitting = false
                    submitPhase = nil
                    return
                }
            }

            if wasLast {
                await runSubmit()
            } else {
                currentIndex += 1
            }
        }
    }

    /// Off-main signature stamping. Reads the template + runs PDFSigner on a
    /// detached task so the main thread stays responsive.
    private static func embedOffMain(png: Data, templateURL: URL?) async throws -> Data {
        guard let url = templateURL else {
            throw NSError(domain: "ConsentPage", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Consent PDF unavailable."])
        }
        return try await Task.detached(priority: .userInitiated) {
            let templateData = try Data(contentsOf: url)
            return try PDFSigner.embedSignature(templateData: templateData, signaturePNG: png)
        }.value
    }

    private func runSubmit() async {
        defer { isSubmitting = false; submitPhase = nil }
        do {
            try await performSubmit { phase in
                self.submitPhase = phase
            }
            appState.path = [.finish]
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func performSubmit(progress: @MainActor @escaping (String) -> Void) async throws {
        // 1. Build the list of signed consents to upload. Order is stable (requiredTypes order).
        var signed: [(type: ConsentFormType, formId: Int, pdf: Data, png: Data?)] = []
        for type in requiredTypes {
            guard let pdf = signedPDFs[type] else { continue } // skipped by the customer
            guard let entry = await ConsentPDFCache.shared.entry(type) else { continue }
            signed.append((type, entry.id, pdf, signaturePNGs[type]))
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
                emailOK: emailOK, smsOK: smsOK, mktOK: mktOK,
                progress: progress
            )
        } catch {
            let queueItems = signed.map { s in
                (type: s.type,
                 pdf: s.pdf,
                 consentFormId: s.formId,
                 emailAgreement:     s.type == .email     ? emailOK : false,
                 smsAgreement:       s.type == .phone     ? smsOK   : false,
                 marketingAgreement: s.type == .marketing ? mktOK   : false,
                 customerId: appState.draft.person?.clientId,
                 signaturePNG: s.png)
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
        signed: [(type: ConsentFormType, formId: Int, pdf: Data, png: Data?)],
        emailOK: Bool, smsOK: Bool, mktOK: Bool,
        progress: @MainActor (String) -> Void
    ) async throws {
        var customerId: Int
        var finalAppointmentBody = appointmentBody
        if let person = appState.draft.person {
            customerId = person.clientId
        } else {
            guard let body = newCustomerBody else {
                throw NSError(domain: "ConsentPage", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: loc.t(.missingCustomerDetails)])
            }
            await progress(loc.t(.submitPhaseCreatingAccount))
            let person = try await FastAPIService().createPerson(jsonBody: body)
            customerId = person.clientId
            if var obj = try JSONSerialization.jsonObject(with: appointmentBody) as? [String: Any] {
                obj["client_id"] = customerId
                finalAppointmentBody = try JSONSerialization.data(withJSONObject: obj)
            }
        }

        let api = ConsentFormsAPI()
        let total = signed.count
        for (idx, s) in signed.enumerated() {
            await progress(loc.tUploadingConsent(idx + 1, of: total))
            _ = try await api.uploadSigned(
                consentFormId: s.formId,
                customerId: customerId,
                pdfData: s.pdf,
                fileName: "\(s.type.rawValue).pdf",
                emailAgreement:     s.type == .email     ? emailOK : false,
                smsAgreement:       s.type == .phone     ? smsOK   : false,
                marketingAgreement: s.type == .marketing ? mktOK   : false,
                signaturePNG: s.png
            )
        }

        // Record the customer's email/SMS opt-in decision so the marketing
        // dispatcher honors it on future campaigns.
        await progress(loc.t(.submitPhaseSavingPrefs))
        try await api.updateCommunicationPrefs(customerId: customerId, email: emailOK, sms: smsOK)

        await progress(loc.t(.submitPhaseSavingAppointment))
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
