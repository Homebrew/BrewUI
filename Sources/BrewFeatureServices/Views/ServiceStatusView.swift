import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceStatusView: View {
    let service: BrewService

    var body: some View {
        HStack(spacing: BrewSpacing.xs) {
            Image(systemName: service.running ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(colour)
                .accessibilityHidden(true)
            Text(verbatim: service.status)
                .foregroundStyle(service.status == "error" ? Color.brewStatusError : .brewTextPrimary)
        }
        .font(.brewCaption)
    }

    private var colour: Color {
        if service.status == "error" { return .brewStatusError }
        return service.running ? .brewStatusSuccess : .brewTextSecondary
    }
}
