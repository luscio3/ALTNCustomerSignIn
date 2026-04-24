import SwiftUI

/// Success screen. After a short confirmation, the kiosk returns to Select Category.
struct FinishPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue

    var body: some View {
        PageContainer(
            title: "All set!",
            showsBack: false,
            canAdvance: true,
            advanceTitle: "Done",
            onAdvance: { appState.path = [.category] }
        ) {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color(red: 0.10, green: 0.31, blue: 0.58))
                Text("You're signed in — please have a seat.")
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
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.up")
            Text("Your sign-in is saved and will sync automatically when the network returns (\(pending) pending).")
                .font(.callout)
        }
        .padding(12)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.9)))
    }
}
