import SwiftUI

/// DNA test picker (checklist, multi-select).
struct ChooseDnaPage: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: Set<ServiceInfo> = []

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .dna) ?? []
    }

    var body: some View {
        PageContainer(
            title: "Choose DNA test(s)",
            canAdvance: !selection.isEmpty,
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
