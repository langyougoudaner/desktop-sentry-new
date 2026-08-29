import SwiftUI
import AppKit

/// Subtle top-lit border that adapts to light/dark. The actual frosted glass
/// comes from the NSVisualEffectView in PanelFactory — views stay transparent
/// and only add this border for definition.
struct GlassBorder: ViewModifier {
    var cornerRadius: CGFloat = 13
    @Environment(\.colorScheme) private var cs

    func body(content: Content) -> some View {
        content
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.primary.opacity(cs == .dark ? 0.22 : 0.12),
                        lineWidth: 0.75
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(cs == .dark ? 0.26 : 0.62),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassBorder(cornerRadius: CGFloat = 13) -> some View {
        modifier(GlassBorder(cornerRadius: cornerRadius))
    }

    /// The native NSVisualEffectView in PanelFactory owns the material. SwiftUI
    /// adds only a border, avoiding a second glass compositor layer.
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self.glassBorder(cornerRadius: cornerRadius)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
