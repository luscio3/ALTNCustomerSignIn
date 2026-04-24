import SwiftUI

/// Two-step page: pick specimen categories (multi), then enter who-sent-you + chain-of-custody radio.
struct ChooseDrugsOrAlcoholPage: View {
    @EnvironmentObject var appState: AppState

    enum Step { case specimens, details }
    @State private var step: Step = .specimens

    @State private var specimens: Set<ServiceInfo> = []
    @State private var whoSent: String = ""
    @State private var radio: DrugsRadio?

    private var options: [ServiceInfo] {
        appState.services?.tests(in: .drugOrAlcohol) ?? []
    }

    private var canAdvanceStep1: Bool { !specimens.isEmpty }
    private var canAdvanceStep2: Bool { !whoSent.trimmingCharacters(in: .whitespaces).isEmpty && radio != nil }

    var body: some View {
        PageContainer(
            title: step == .specimens ? "Choose specimen type(s)" : "Tell us more",
            canAdvance: step == .specimens ? canAdvanceStep1 : canAdvanceStep2,
            advanceTitle: step == .specimens ? "Next" : "Continue",
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
                    FormField(
                        label: "Who sent you? (Employer / School / Court)",
                        placeholder: "Enter name",
                        text: $whoSent
                    )
                    SectionTitle(text: "Chain-of-custody paperwork")
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
            specimens = Set(existing.specimens)
            whoSent   = existing.whoSent
            radio     = existing.radio
        }
    }

    private func advance() {
        switch step {
        case .specimens:
            guard canAdvanceStep1 else { return }
            step = .details
        case .details:
            guard canAdvanceStep2, let radio else { return }
            appState.draft.drugsOrAlcohol = DrugsOrAlcoholData(
                radio: radio,
                specimens: Array(specimens),
                whoSent: whoSent.trimmingCharacters(in: .whitespaces)
            )
            appState.push(.personInfo)
        }
    }
}
