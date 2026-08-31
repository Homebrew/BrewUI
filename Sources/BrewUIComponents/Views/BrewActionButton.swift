//
//  BrewActionButton.swift
//  BrewUIComponents
//

import SwiftUI

/// Compact icon + title action button for chrome — the console toolbar, the command block header.
///
/// One type so those places agree on icon-to-title spacing, hover and pressed highlighting, and how a
/// finished action is acknowledged. Actions that leave no visible trace (copying to the pasteboard,
/// clearing a list) pass a `confirmationTitle`: the button swaps to a tick and that title for a few
/// seconds, which is the only feedback the user gets that the press did anything.
public struct BrewActionButton: View {
    private let title: String
    private let systemImage: String
    private let confirmationTitle: String?
    private let help: String?
    private let action: () -> Void

    @State private var isHovered = false
    @State private var isConfirming = false
    @State private var confirmationTask: Task<Void, Never>?

    /// How long a confirmation stays up before the button returns to its own title.
    private static let confirmationDuration: Duration = .seconds(5)

    public init(
        _ title: String,
        systemImage: String,
        confirmationTitle: String? = nil,
        help: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.confirmationTitle = confirmationTitle
        self.help = help
        self.action = action
    }

    public var body: some View {
        let appearance = BrewActionButtonAppearance(
            title: title,
            systemImage: systemImage,
            confirmationTitle: confirmationTitle,
            isConfirming: isConfirming,
        )
        Button {
            action()
            confirm()
        } label: {
            Label(appearance.title, systemImage: appearance.systemImage)
                .font(.brewCaption)
        }
        .buttonStyle(BrewActionButtonStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .help(help ?? title)
        // The label changes while confirming; the identity a screen reader (or a UI test) matches on
        // must not.
        .accessibilityLabel(title)
    }

    private func confirm() {
        guard confirmationTitle != nil else {
            return
        }
        isConfirming = true
        confirmationTask?.cancel()
        confirmationTask = Task { @MainActor in
            try? await Task.sleep(for: Self.confirmationDuration)
            if !Task.isCancelled {
                isConfirming = false
            }
        }
    }
}

/// What a ``BrewActionButton`` shows right now.
struct BrewActionButtonAppearance: Equatable {
    let title: String
    let systemImage: String

    /// A button with a confirmation title swaps to a tick and that title while its confirmation window
    /// is open; anything else always shows its own title and icon.
    init(title: String, systemImage: String, confirmationTitle: String?, isConfirming: Bool) {
        if isConfirming, let confirmationTitle {
            self.title = confirmationTitle
            self.systemImage = "checkmark"
        } else {
            self.title = title
            self.systemImage = systemImage
        }
    }
}

/// Borderless until pointed at: hovering fills the button so it reads as hit-testable, and pressing it
/// takes the app's selection tint so the press itself is unmistakable.
private struct BrewActionButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isHovered || configuration.isPressed ? Color.brewTextPrimary : Color.brewTextSecondary,
            )
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(background(isPressed: configuration.isPressed)),
            )
            .contentShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
            .animation(.brewFast, value: isHovered)
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed {
            return .brewBrandTint
        }
        return isHovered ? .brewSurfaceElevated : .clear
    }
}

#if DEBUG
    #Preview {
        HStack(spacing: BrewSpacing.xs) {
            BrewActionButton("Save", systemImage: "square.and.arrow.down", help: "Save output to file") {}
            BrewActionButton(
                "Copy",
                systemImage: "doc.on.doc",
                confirmationTitle: "Copied",
                help: "Copy output to clipboard",
            ) {}
            BrewActionButton(
                "Clear",
                systemImage: "trash",
                confirmationTitle: "Cleared",
                help: "Clear completed jobs",
            ) {}
        }
        .padding()
        .background(Color.brewSurface)
    }
#endif
