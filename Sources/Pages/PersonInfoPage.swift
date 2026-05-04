import SwiftUI

/// Phone + DOB lookup. Online: hits /client to see if customer is known.
/// Offline: always treat as new customer so the signing flow can still continue.
struct PersonInfoPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var loc: Localization

    @State private var phone: String = ""
    @State private var dob: Date = defaultDob()
    @State private var isSubmitting = false
    @State private var error: String?

    private var phoneDigits: String {
        phone.filter(\.isNumber)
    }
    private var canAdvance: Bool {
        !isSubmitting && phoneDigits.count == 10
    }

    var body: some View {
        PageContainer(
            title: loc.t(.tellUsAboutYourself),
            canAdvance: canAdvance,
            advanceTitle: isSubmitting ? loc.t(.checking) : loc.t(.next),
            onAdvance: lookup
        ) {
            VStack(alignment: .leading, spacing: 20) {
                FormField(
                    label: loc.t(.phoneNumber),
                    placeholder: "(555) 123-4567",
                    text: $phone,
                    keyboard: .phonePad,
                    autocapitalize: false
                )
                .onChange(of: phone) { phone = FieldFormatters.phone($0) }

                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.t(.dateOfBirth)).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                    DatePicker("", selection: $dob, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .environment(\.locale, loc.language == .spanish
                                     ? Locale(identifier: "es_MX")
                                     : Locale(identifier: "en_US"))
                }

                ErrorBanner(text: error)
                if !connectivity.isOnline {
                    OfflineNotice()
                }
            }
        }
        .onAppear {
            phone = appState.draft.phone.isEmpty ? "" : appState.draft.phone
            if let d = appState.draft.dateOfBirth { dob = d }
        }
    }

    private func lookup() {
        guard let franchise = appState.franchise else { return }
        isSubmitting = true
        error = nil

        appState.draft.phone = phoneDigits
        appState.draft.dateOfBirth = dob

        Task {
            defer { isSubmitting = false }

            guard connectivity.isOnline else {
                // Offline: skip server check, treat as new customer.
                appState.draft.person = nil
                appState.push(.fullPersonInfo)
                return
            }

            do {
                let info = PersonInfo(phone: phoneDigits, dob: dob, franchise: franchise)
                let person = try await FastAPIService().fetchPerson(info)
                appState.draft.person = person
                if person == nil {
                    appState.push(.fullPersonInfo)
                } else {
                    appState.push(.consent)
                }
            } catch {
                // Network error — degrade gracefully: let the customer continue as new.
                appState.draft.person = nil
                appState.push(.fullPersonInfo)
            }
        }
    }

    private static func defaultDob() -> Date {
        let cal = Calendar(identifier: .gregorian)
        return cal.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }
}

private struct OfflineNotice: View {
    @EnvironmentObject var loc: Localization
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash").foregroundStyle(.white)
            Text(loc.t(.offlineNoticeShort))
                .font(.footnote)
                .foregroundStyle(.white)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.9)))
    }
}
