import SwiftUI

/// Home screen of the kiosk. Four tiles; tap one to start a sign-in.
struct SelectCategoryPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization

    private var vitaminLabel: String {
        // Honor a franchise-specific override when present; otherwise fall
        // back to the localized default ("Vitamin Injection" / "Inyección de
        // Vitaminas"). The override comes from /franchise/{id} so it's
        // typically already in the correct customer-facing name.
        if let custom = appState.franchiseInfo?.customCategoryName, !custom.isEmpty {
            return custom
        }
        return loc.t(.vitaminInjection)
    }

    var body: some View {
        PageContainer(
            title: loc.t(.howCanWeHelp),
            showsBack: false,
            canAdvance: false,
            onAdvance: nil
        ) {
            VStack(spacing: 18) {
                Text(loc.t(.tapService))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 18),
                                    GridItem(.flexible(), spacing: 18)], spacing: 18) {
                    TileButton(title: vitaminLabel, systemImage: "syringe.fill") {
                        start(.vitaminInjection, next: .chooseInjection)
                    }
                    TileButton(title: loc.t(.drugOrAlcoholScreen), systemImage: "drop.degreesign.fill") {
                        start(.drugOrAlcohol, next: .chooseDrugsOrAlcohol)
                    }
                    TileButton(title: loc.t(.dnaTest), systemImage: "allergens") {
                        start(.dna, next: .chooseDna)
                    }
                    TileButton(title: loc.t(.labTest), systemImage: "testtube.2") {
                        start(.labTest, next: .chooseLabTest)
                    }
                }
            }
        }
        // Whenever the kiosk returns to the home screen we're between
        // customers — flip the language back to English so the next person
        // always sees their default.
        .onAppear { loc.reset() }
    }

    private func start(_ category: CustomerCategory, next: Route) {
        appState.draft = SignInDraft(category: category)
        appState.path = [next]
    }
}
