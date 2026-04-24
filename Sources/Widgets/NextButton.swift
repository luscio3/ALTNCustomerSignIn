import SwiftUI

/// Large "Next" button for progressing through the flow.
struct NextButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 10) {
                Text(title).font(.title3.weight(.semibold))
                Image(systemName: "arrow.right").font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled
                          ? Color(red: 0.10, green: 0.31, blue: 0.58)
                          : Color.gray.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
