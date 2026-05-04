import SwiftUI

/// Success screen. After a short confirmation, the kiosk returns to Select Category.
struct FinishPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue
    @EnvironmentObject var loc: Localization

    var body: some View {
        PageContainer(
            title: loc.t(.allSet),
            showsBack: false,
            canAdvance: true,
            advanceTitle: loc.t(.done),
            onAdvance: { appState.path = [.category] }
        ) {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color(red: 0.10, green: 0.31, blue: 0.58))
                Text(loc.t(.signedInSeat))
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                if !connectivity.isOnline || offlineQueue.pendingCount > 0 {
                    OfflineSubmittedNotice(pending: offlineQueue.pendingCount)
                }
            }
            .padding(.vertical, 40)
        }
    }
}

private struct OfflineSubmittedNotice: View {
    let pending: Int
    @EnvironmentObject var loc: Localization
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.up")
            Text("\(loc.t(.offlineQueuedNotice)) (\(pending)).")
                .font(.callout)
        }
        .padding(12)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.9)))
    }
}
