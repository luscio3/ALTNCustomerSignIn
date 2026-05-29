import SwiftUI

/// Phone + DOB lookup. Online: hits /client to see if customer is known.
/// Offline: always treat as new customer so the signing flow can still continue.
struct PersonInfoPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var loc: Localization

    @State private var phone: String = ""
    /// `nil` until the customer actually picks a date — there is intentionally no
    /// pre-filled default, so a date can never be accepted by accident. (Customers
    /// were tapping Next on a pre-filled wheel and recording the wrong DOB.)
    @State private var dob: Date? = nil
    @State private var showPicker = false
    @State private var isSubmitting = false
    @State private var error: String?

    private var phoneDigits: String {
        phone.filter(\.isNumber)
    }
    private var canAdvance: Bool {
        !isSubmitting && phoneDigits.count == 10 && dob != nil
    }

    /// Non-optional binding for the wheel. Reading falls back to a sensible
    /// starting position (~30 yrs ago); writing is what marks the DOB as set.
    private var dobBinding: Binding<Date> {
        Binding(
            get: { dob ?? Self.defaultDob() },
            set: { dob = $0 }
        )
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

                    // Tap-to-set field: shows a placeholder until a date is chosen,
                    // then the formatted date. Tapping reveals the wheel below.
                    Button {
                        withAnimation { showPicker.toggle() }
                    } label: {
                        HStack {
                            Text(dob.map(displayDob) ?? loc.t(.tapToSelectDate))
                                .font(.title3.weight(dob == nil ? .regular : .semibold))
                                .foregroundStyle(dob == nil ? Color.secondary : Color.primary)
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(dob == nil ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    if showPicker {
                        DatePicker("", selection: dobBinding, in: ...Date(), displayedComponents: .date)
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                ErrorBanner(text: error)
                if !connectivity.isOnline {
                    OfflineNotice()
                }
            }
        }
        .onAppear {
            phone = appState.draft.phone.isEmpty ? "" : appState.draft.phone
            // Restore a previously-entered DOB (e.g. customer tapped Back), so a
            // returning customer isn't forced to re-enter it.
            if let d = appState.draft.dateOfBirth {
                dob = d
            }
        }
    }

    private func displayDob(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = loc.language == .spanish ? Locale(identifier: "es_MX") : Locale(identifier: "en_US")
        fmt.dateStyle = .long
        return fmt.string(from: date)
    }

    private func lookup() {
        guard let franchise = appState.franchise, let dob else { return }
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
