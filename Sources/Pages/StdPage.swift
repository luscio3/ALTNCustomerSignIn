import SwiftUI

/// STD/HIV page. Two mutually-exclusive views: choose a preset plan OR check individual options.
/// Matches the Flutter two-view toggle.
struct StdPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization

    enum Mode: String, CaseIterable, Identifiable {
        case plans   = "Plans"
        case options = "Individual Options"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .plans
    @State private var planSelection: ServiceInfo?
    @State private var optionSelection: Set<ServiceInfo> = []

    private var plans: [ServiceInfo] {
        appState.services?.tests(in: .stdPlans) ?? []
    }
    private var options: [ServiceInfo] {
        appState.services?.tests(in: .stdOption) ?? []
    }

    private var canAdvance: Bool {
        switch mode {
        case .plans:   return planSelection != nil
        case .options: return !optionSelection.isEmpty
        }
    }

    var body: some View {
        PageContainer(
            title: loc.t(.stdHivTesting),
            canAdvance: canAdvance,
            advanceTitle: loc.t(.next),
            onAdvance: advance
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m == .plans ? loc.t(.plans) : loc.t(.individualOptions)).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .plans:
                    if plans.isEmpty {
                        EmptyCatalogNotice()
                    } else {
                        RadioList(options: plans, selection: $planSelection) { TestLabel(service: $0) }
                    }
                case .options:
                    if options.isEmpty {
                        EmptyCatalogNotice()
                    } else {
                        CheckList(options: options, selection: $optionSelection) { TestLabel(service: $0) }
                    }
                }
            }
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        switch appState.draft.stdSelection {
        case .plan(let p)?:    mode = .plans;   planSelection = p
        case .options(let o)?: mode = .options; optionSelection = Set(o)
        case nil:              break
        }
    }

    private func advance() {
        switch mode {
        case .plans:
            guard let plan = planSelection else { return }
            appState.draft.stdSelection = .plan(plan)
        case .options:
            guard !optionSelection.isEmpty else { return }
            appState.draft.stdSelection = .options(Array(optionSelection))
        }
        appState.push(.personInfo)
    }
}
