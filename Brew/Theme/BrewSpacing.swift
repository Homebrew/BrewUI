import SwiftUI

// MARK: - Brew Design System — Spacing, Layout & Radii (§6, §7)

// 8pt base grid with 4pt half-step for tight internal spacing.

enum BrewSpacing {
    // MARK: Spacing Scale (§6)

    /// 2pt — Icon-to-label gap, badge padding.
    static let xxs: CGFloat = 2

    /// 4pt — Tight internal padding.
    static let xs: CGFloat = 4

    /// 8pt — Standard internal padding, row insets.
    static let sm: CGFloat = 8

    /// 12pt — Section internal padding.
    static let md: CGFloat = 12

    /// 16pt — Panel padding, card insets.
    static let lg: CGFloat = 16

    /// 24pt — Between sections.
    static let xl: CGFloat = 24

    /// 32pt — Empty state vertical margins.
    static let xxl: CGFloat = 32
}

// MARK: - Layout Constants (§6)

enum BrewLayout {
    /// Default sidebar width.
    static let sidebarWidth: CGFloat = 220

    /// Detail inspector panel width.
    static let inspectorWidth: CGFloat = 280

    /// Installed list column (middle pane of `NavigationSplitView`).
    static let installedListColumnMinWidth: CGFloat = 300
    static let installedListColumnIdealWidth: CGFloat = 400
    static let installedListColumnMaxWidth: CGFloat = 800

    /// Third column (package detail).
    static let installedDetailColumnIdealWidth: CGFloat = 400
    static let installedDetailColumnMaxWidth: CGFloat = 1200
    static let installedThreePaneMinWindowWidth: CGFloat = 960

    /// Minimum window width for the main window: sidebar + feature surface.
    /// Installed detail is handled inside the feature view when selected.
    static let minWindowWidth: CGFloat =
        Self.sidebarWidth + Self.installedListColumnMinWidth

    /// Minimum supported window height.
    static let minWindowHeight: CGFloat = 520

    // MARK: Command Console

    /// Collapsed status-strip height (36pt — matches the mock and macOS toolbar idiom).
    static let consoleCollapsedHeight: CGFloat = 36

    /// Lower bound for the expanded console body. Below this the toolbar dominates and output becomes unreadable.
    static let consoleMinExpandedHeight: CGFloat = 120

    /// Upper bound for the expanded console body. Beyond this the main pane is starved.
    static let consoleMaxExpandedHeight: CGFloat = 600

    /// Default expanded console body height when no per-window override is stored.
    static let consoleDefaultExpandedHeight: CGFloat = 240
}

// MARK: - Corner Radii (§7)

enum BrewRadius {
    /// 4pt — Badges, tags, small chips.
    static let sm: CGFloat = 4

    /// 6pt — Buttons, text fields, cards.
    static let md: CGFloat = 6

    /// 10pt — Panels, sheets, popovers.
    static let lg: CGFloat = 10

    /// 14pt — Modal windows, onboarding cards.
    static let xl: CGFloat = 14
}

// MARK: - Shadow Tokens (§8)

extension View {
    /// Cards resting on surface.
    func brewShadowSmall() -> some View {
        shadow(
            color: Color(.sRGB, white: 0, opacity: 0.10),
            radius: 1.5,
            x: 0,
            y: 1,
        )
    }

    /// Popovers, dropdown menus.
    func brewShadowMedium() -> some View {
        shadow(
            color: Color(.sRGB, white: 0, opacity: 0.12),
            radius: 6,
            x: 0,
            y: 4,
        )
    }

    /// Sheets, modal windows.
    func brewShadowLarge() -> some View {
        shadow(
            color: Color(.sRGB, white: 0, opacity: 0.14),
            radius: 12,
            x: 0,
            y: 8,
        )
    }
}

// MARK: - Animation Tokens (§10)

extension Animation {
    /// 0.15s easeOut — Button state changes, badge updates.
    static let brewFast: Animation = .easeOut(duration: 0.15)

    /// 0.25s easeInOut — Panel transitions, list insertions.
    static let brewStandard: Animation = .easeInOut(duration: 0.25)

    /// 0.35s easeInOut — Sheet presentation, modal entrance.
    static let brewSlow: Animation = .easeInOut(duration: 0.35)

    /// Spring — Sidebar expand/collapse.
    static let brewSpring: Animation = .spring(response: 0.35, dampingFraction: 0.75)
}
