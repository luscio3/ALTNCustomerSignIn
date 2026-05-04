import SwiftUI

/// DNA test picker (checklist, multi-select).
struct ChooseDnaPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization
    @State private var selection: Set<ServiceInfo> = []

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .dna) ?? []
    }

    var body: some View {
        PageContainer(
            title: loc.t(.chooseDnaTests),
            canAdvance: !selection.isEmpty,
            advanceTitle: loc.t(.next),
            onAdvance: advance
        ) {
            if options.isEmpty {
                EmptyCatalogNotice()
            } else {
                CheckList(options: options, selection: $selection) { s in
                    TestLabel(service: s)
                }
            }
        }
        .onAppear { selection = Set(appState.draft.dnaSelections) }
    }

    private func advance() {
        appState.draft.dnaSelections = Array(selection)
        appState.push(.personInfo)
    }
}
