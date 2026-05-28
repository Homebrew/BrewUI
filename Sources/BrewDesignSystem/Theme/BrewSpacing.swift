import SwiftUI

// MARK: - Brew Design System — Spacing, Layout & Radii (§6, §7)

// 8pt base grid with 4pt half-step for tight internal spacing.

public enum BrewSpacing {
    // MARK: Spacing Scale (§6)

    /// 2pt — Icon-to-label gap, badge padding.
    public static let xxs: CGFloat = 2

    /// 4pt — Tight internal padding.
    public static let xs: CGFloat = 4

    /// 8pt — Standard internal padding, row insets.
    public static let sm: CGFloat = 8

    /// 12pt — Section internal padding.
    public static let md: CGFloat = 12

    /// 16pt — Panel padding, card insets.
    public static let lg: CGFloat = 16

    /// 24pt — Between sections.
    public static let xl: CGFloat = 24

    /// 32pt — Empty state vertical margins.
    public static let xxl: CGFloat = 32
}

// MARK: - Layout Constants (§6)

public enum BrewLayout {
    /// Default sidebar width.
    public static let sidebarWidth: CGFloat = 220

    /// Detail inspector panel width.
    public static let inspectorWidth: CGFloat = 280

    /// Installed list column (middle pane of `NavigationSplitView`).
    public static let installedListColumnMinWidth: CGFloat = 300
    public static let installedListColumnIdealWidth: CGFloat = 400
    public static let installedListColumnMaxWidth: CGFloat = 800

    /// Third column (package detail).
    public static let installedDetailColumnIdealWidth: CGFloat = 400
    public static let installedDetailColumnMaxWidth: CGFloat = 1200
    public static let installedThreePaneMinWindowWidth: CGFloat = 960

    /// Minimum window width for the main window: sidebar + feature surface.
    /// Installed detail is handled inside the feature view when selected.
    public static let minWindowWidth: CGFloat =
        Self.sidebarWidth + Self.installedListColumnMinWidth

    /// Minimum supported window height.
    public static let minWindowHeight: CGFloat = 520

    // MARK: Command Console

    /// Collapsed status-strip height (36pt — matches the mock and macOS toolbar idiom).
    public static let consoleCollapsedHeight: CGFloat = 36

    /// Expanded-mode toolbar height (matches the collapsed strip so resizing the body doesn't shift chrome height).
    public static let consoleToolbarHeight: CGFloat = 36

    /// Lower bound for the expanded console body. Below ~150pt a SwiftUI scroll-indicator artefact from
    /// the main pane bleeds into the console area, on top of the toolbar starting to dominate the output.
    public static let consoleMinExpandedHeight: CGFloat = 150

    /// Upper bound for the expanded console body. Beyond this the main pane is starved.
    public static let consoleMaxExpandedHeight: CGFloat = 600

    /// Default expanded console body height when no per-window override is stored.
    public static let consoleDefaultExpandedHeight: CGFloat = 250
}

// MARK: - Corner Radii (§7)

public enum BrewRadius {
    /// 4pt — Badges, tags, small chips.
    public static let sm: CGFloat = 4

    /// 6pt — Buttons, text fields, cards.
    public static let md: CGFloat = 6

    /// 10pt — Panels, sheets, popovers.
    public static let lg: CGFloat = 10

    /// 14pt — Modal windows, onboarding cards.
    public static let xl: CGFloat = 14
}

// MARK: - Shadow Tokens (§8)

public extension View {
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

public extension Animation {
    /// 0.15s easeOut — Button state changes, badge updates.
    static let brewFast: Animation = .easeOut(duration: 0.15)

    /// 0.25s easeInOut — Panel transitions, list insertions.
    static let brewStandard: Animation = .easeInOut(duration: 0.25)

    /// 0.35s easeInOut — Sheet presentation, modal entrance.
    static let brewSlow: Animation = .easeInOut(duration: 0.35)

    /// Spring — Sidebar expand/collapse.
    static let brewSpring: Animation = .spring(response: 0.35, dampingFraction: 0.75)
}
