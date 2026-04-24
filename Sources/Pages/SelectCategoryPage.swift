import SwiftUI

/// Home screen of the kiosk. Four tiles; tap one to start a sign-in.
struct SelectCategoryPage: View {
    @EnvironmentObject var appState: AppState

    private var vitaminLabel: String {
        appState.franchiseInfo?.displayCategoryName ?? FranchiseInfo.defaultCategoryName
    }

    var body: some View {
        PageContainer(
            title: "How can we help today?",
            showsBack: false,
            canAdvance: false,
            onAdvance: nil
        ) {
            VStack(spacing: 18) {
                Text("Tap the service you're here for.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 18),
                                    GridItem(.flexible(), spacing: 18)], spacing: 18) {
                    TileButton(title: vitaminLabel, systemImage: "syringe.fill") {
                        start(.vitaminInjection, next: .chooseInjection)
                    }
                    TileButton(title: "Drug or Alcohol Screen", systemImage: "drop.degreesign.fill") {
                        start(.drugOrAlcohol, next: .chooseDrugsOrAlcohol)
                    }
                    TileButton(title: "DNA Test", systemImage: "allergens") {
                        start(.dna, next: .chooseDna)
                    }
                    TileButton(title: "Lab Test", systemImage: "testtube.2") {
                        start(.labTest, next: .chooseLabTest)
                    }
                }
            }
        }
    }

    private func start(_ category: CustomerCategory, next: Route) {
        appState.draft = SignInDraft(category: category)
        appState.path = [next]
    }
}
