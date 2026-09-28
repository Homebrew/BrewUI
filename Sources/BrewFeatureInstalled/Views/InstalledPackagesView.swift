//
//  InstalledPackagesView.swift
//  Brew
//

import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Middle column of the main window: “Installed” chrome and the package list.
struct InstalledPackagesView: View {
    @Bindable var viewModel: InstalledViewModel
    @FocusState.Binding var focus: SearchFocusTarget?

    @Environment(\.packageListBanner) private var packageListBanner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            packageListBanner()

            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.md) {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Your packages", bundle: #bundle, comment: "Installed tab heading")
                        .font(.brewTitle2)
                        .foregroundStyle(Color.brewTextPrimary)
                    Text(viewModel.packageCountSubtitle)
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityHeading(.h1)

                Button(saveBrewfileLabel, systemImage: "square.and.arrow.down") {
                    saveBrewfile()
                }
                .disabled(!viewModel.canSaveBrewfile || viewModel.isSavingBrewfile)
                .axid(.installedSaveBrewfileButton)
            }
            .padding(BrewSpacing.lg)

            if let outcome = viewModel.brewfileOutcome {
                brewfileOutcomeNote(outcome)
            }

            scopePicker
            hideDependenciesToggle
            Divider()

            AsyncContentView(
                state: viewModel.state,
                onRetry: { Task { await viewModel.refresh() } },
                loaded: { content in
                    installedList(content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                },
            )
        }
        .accessibilityElement(children: .contain)
        .axid(.installedScreen)
        .task {
            await viewModel.load()
        }
    }

    /// Inline result of the last dump. `brew` writes the file itself, so the confirmation names where it
    /// landed; a failure keeps the technical detail in the console and shows the message here.
    @ViewBuilder
    private func brewfileOutcomeNote(_ outcome: BrewfileSaveOutcome) -> some View {
        switch outcome {
        case let .saved(url):
            NoteCallout(
                verbatim: String(
                    localized: "Saved a Brewfile to \(url.path)",
                    bundle: #bundle,
                    comment: "Installed tab: confirmation after saving a Brewfile; %@ is the file path",
                ),
                tone: .brand,
            )
            .padding(.horizontal, BrewSpacing.lg)
        case let .failed(message):
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewStatusError)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BrewSpacing.lg)
        }
    }

    /// While a dump runs the action says so, so the disabled state has a reason on screen.
    private var saveBrewfileLabel: String {
        if viewModel.isSavingBrewfile {
            return String(
                localized: "Saving Brewfile…",
                bundle: #bundle,
                comment: "Installed header: a Brewfile dump is running",
            )
        }
        return String(
            localized: "Save Brewfile…",
            bundle: #bundle,
            comment: "Installed header: save the installed environment as a Brewfile",
        )
    }

    /// Asks for a destination, then lets `brew bundle dump` write it. Cancelling the panel is not a
    /// failure and leaves any earlier outcome on screen untouched.
    private func saveBrewfile() {
        guard let destination = BrewfileSavePanel.chooseDestination() else {
            return
        }
        viewModel.saveBrewfile(to: destination)
    }

    /// Persistent kind filter, always visible. Filters the loaded inventory client-side; never refetches.
    private var scopePicker: some View {
        Picker(String(localized: "Scope", bundle: #bundle, comment: "Installed tab: formula/cask scope picker label"), selection: $viewModel.scope) {
            Text("All", bundle: #bundle, comment: "Scope picker: every package kind").tag(InstalledPackageScope.all)
            Text("Formulae", bundle: #bundle, comment: "Scope picker: formulae only").tag(InstalledPackageScope.formulae)
            Text("Casks", bundle: #bundle, comment: "Scope picker: casks only").tag(InstalledPackageScope.casks)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.bottom, BrewSpacing.sm)
    }

    private var hideDependenciesToggle: some View {
        Toggle(String(localized: "Hide dependencies", bundle: #bundle, comment: "Installed tab: hide dependency-only packages"), isOn: $viewModel.hideDependencies)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.brewSubheadline)
            .foregroundStyle(Color.brewTextSecondary)
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.md)
            .axid(.installedHideDependenciesSwitch)
    }

    private func installedList(_ content: InstalledPackagesContent) -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(content.packages) { package in
                    row(for: package)
                }
            }
            .listStyle(.inset)
            .accessibilityLabel(String(localized: "Installed packages", bundle: #bundle, comment: "VoiceOver: the installed packages list"))
            .axid(.installedList)
            .onAppear {
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .focused($focus, equals: .list)
            .onChange(of: viewModel.activeSelectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, in: content, with: proxy)
            }
            .onChange(of: content.packages.map(\.id)) { previousIDs, currentIDs in
                viewModel.reconcileSelection(afterChangingFrom: previousIDs, to: currentIDs)
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .onKeyPress(.upArrow) {
                viewModel.selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.selectNext()
                return .handled
            }
            .onExitCommand {
                viewModel.clearSelection()
            }
        }
    }

    private func row(for package: InstalledBrewPackage) -> some View {
        InstalledListRowRoot(package: package)
            .id(package.id)
            .contentShape(Rectangle())
            .listRowBackground(
                RoundedRectangle(
                    cornerRadius: BrewRadius.lg,
                    style: .continuous,
                )
                .fill(
                    viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                )
                .padding(.horizontal, BrewSpacing.sm),
            )
            .onTapGesture {
                // Needed to suppress the default ugly blue macOS highlight state
                viewModel.setSelection(package.id)
            }
            .axid(.installedRow(token: package.name))
    }

    private func scrollToSelection(
        _ selectedID: InstalledBrewPackage.ID?,
        in content: InstalledPackagesContent,
        with proxy: ScrollViewProxy,
    ) {
        guard let selectedID, content.packages.contains(where: { $0.id == selectedID }) else {
            return
        }
        withAnimation(.brewFast) {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }
}

#if DEBUG

    #Preview("Installed list - loaded") {
        let viewModel = InstalledViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(),
            preferences: StubInstalledPreferences(),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        SearchFocusPreviewHost { focus in
            InstalledPackagesView(viewModel: viewModel, focus: focus)
        }
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }

    #Preview("Installed list - empty") {
        let viewModel = InstalledViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(packages: PreviewSupport.emptyPackages),
            preferences: StubInstalledPreferences(),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        SearchFocusPreviewHost { focus in
            InstalledPackagesView(viewModel: viewModel, focus: focus)
        }
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }
#endif
