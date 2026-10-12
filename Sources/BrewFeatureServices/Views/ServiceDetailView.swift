import AppKit
import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

struct ServiceDetailView: View {
    let service: BrewService
    private let labelWidth: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xl) {
            hero
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                PackageDetailSectionHeading(title: LocalizedStringResource(
                    "Details", bundle: #bundle, comment: "Service details: section containing ownership and login registration",
                ))
                metadata(LocalizedStringResource("User", bundle: #bundle, comment: "Service details: service owner reported by Homebrew"),
                         service.user ?? "—", field: .user)
                metadata(LocalizedStringResource("Process ID (PID)", bundle: #bundle, comment: "Service details: process identifier reported by Homebrew"),
                         service.pid.map(String.init) ?? "—", field: .pid)
                metadata(LocalizedStringResource("Exit code", bundle: #bundle, comment: "Service details: last process exit code reported by Homebrew"),
                         service.exitCode.map(String.init) ?? "—", field: .exitCode)
                if ServiceStatusTone(service) == .failed {
                    Text(errorGuidance)
                        .font(.brewCallout).foregroundStyle(Color.brewStatusError)
                        .axid(.serviceDetailValue(.errorGuidance))
                }
                metadata(LocalizedStringResource("Starts at login", bundle: #bundle, comment: "Service details: whether Homebrew registered this service for login"),
                         String(localized: booleanStatus(service.registered)), field: .startsAtLogin)
                metadata(LocalizedStringResource("Schedulable", bundle: #bundle, comment: "Service details: whether the service defines a cron schedule or fixed interval"),
                         String(localized: booleanStatus(service.schedulable)), field: .schedulable)
            }
            PackageDetailSectionDivider()
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                PackageDetailSectionHeading(title: LocalizedStringResource("Files", bundle: #bundle, comment: "Service details: section containing configuration and log paths"))
                path(LocalizedStringResource("Configuration file", bundle: #bundle, comment: "Service details: launchd service file path"), service.file, field: .file)
                path(LocalizedStringResource("Standard log", bundle: #bundle, comment: "Service details: standard output log path"), service.logPath, field: .logPath)
                path(LocalizedStringResource("Error log", bundle: #bundle, comment: "Service details: standard error log path"), service.errorLogPath, field: .errorLogPath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: BrewSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .strokeBorder(Color.brewTextBrand, lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(Color.brewTextBrand)
            }
            .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: BrewSpacing.sm) {
                    name(singleLine: true)
                    ServiceStatusBadge(service: service)
                }
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    name(singleLine: false)
                    ServiceStatusBadge(service: service)
                }
            }
        }
    }

    private func name(singleLine: Bool) -> some View {
        Text(verbatim: service.name)
            .font(.brewTitle1)
            .foregroundStyle(Color.brewTextPrimary)
            .lineLimit(singleLine ? 1 : nil)
            .fixedSize(horizontal: singleLine, vertical: false)
            .textSelection(.enabled)
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

    private func metadata(_ title: LocalizedStringResource, _ value: String, field: AXID.ServiceDetailField) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            Text(title)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(verbatim: value)
                .font(.brewCallout.weight(.medium))
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
                .axid(.serviceDetailValue(field))
            Spacer(minLength: 0)
        }
    }

    private func path(_ title: LocalizedStringResource, _ value: String?, field: AXID.ServiceDetailField) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(title).font(.brewCallout).foregroundStyle(Color.brewTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                Text(verbatim: value.flatMap { $0.isEmpty ? nil : $0 } ?? "—").font(.brewCode).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .axid(.serviceDetailValue(field))
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

struct ServiceDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection", bundle: #bundle, comment: "Service detail placeholder title when nothing is selected")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Choose a service from the list to see details.", bundle: #bundle, comment: "Service detail placeholder body when nothing is selected")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
        .brewPaneContentWidth()
    }
}
