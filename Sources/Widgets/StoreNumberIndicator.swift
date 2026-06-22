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
    @ObservedObject private var kiosk = KioskMode.shared

    @Environment(\.dismiss) private var dismiss

    /// Staff entered the correct PIN this session → kiosk controls revealed.
    @State private var kioskUnlocked = false
    @State private var showPINPrompt = false
    @State private var showChangePIN = false
    @State private var pinError = false

    private var kioskStatus: String {
        guard kiosk.isEnabled else { return "Off" }
        return kiosk.isLocked ? "Locked" : "Unlocked"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Status")) {
                    row("Network", connectivity.isOnline ? "Online" : "Offline")
                    row("Pending submissions", "\(offlineQueue.pendingCount)")
                    row("Store number", appState.storeNumber.isEmpty ? "—" : appState.storeNumber)
                    row("Kiosk lock", kioskStatus)
                    if let f = appState.franchise { row("Franchise", f.id) }
                    if let l = appState.location  { row("Location",  l.id) }
                }
                Section {
                    Button("Retry queued submissions now") {
                        Task { await offlineQueue.drain() }
                    }
                    .disabled(!connectivity.isOnline || offlineQueue.pendingCount == 0)
                }

                kioskSection

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
            .alert("Incorrect PIN", isPresented: $pinError) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showPINPrompt) {
                PINPrompt(title: "Enter staff PIN", confirm: false) { entered in
                    if kiosk.verify(pin: entered) {
                        kioskUnlocked = true
                    } else {
                        pinError = true
                    }
                }
            }
            .sheet(isPresented: $showChangePIN) {
                PINPrompt(title: "Set new staff PIN", confirm: true) { newPIN in
                    kiosk.setPIN(newPIN)
                }
            }
        }
    }

    @ViewBuilder
    private var kioskSection: some View {
        Section(
            header: Text("Kiosk Lock"),
            footer: Text("Locks the iPad to this app (Autonomous Single App Mode). Requires the iPad to be supervised with the ALTN kiosk profile installed.")
        ) {
            if kioskUnlocked {
                Toggle("Lock iPad to this app", isOn: $kiosk.isEnabled)

                if kiosk.isEnabled {
                    Button {
                        kiosk.staffExit()
                        dismiss()   // staff can now press Home and leave
                    } label: {
                        Label("Exit lock & leave app", systemImage: "lock.open")
                    }
                }

                Button("Change staff PIN…") { showChangePIN = true }
            } else {
                Button {
                    showPINPrompt = true
                } label: {
                    Label("Manage kiosk lock…", systemImage: "lock")
                }
            }
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

/// Minimal numeric-PIN entry sheet (iOS 15 compatible — no alert text fields).
private struct PINPrompt: View {
    let title: String
    /// When true, requires the PIN to be entered twice and to match.
    let confirm: Bool
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var pin2 = ""

    private var isValid: Bool {
        guard pin.count >= 4 else { return false }
        return confirm ? pin == pin2 : true
    }

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text(confirm ? "PIN must be at least 4 digits." : "")) {
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    if confirm {
                        SecureField("Confirm PIN", text: $pin2)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("OK") {
                    onSubmit(pin)
                    dismiss()
                }
                .disabled(!isValid)
            )
        }
    }
}
