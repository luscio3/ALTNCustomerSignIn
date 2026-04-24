import SwiftUI

/// Top-right chip: store number + online/offline status + pending-queue badge.
/// Tap to force-open the Select Franchise page (admin exit hatch).
struct StoreNumberIndicator: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue

    @State private var showAdminSheet = false

    var body: some View {
        Button(action: { showAdminSheet = true }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(connectivity.isOnline ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)
                Text(appState.storeNumber.isEmpty ? "—" : appState.storeNumber)
                    .font(.headline.monospaced())
                    .foregroundStyle(.white)
                if offlineQueue.pendingCount > 0 {
                    Text("\(offlineQueue.pendingCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAdminSheet) {
            AdminSheet()
                .environmentObject(appState)
                .environmentObject(connectivity)
                .environmentObject(offlineQueue)
        }
    }
}

private struct AdminSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Status")) {
                    row("Network", connectivity.isOnline ? "Online" : "Offline")
                    row("Pending submissions", "\(offlineQueue.pendingCount)")
                    row("Store number", appState.storeNumber.isEmpty ? "—" : appState.storeNumber)
                    if let f = appState.franchise { row("Franchise", f.id) }
                    if let l = appState.location  { row("Location",  l.id) }
                }
                Section {
                    Button("Retry queued submissions now") {
                        Task { await offlineQueue.drain() }
                    }
                    .disabled(!connectivity.isOnline || offlineQueue.pendingCount == 0)
                }
                Section {
                    Button(role: .destructive) {
                        UserSettings.franchise = nil
                        UserSettings.location = nil
                        UserSettings.storeNumber = nil
                        appState.franchise = nil
                        appState.location = nil
                        appState.storeNumber = ""
                        dismiss()
                    } label: {
                        Text("Change store number…")
                    }
                }
            }
            .navigationTitle("Admin")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
