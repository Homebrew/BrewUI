import AppKit
import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceDetailView: View {
    let service: BrewService

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.lg) {
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Text(verbatim: service.name).font(.brewTitle2).textSelection(.enabled)
                ServiceStatusView(service: service)
                    .padding(.horizontal, BrewSpacing.sm).padding(.vertical, BrewSpacing.xs)
                    .background(Color.brewSurfaceRecessed, in: RoundedRectangle(cornerRadius: BrewRadius.sm))
            }
            Divider()
            Text("Details", bundle: #bundle, comment: "Service details: section containing ownership and login registration")
                .font(.brewTitle3)
            metadata(LocalizedStringResource("User", bundle: #bundle, comment: "Service details: service owner reported by Homebrew"), service.user ?? "—")
            metadata(
                LocalizedStringResource("Process ID (PID)", bundle: #bundle, comment: "Service details: process identifier reported by Homebrew"),
                service.pid.map(String.init) ?? "—",
            )
            metadata(
                LocalizedStringResource("Exit code", bundle: #bundle, comment: "Service details: last process exit code reported by Homebrew"),
                service.exitCode.map(String.init) ?? "—",
            )
            if service.status == "error" {
                Text(errorGuidance)
                    .font(.brewCaption).foregroundStyle(Color.brewStatusError)
            }
            metadata(
                LocalizedStringResource("Starts at login", bundle: #bundle, comment: "Service details: whether Homebrew registered this service for login"),
                String(localized: booleanStatus(service.registered)),
            )
            metadata(
                LocalizedStringResource("Schedulable", bundle: #bundle, comment: "Service details: whether the service defines a cron schedule or fixed interval"),
                String(localized: booleanStatus(service.schedulable)),
            )
            Divider()
            Text("Files", bundle: #bundle, comment: "Service details: section containing configuration and log paths")
                .font(.brewTitle3)
            path(LocalizedStringResource("Configuration file", bundle: #bundle, comment: "Service details: launchd service file path"), service.file)
            path(LocalizedStringResource("Standard log", bundle: #bundle, comment: "Service details: standard output log path"), service.logPath)
            path(LocalizedStringResource("Error log", bundle: #bundle, comment: "Service details: standard error log path"), service.errorLogPath)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorGuidance: LocalizedStringResource {
        if service.errorLogPath?.isEmpty == false {
            LocalizedStringResource("Check the error log for details.", bundle: #bundle, comment: "Service details: error status guidance")
        } else {
            LocalizedStringResource("No error log path reported.", bundle: #bundle, comment: "Service details: Homebrew returned an error without an error log path")
        }
    }

    private func booleanStatus(_ value: Bool?) -> LocalizedStringResource {
        switch value {
        case true: LocalizedStringResource("Yes", bundle: #bundle, comment: "Service details: reported boolean is true")
        case false: LocalizedStringResource("No", bundle: #bundle, comment: "Service details: reported boolean is false")
        default: LocalizedStringResource("Unknown", bundle: #bundle, comment: "Service details: Homebrew did not report this value")
        }
    }

    private func metadata(_ title: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.brewTextSecondary)
            Spacer(minLength: BrewSpacing.md)
            Text(verbatim: value)
        }
        .font(.brewCallout)
    }

    private func path(_ title: LocalizedStringResource, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(title).font(.brewCaption).foregroundStyle(Color.brewTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                Text(verbatim: value.flatMap { $0.isEmpty ? nil : $0 } ?? "—").font(.brewCode).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let value, !value.isEmpty {
                    BrewActionButton(
                        LocalizedStringResource("Copy", bundle: #bundle, comment: "Service files: copy a file path"),
                        systemImage: "doc.on.doc",
                        confirmationTitle: LocalizedStringResource("Copied", bundle: #bundle, comment: "Service files: confirms the path was copied"),
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }
                    .fixedSize()
                    .accessibilityLabel(String(
                        localized: "Copy path: \(String(localized: title))", bundle: #bundle,
                        comment: "Service files: copy button; %@ is the configuration or log path label",
                    ))
                }
            }
        }
    }
}
