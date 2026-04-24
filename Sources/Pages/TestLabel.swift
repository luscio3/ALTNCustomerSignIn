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

/// Placeholder shown when the services catalog hasn't loaded yet (e.g. first launch while offline).
struct EmptyCatalogNotice: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Service catalog unavailable")
                .font(.title3.weight(.semibold))
            Text("Connect this iPad to the Internet at least once to load the service list. The sign-in app stays usable afterward — even offline.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
