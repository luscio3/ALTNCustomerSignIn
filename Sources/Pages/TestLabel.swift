import SwiftUI

/// Standardized two-line list row for a service: name + optional price + optional description.
struct TestLabel: View {
    let service: ServiceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(service.name)
                    .font(.title3.weight(.medium))
                Spacer()
                if let price = service.displayPrice {
                    Text(price)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.31, blue: 0.58))
                }
            }
            if let desc = service.description, !desc.isEmpty {
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

/// Placeholder shown when the services catalog hasn't loaded yet. The copy names
/// the actual failure: offline vs. rejected token (stale build) vs. server error —
/// a 401 shown as "connect to the Internet" sends staff chasing the Wi-Fi.
struct EmptyCatalogNotice: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loc: Localization
    @State private var retrying = false

    private var icon: String {
        switch appState.catalogFailure {
        case .unauthorized:        return "key.slash"
        case .serverError:         return "exclamationmark.icloud"
        case .offline, .none:      return "wifi.exclamationmark"
        }
    }
    private var title: LocKey {
        switch appState.catalogFailure {
        case .unauthorized:        return .catalogAuthFailure
        case .serverError:         return .catalogServerError
        case .offline, .none:      return .catalogUnavailable
        }
    }
    private var detail: LocKey {
        switch appState.catalogFailure {
        case .unauthorized:        return .catalogAuthFailureDetail
        case .serverError:         return .catalogServerErrorDetail
        case .offline, .none:      return .catalogUnavailableDetail
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(loc.t(title))
                .font(.title3.weight(.semibold))
            Text(loc.t(detail))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // A fresh build fixes .unauthorized, not a retry — hide the button there.
            if appState.catalogFailure != .unauthorized,
               let f = appState.franchise, let l = appState.location {
                Button {
                    retrying = true
                    Task {
                        await Bootstrap.refreshBackingData(appState: appState, franchise: f, location: l)
                        retrying = false
                    }
                } label: {
                    if retrying {
                        ProgressView()
                    } else {
                        Text(loc.t(.catalogRetry))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(retrying)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
