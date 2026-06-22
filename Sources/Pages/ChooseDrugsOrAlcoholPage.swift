import SwiftUI

/// Two-step page: pick specimen categories (multi), then enter who-sent-you + chain-of-custody radio.
struct ChooseDrugsOrAlcoholPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization

    enum Step { case specimens, details }
    @State private var step: Step = .specimens

    @State private var specimens: Set<ServiceInfo> = []
    @State private var whoSent: String = ""
    @State private var whoSentClientId: Int? = nil
    @State private var radio: DrugsRadio?
    @State private var isResolving = false

    private let referralService = ReferralClientService()

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .drugOrAlcohol) ?? []
    }

    private var canAdvanceStep1: Bool { !specimens.isEmpty }
    private var canAdvanceStep2: Bool { !whoSent.trimmingCharacters(in: .whitespaces).isEmpty && radio != nil }

    var body: some View {
        PageContainer(
            title: step == .specimens ? loc.t(.chooseSpecimenTypes) : loc.t(.tellUsMore),
            canAdvance: step == .specimens ? canAdvanceStep1 : canAdvanceStep2,
            advanceTitle: step == .specimens ? loc.t(.next) : loc.t(.continueAction),
            onAdvance: advance
        ) {
            switch step {
            case .specimens:
                if options.isEmpty {
                    EmptyCatalogNotice()
                } else {
                    CheckList(options: options, selection: $specimens) { TestLabel(service: $0) }
                }
            case .details:
                VStack(alignment: .leading, spacing: 20) {
                    WhoSentYouField(
                        label: loc.t(.whoSentYou),
                        placeholder: loc.t(.enterName),
                        text: $whoSent,
                        matchedClientId: $whoSentClientId,
                        franchise: appState.franchise?.id
                    )
                    SectionTitle(text: loc.t(.chainOfCustody))
                    RadioList(
                        options: DrugsRadio.allCases,
                        selection: $radio
                    ) { r in Text(r.displayName).font(.title3) }
                }
            }
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        if let existing = appState.draft.drugsOrAlcohol {
            specimens       = Set(existing.specimens)
            whoSent         = existing.whoSent
            whoSentClientId = existing.whoSentClientId
            radio           = existing.radio
        }
    }

    private func advance() {
        switch step {
        case .specimens:
            guard canAdvanceStep1 else { return }
            step = .details
        case .details:
            guard canAdvanceStep2, let radio, !isResolving else { return }
            let typed = whoSent.trimmingCharacters(in: .whitespaces)

            // If the typed referrer wasn't already confirmed against an account,
            // try one last exact-name match so a fully-typed name still links.
            // Network failure / offline just falls back to free text.
            isResolving = true
            Task {
                var clientId = whoSentClientId
                if clientId == nil, !typed.isEmpty {
                    clientId = try? await referralService
                        .exactMatch(typed, franchise: appState.franchise?.id)?.id
                }
                await MainActor.run {
                    appState.draft.drugsOrAlcohol = DrugsOrAlcoholData(
                        radio: radio,
                        specimens: Array(specimens),
                        whoSent: typed,
                        whoSentClientId: clientId
                    )
                    isResolving = false
                    appState.push(.personInfo)
                }
            }
        }
    }
}
