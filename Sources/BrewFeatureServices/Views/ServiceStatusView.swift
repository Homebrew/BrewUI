import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceStatusView: View {
    let service: BrewService

    var body: some View {
        Label(service.status, systemImage: service.running ? "checkmark.circle.fill" : "circle")
            .font(.brewCaption)
            .foregroundStyle(colour)
    }

    private var colour: Color {
        if service.status == "error" { return .brewStatusError }
        return service.running ? .brewStatusSuccess : .brewTextSecondary
    }
}
