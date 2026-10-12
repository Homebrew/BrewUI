import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceStatusView: View {
    let service: BrewService

    var body: some View {
        let tone = ServiceStatusTone(service)
        HStack(spacing: BrewSpacing.xs) {
            ServiceStatusGlyph(tone: tone)
            Text(verbatim: service.status)
                .foregroundStyle(tone == .failed ? Color.brewStatusError : .brewTextPrimary)
        }
        .font(.brewCaption)
    }
}

/// The text stays the primary colour: the glyph and fill carry the state.
struct ServiceStatusBadge: View {
    let service: BrewService

    var body: some View {
        let tone = ServiceStatusTone(service)
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
            ServiceStatusGlyph(tone: tone)
            Text(verbatim: service.status)
                .textCase(.uppercase)
                .foregroundStyle(Color.brewTextPrimary)
        }
        .font(.brewCaption2)
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background {
            Capsule()
                .fill(fill(for: tone))
        }
    }

    private func fill(for tone: ServiceStatusTone) -> Color {
        switch tone {
        case .running: .brewStatusSuccessSubtle
        case .failed: .brewStatusErrorSubtle
        case .inactive: .brewSurfaceElevated
        }
    }
}

private struct ServiceStatusGlyph: View {
    let tone: ServiceStatusTone

    var body: some View {
        switch tone {
        case .running:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brewStatusSuccess)
                .accessibilityHidden(true)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.brewStatusError)
                .accessibilityHidden(true)
        case .inactive:
            Image(systemName: "circle").foregroundStyle(Color.brewTextSecondary)
                .accessibilityHidden(true)
        }
    }
}
