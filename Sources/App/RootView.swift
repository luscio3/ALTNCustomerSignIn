import SwiftUI

/// Top-level navigation. If no franchise is configured yet, show the Select Franchise page.
/// Otherwise the kiosk starts on Select Category and cycles back there after each sign-in.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            BackgroundView()
            if appState.franchise == nil || appState.location == nil {
                SelectFranchisePage()
            } else {
                // Use NavigationStack on iOS 16+, fall back to NavigationView on iOS 15.
                if #available(iOS 16.0, *) {
                    NavigationStack(path: $appState.path) {
                        SelectCategoryPage()
                            .navigationDestination(for: Route.self, destination: destination)
                    }
                } else {
                    NavigationView {
                        SelectCategoryPage()
                    }
                    .navigationViewStyle(.stack)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .category:             SelectCategoryPage()
        case .chooseInjection:      ChooseInjectionPage()
        case .chooseDrugsOrAlcohol: ChooseDrugsOrAlcoholPage()
        case .chooseDna:            ChooseDnaPage()
        case .chooseLabTest:        ChooseLabTestPage()
        case .std:                  StdPage()
        case .personInfo:           PersonInfoPage()
        case .fullPersonInfo:       FullPersonInfoPage()
        case .address:              AddressPage()
        case .consent:              ConsentPage()
        case .finish:               FinishPage()
        }
    }
}
