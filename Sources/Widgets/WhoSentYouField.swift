import SwiftUI

/// "Who sent you?" text field with live B2B-client autocomplete.
///
/// The customer can still type and submit anything; suggestions are a
/// convenience. When the typed text matches one of our client accounts
/// (either by tapping a suggestion or by an exact name match), `matchedClientId`
/// is set so the resulting appointment can be auto-linked to that account.
struct WhoSentYouField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @Binding var matchedClientId: Int?
    /// Kiosk franchise, used to scope suggestions when available.
    var franchise: String? = nil

    @State private var suggestions: [ReferralClient] = []
    @State private var isSearching = false
    @State private var showSuggestions = false
    @State private var searchTask: Task<Void, Never>?

    private let service = ReferralClientService()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.callout.weight(.medium)).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.words)
                    .onChange(of: text) { newValue in onEdit(newValue) }
                if isSearching {
                    ProgressView().controlSize(.regular)
                } else if matchedClientId != nil {
                    // Visual confirmation that we recognized the account.
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.10, green: 0.45, blue: 0.20))
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            if showSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { client in
                        Button { select(client) } label: {
                            HStack {
                                Text(client.companyName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if client.id != suggestions.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Behavior

    private func onEdit(_ newValue: String) {
        // Any edit invalidates a previously matched account until we re-confirm.
        matchedClientId = nil
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            showSuggestions = false
            isSearching = false
            return
        }

        isSearching = true
        showSuggestions = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if Task.isCancelled { return }

            let results = (try? await service.search(trimmed, franchise: franchise)) ?? []
            if Task.isCancelled { return }

            await MainActor.run {
                suggestions = results
                isSearching = false
                // Auto-confirm when the typed text already equals a single account.
                let exact = results.filter {
                    $0.companyName.trimmingCharacters(in: .whitespaces)
                        .caseInsensitiveCompare(trimmed) == .orderedSame
                }
                if exact.count == 1 {
                    matchedClientId = exact.first?.id
                }
            }
        }
    }

    private func select(_ client: ReferralClient) {
        searchTask?.cancel()
        text = client.companyName
        matchedClientId = client.id
        suggestions = []
        showSuggestions = false
        isSearching = false
    }
}
