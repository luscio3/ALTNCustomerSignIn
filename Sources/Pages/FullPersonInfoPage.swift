import SwiftUI

/// New-customer details: first/middle/last name, email, gender.
struct FullPersonInfoPage: View {
    @EnvironmentObject var appState: AppState

    @State private var first  = ""
    @State private var middle = ""
    @State private var last   = ""
    @State private var email  = ""
    @State private var gender: Gender?

    private var canAdvance: Bool {
        !first.trimmingCharacters(in: .whitespaces).isEmpty &&
        !last.trimmingCharacters(in: .whitespaces).isEmpty  &&
        FieldFormatters.isValidEmail(email) &&
        gender != nil
    }

    var body: some View {
        PageContainer(
            title: "Welcome! A few details",
            canAdvance: canAdvance,
            onAdvance: advance
        ) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    FormField(label: "First name",  placeholder: "Jane",  text: $first)
                    FormField(label: "Middle (optional)", placeholder: "M.", text: $middle)
                }
                FormField(label: "Last name", placeholder: "Doe", text: $last)
                FormField(label: "Email",
                          placeholder: "you@example.com",
                          text: $email,
                          keyboard: .emailAddress,
                          autocapitalize: false)
                SectionTitle(text: "Gender")
                RadioList(options: Gender.allCases, selection: $gender) { g in
                    Text(g.displayName).font(.title3)
                }
            }
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        if let existing = appState.draft.nameGender {
            first  = existing.firstName
            middle = existing.middleName ?? ""
            last   = existing.lastName
            email  = existing.email
            gender = existing.gender
        }
    }

    private func advance() {
        guard let gender else { return }
        appState.draft.nameGender = NameGender(
            firstName:  first.trimmingCharacters(in: .whitespaces),
            middleName: middle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : middle.trimmingCharacters(in: .whitespaces),
            lastName:   last.trimmingCharacters(in: .whitespaces),
            email:      email.trimmingCharacters(in: .whitespaces),
            gender:     gender
        )
        appState.push(.address)
    }
}
