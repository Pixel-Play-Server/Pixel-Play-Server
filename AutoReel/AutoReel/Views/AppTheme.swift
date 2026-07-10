import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.45, green: 0.22, blue: 0.95)
    static let accentSecondary = Color(red: 0.95, green: 0.35, blue: 0.55)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.06, blue: 0.14),
            Color(red: 0.12, green: 0.08, blue: 0.18),
            Color(.systemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }

    func screenBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isEnabled {
                        AppTheme.heroGradient
                    } else {
                        Color.gray.opacity(0.4)
                    }
                }
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
