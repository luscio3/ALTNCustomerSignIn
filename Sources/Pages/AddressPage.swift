import SwiftUI

/// New-customer address: street + ZIP.
struct AddressPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization

    @State private var street  = ""
    @State private var zip     = ""

    private var canAdvance: Bool {
        !street.trimmingCharacters(in: .whitespaces).isEmpty && zip.count == 5
    }

    var body: some View {
        PageContainer(
            title: loc.t(.yourAddress),
            canAdvance: canAdvance,
            advanceTitle: loc.t(.next),
            onAdvance: advance
        ) {
            VStack(alignment: .leading, spacing: 20) {
                FormField(label: loc.t(.streetAddress),
                          placeholder: "123 Main St",
                          text: $street)
                FormField(label: loc.t(.zipCode),
                          placeholder: "75024",
                          text: $zip,
                          keyboard: .numberPad,
                          autocapitalize: false)
                .onChange(of: zip) { zip = FieldFormatters.zip($0) }
            }
        }
        .onAppear {
            if let a = appState.draft.address {
                street = a.address
                zip    = a.zipCode
            }
        }
    }

    private func advance() {
        appState.draft.address = Address(
            address: street.trimmingCharacters(in: .whitespaces),
            zipCode: zip
        )
        appState.push(.consent)
    }
}
