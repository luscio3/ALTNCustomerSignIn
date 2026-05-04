import SwiftUI

/// Lab test picker (radio). Special case: selecting "STD or HIV" branches to the STD page.
struct ChooseLabTestPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization
    @State private var selection: ServiceInfo?

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .labTest) ?? []
    }

    var body: some View {
        PageContainer(
            title: loc.t(.chooseLabTest),
            canAdvance: selection != nil,
            advanceTitle: loc.t(.next),
            onAdvance: advance
        ) {
            if options.isEmpty {
                EmptyCatalogNotice()
            } else {
                RadioList(options: options, selection: $selection) { s in
                    TestLabel(service: s)
                }
            }
        }
        .onAppear { selection = appState.draft.labTest }
    }

    private func advance() {
        guard let selection else { return }
        appState.draft.labTest = selection
        if selection.apiValue == ServiceInfo.stdOrHivTestKey {
            appState.push(.std)
        } else {
            appState.push(.personInfo)
        }
    }
}
