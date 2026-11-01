import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceActionsView: View {
    let item: ServiceActionsItem
    let isBusy: Bool
    let onPerform: (BrewServiceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            if let restriction = item.restriction {
                Text(restriction)
                    .font(.brewCallout).foregroundStyle(Color.brewTextSecondary)
                    .axid(.serviceActionRestriction)
            } else {
                CommandBlockView(commands: item.runtimeCommands, summaryText: item.runtimeSummary)
                    .axid(.serviceRuntimeCommand)
                Button { onPerform(item.runtimeAction) } label: {
                    Text(item.runtimeTitle)
                        .opacity(isBusy ? 0 : 1)
                        .overlay { if isBusy { ProgressView().controlSize(.small) } }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                .accessibilityLabel(item.runtimeTitle)
                .axid(.serviceRuntimeButton)
                if item.canRestart {
                    CommandBlockView(
                        commands: item.restartCommands,
                        summaryText: LocalizedStringResource("Restarts this service", bundle: #bundle, comment: "Service restart command summary"),
                    )
                    .axid(.serviceRestartCommand)
                    Button(LocalizedStringResource("Restart", bundle: #bundle, comment: "Service action: restart the selected service")) { onPerform(.restart) }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                        .axid(.serviceRestartButton)
                }
            }
        }
    }
}
