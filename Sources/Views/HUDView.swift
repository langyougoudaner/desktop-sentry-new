import SwiftUI

/// Compact HUD banner shown at the top of the popover for transient feedback.
struct HUDView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(.blue.opacity(0.25), lineWidth: 0.5)
        )
    }
}
