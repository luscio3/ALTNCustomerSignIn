import SwiftUI

// MARK: - Section title

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color(red: 0.10, green: 0.31, blue: 0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text field

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalize: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .keyboardType(keyboard)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(autocapitalize ? .words : .never)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

// MARK: - Radio list (single-select)

struct RadioList<T: Hashable, Label: View>: View {
    let options: [T]
    @Binding var selection: T?
    @ViewBuilder let label: (T) -> Label

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack(spacing: 14) {
                        Image(systemName: selection == option ? "largecircle.fill.circle" : "circle")
                            .font(.title2)
                            .foregroundStyle(selection == option
                                             ? Color(red: 0.10, green: 0.31, blue: 0.58)
                                             : .gray)
                        label(option)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Check list (multi-select)

struct CheckList<T: Hashable, Label: View>: View {
    let options: [T]
    @Binding var selection: Set<T>
    @ViewBuilder let label: (T) -> Label

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button(action: { toggle(option) }) {
                    HStack(spacing: 14) {
                        Image(systemName: selection.contains(option) ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(selection.contains(option)
                                             ? Color(red: 0.10, green: 0.31, blue: 0.58)
                                             : .gray)
                        label(option)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ o: T) {
        if selection.contains(o) { selection.remove(o) } else { selection.insert(o) }
    }
}

// MARK: - Big picture/tile button

struct TileButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color(red: 0.10, green: 0.31, blue: 0.58))
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 190)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error banner

struct ErrorBanner: View {
    let text: String?
    var body: some View {
        if let text, !text.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                Text(text).foregroundStyle(.white).font(.callout)
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.85)))
        }
    }
}
