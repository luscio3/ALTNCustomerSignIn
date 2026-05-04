import SwiftUI

/// Vitamin/injection picker (radio, single select).
struct ChooseInjectionPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization
    @State private var selection: ServiceInfo?

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .vitaminInjection) ?? []
    }

    var body: some View {
        PageContainer(
            title: loc.t(.chooseInjection),
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
        .onAppear { selection = appState.draft.injection }
    }

    private func advance() {
        guard let selection else { return }
        appState.draft.injection = selection
        appState.push(.personInfo)
    }
}
