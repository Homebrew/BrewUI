import AppKit
import BrewUIComponents
import SwiftUI

struct LanguageChangePrompt: View {
    let localization: AppLocalization
    let language: String
    let isBusy: Bool
    let respond: (NSApplication.ModalResponse) -> Void

    private var languageName: String {
        Locale(identifier: language).localizedString(forIdentifier: language) ?? language
    }

    private var title: String {
        localization.string("Switch to \(languageName)?")
    }

    var body: some View {
        VStack(spacing: BrewSpacing.lg) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: BrewLayout.confirmationIconSize, height: BrewLayout.confirmationIconSize)
                .accessibilityHidden(true)
            Text(title)
                .font(.brewTitle3)
            Text(localization.string("The entire app will use \(languageName) the next time you open it. Reopening closes all current windows."))
                .font(.brewBody)
                .textSelection(.enabled)
            if isBusy {
                Text(localization.string("A Homebrew operation is running. You can reopen the app after it finishes; it will not reopen automatically."))
                    .font(.brewCallout)
                    .foregroundStyle(.secondary)
            }
            actions
        }
        .multilineTextAlignment(.center)
        .padding(BrewSpacing.xl)
        .frame(width: BrewLayout.confirmationWidth)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.locale, localization.locale)
        .environment(\.layoutDirection, localization.layoutDirection)
    }

    private var actions: some View {
        VStack(spacing: BrewSpacing.sm) {
            Button { respond(.alertSecondButtonReturn) } label: {
                Text(localization.string("Reopen Now")).frame(maxWidth: .infinity)
            }
            .keyboardShortcut(isBusy ? nil : .defaultAction)
            .disabled(isBusy)
            Button { respond(.alertFirstButtonReturn) } label: {
                Text(localization.string("Next Launch")).frame(maxWidth: .infinity)
            }
            .keyboardShortcut(isBusy ? .defaultAction : nil)
            Button { respond(.alertThirdButtonReturn) } label: {
                Text(localization.string("Undo Language Change")).frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.cancelAction)
        }
        .controlSize(.large)
    }

    @MainActor
    static func present(localization: AppLocalization, language: String, isBusy: Bool, centeredOn owner: NSWindow?) -> NSApplication.ModalResponse {
        let view = Self(localization: localization, language: language, isBusy: isBusy) { NSApp.stopModal(withCode: $0) }
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = view.title
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        // Avoid `NSAlert.runModal` / `NSWindow.center`, which the framework recenters on the screen or visually high.
        if let owner {
            panel.setFrameOrigin(NSPoint(x: owner.frame.midX - panel.frame.width / 2, y: owner.frame.midY - panel.frame.height / 2))
        } else {
            panel.center()
        }
        // `runModal` recenters windows that are not yet visible; order the panel front first so the parent-window origin is kept.
        panel.orderFront(nil)
        defer { panel.orderOut(nil); panel.close() }
        return NSApp.runModal(for: panel)
    }
}
