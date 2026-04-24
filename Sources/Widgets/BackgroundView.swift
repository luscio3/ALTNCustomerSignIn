import SwiftUI

/// App-wide background. Modernized look vs the old Flutter app — soft linear gradient
/// in the ALTN blue family, with a subtle top-edge shine.
struct BackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.18, blue: 0.40),
                Color(red: 0.10, green: 0.31, blue: 0.58),
                Color(red: 0.22, green: 0.49, blue: 0.78),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.15), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 160)
            .ignoresSafeArea()
        }
    }
}
