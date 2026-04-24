import SwiftUI

/// First-launch/admin screen. Staff picks the store from a hardcoded list of
/// JG Johnson Holdings LLC locations. Stores franchise (`0035`) + location code.
/// Replaces the earlier free-text input (`XXXX-XX`), which was error-prone.
struct SelectFranchisePage: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: Store?
    @State private var isSubmitting = false

    struct Store: Identifiable, Hashable {
        let id: String          // e.g. "0035-01"
        let name: String        // e.g. "Plano"
        let franchise: String   // "0035"
        let location: String    // "01"
    }

    /// Hardcoded list — the only stores this iPad build targets.
    private static let stores: [Store] = [
        .init(id: "0035-01", name: "Plano",      franchise: "0035", location: "01"),
        .init(id: "0035-03", name: "Frisco",     franchise: "0035", location: "03"),
        .init(id: "0035-04", name: "McKinney",   franchise: "0035", location: "04"),
        .init(id: "0035-05", name: "Richardson", franchise: "0035", location: "05"),
    ]

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                VStack(spacing: 10) {
                    Text("ANY LAB TEST NOW®")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Customer Sign-In")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(spacing: 16) {
                    SectionTitle(text: "Select your store")
                    VStack(spacing: 12) {
                        ForEach(Self.stores) { store in
                            StoreRow(
                                store: store,
                                isSelected: selection == store,
                                action: { selection = store }
                            )
                        }
                    }
                    NextButton(
                        title: isSubmitting ? "Loading…" : "Continue",
                        enabled: !isSubmitting && selection != nil,
                        action: submit
                    )
                }
                .padding(28)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white)
                )

                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }

    private func submit() {
        guard let store = selection else { return }
        isSubmitting = true
        let franchise = Franchise(id: store.franchise)
        let location = LocationRef(id: store.location)
        appState.saveFranchise(franchise, location: location, rawStoreNumber: store.id)
        Task {
            await Bootstrap.refreshBackingData(
                appState: appState,
                franchise: franchise,
                location: location
            )
            isSubmitting = false
        }
    }
}

private struct StoreRow: View {
    let store: SelectFranchisePage.Store
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(red: 0.10, green: 0.31, blue: 0.58) : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name).font(.title3.weight(.semibold))
                    Text(store.id).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(red: 0.10, green: 0.31, blue: 0.58).opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.10, green: 0.31, blue: 0.58) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
