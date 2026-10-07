import AppKit
import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceDetailView: View {
    let service: BrewService
    private let labelWidth: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xl) {
            HStack(spacing: BrewSpacing.sm) {
                Text(verbatim: service.name)
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)
                    .textSelection(.enabled)
                ServiceStatusView(service: service)
                    .padding(.horizontal, BrewSpacing.sm).padding(.vertical, BrewSpacing.xs)
                    .background(Color.brewSurfaceElevated, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.brewBorderDefault, lineWidth: 1) }
            }
            PackageDetailSectionDivider()
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                PackageDetailSectionHeading(title: LocalizedStringResource(
                    "Details", bundle: #bundle, comment: "Service details: section containing ownership and login registration",
                ))
                metadata(LocalizedStringResource("User", bundle: #bundle, comment: "Service details: service owner reported by Homebrew"), service.user ?? "—")
                metadata(LocalizedStringResource("Process ID (PID)", bundle: #bundle, comment: "Service details: process identifier reported by Homebrew"),
                         service.pid.map(String.init) ?? "—")
                metadata(LocalizedStringResource("Exit code", bundle: #bundle, comment: "Service details: last process exit code reported by Homebrew"),
                         service.exitCode.map(String.init) ?? "—")
                if service.status == "error" {
                    Text(errorGuidance)
                        .font(.brewCallout).foregroundStyle(Color.brewStatusError)
                }
                metadata(LocalizedStringResource("Starts at login", bundle: #bundle, comment: "Service details: whether Homebrew registered this service for login"),
                         String(localized: booleanStatus(service.registered)))
                metadata(LocalizedStringResource("Schedulable", bundle: #bundle, comment: "Service details: whether the service defines a cron schedule or fixed interval"),
                         String(localized: booleanStatus(service.schedulable)))
            }
            PackageDetailSectionDivider()
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                PackageDetailSectionHeading(title: LocalizedStringResource("Files", bundle: #bundle, comment: "Service details: section containing configuration and log paths"))
                path(LocalizedStringResource("Configuration file", bundle: #bundle, comment: "Service details: launchd service file path"), service.file)
                path(LocalizedStringResource("Standard log", bundle: #bundle, comment: "Service details: standard output log path"), service.logPath)
                path(LocalizedStringResource("Error log", bundle: #bundle, comment: "Service details: standard error log path"), service.errorLogPath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorGuidance: LocalizedStringResource {
        service.errorLogPath?.isEmpty == false
            ? LocalizedStringResource("Check the error log for details.", bundle: #bundle, comment: "Service details: error status guidance")
            : LocalizedStringResource("No error log path reported.", bundle: #bundle, comment: "Service details: Homebrew returned an error without an error log path")
    }

    private func booleanStatus(_ value: Bool?) -> LocalizedStringResource {
        switch value {
        case true: LocalizedStringResource("Yes", bundle: #bundle, comment: "Service details: reported boolean is true")
        case false: LocalizedStringResource("No", bundle: #bundle, comment: "Service details: reported boolean is false")
        default: LocalizedStringResource("Unknown", bundle: #bundle, comment: "Service details: Homebrew did not report this value")
        }
    }

    private func metadata(_ title: LocalizedStringResource, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(title).foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(verbatim: value)
                .fontWeight(.medium)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.brewCallout)
    }

    private func path(_ title: LocalizedStringResource, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(title).font(.brewCallout).foregroundStyle(Color.brewTextSecondary)
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
