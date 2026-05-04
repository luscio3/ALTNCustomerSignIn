import SwiftUI

/// Standard page chrome: translucent card with title, back button, store indicator,
/// scrollable body, optional non-scrolling `fixedContent`, and an optional Next button.
/// All sign-in pages render inside one of these.
///
/// `fixedContent` is for interactive elements that must not be inside the outer
/// ScrollView (e.g. `SignaturePad` — finger drags get stolen by the scroll gesture).
struct PageContainer<Content: View, FixedContent: View>: View {

    let title: String
    let showsBack: Bool
    let canAdvance: Bool
    let advanceTitle: String
    let onAdvance: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let fixedContent: () -> FixedContent

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue

    init(
        title: String,
        showsBack: Bool = true,
        canAdvance: Bool = false,
        advanceTitle: String = "Next",
        onAdvance: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fixedContent: @escaping () -> FixedContent
    ) {
        self.title = title
        self.showsBack = showsBack
        self.canAdvance = canAdvance
        self.advanceTitle = advanceTitle
        self.onAdvance = onAdvance
        self.content = content
        self.fixedContent = fixedContent
    }

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 0) {
                TopBar(title: title, showsBack: showsBack)
                card
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var card: some View {
        VStack(spacing: 16) {
            ScrollView {
                content()
                    .padding(.horizontal, 36)
                    .padding(.vertical,   24)
            }
            fixedContent()
                .padding(.horizontal, 36)
            if let onAdvance {
                NextButton(title: advanceTitle, enabled: canAdvance, action: onAdvance)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        )
        .padding(.horizontal, 40)
    }
}

// Convenience init for pages that don't need a fixed-content slot — keeps the
// existing call sites unchanged.
extension PageContainer where FixedContent == EmptyView {
    init(
        title: String,
        showsBack: Bool = true,
        canAdvance: Bool = false,
        advanceTitle: String = "Next",
        onAdvance: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            showsBack: showsBack,
            canAdvance: canAdvance,
            advanceTitle: advanceTitle,
            onAdvance: onAdvance,
            content: content,
            fixedContent: { EmptyView() }
        )
    }
}

// MARK: - Top bar

private struct TopBar: View {
    let title: String
    let showsBack: Bool

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var connectivity: ConnectivityMonitor
    @EnvironmentObject var offlineQueue: OfflineQueue
    @EnvironmentObject var loc: Localization

    var body: some View {
        HStack(alignment: .center) {
            if showsBack {
                Button(action: { appState.pop() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.title3.weight(.semibold))
                        Text(loc.t(.back)).font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            // Language toggle — left of the store indicator. The label always
            // names the OTHER language ("Español" when English is active),
            // so the customer sees what they'd switch to.
            Button(action: { loc.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "globe").font(.headline)
                    Text(loc.t(.languageToggleLabel)).font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Switch language"))

            StoreNumberIndicator()
                .environmentObject(appState)
                .environmentObject(connectivity)
                .environmentObject(offlineQueue)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}
