//
//  AsyncContentView.swift
//  Brew
//

import BrewCore
import SwiftUI

/// Renders a ``LoadState`` by switching on its case and standardises the boilerplate that would
/// otherwise be repeated at every loadable surface.
///
/// The loading case reuses the exact same `loaded` view tree, populated with `Content.placeholder`
/// and modified by `.redacted(reason: .placeholder)`. This guarantees the skeleton matches the
/// loaded layout instead of a hand-built one drifting out of sync. Hit-testing is disabled while the
/// placeholder is on screen.
///
/// `Failure` is fixed to `String`: ViewModels map their repository errors to user-facing copy before
/// handing the state here (`CONVENTIONS.md` — Loadable UI state), so ``ErrorStateView`` only needs a
/// message.
public struct AsyncContentView<Content: Placeholdable, LoadedView: View>: View {
    let state: LoadState<Content, String>
    let onRetry: (() -> Void)?
    @ViewBuilder let loaded: (Content) -> LoadedView

    public init(
        state: LoadState<Content, String>,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder loaded: @escaping (Content) -> LoadedView,
    ) {
        self.state = state
        self.onRetry = onRetry
        self.loaded = loaded
    }

    public var body: some View {
        switch state {
        case .loading:
            loaded(Content.placeholder)
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
        case let .loaded(content):
            loaded(content)
        case let .failed(message):
            ErrorStateView(message: message, onRetry: onRetry)
        }
    }
}

/// Standard failure presentation: a warning glyph, the human-readable message a ViewModel mapped from
/// its error, and an optional Retry button. Pass `onRetry: nil` when a tap can't recover the failure.
struct ErrorStateView: View {
    let message: String
    let onRetry: (() -> Void)?

    init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: BrewSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewStatusError)
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewStatusError)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button("Retry", action: onRetry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#if DEBUG
    private struct AsyncContentPreviewItem: Placeholdable, Identifiable {
        let id: Int
        let title: String
        let subtitle: String

        static var placeholder: AsyncContentPreviewItem {
            AsyncContentPreviewItem(id: -1, title: "Placeholder title", subtitle: "Placeholder secondary line")
        }
    }

    private func asyncContentPreviewRows(_ item: AsyncContentPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(item.title)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
            Text(item.subtitle)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    #Preview("Loaded") {
        AsyncContentView(
            state: .loaded(AsyncContentPreviewItem(id: 1, title: "git", subtitle: "Distributed revision control")),
        ) { item in
            asyncContentPreviewRows(item)
        }
        .frame(width: 360, height: 160)
    }

    #Preview("Loading") {
        AsyncContentView(state: .loading) { (item: AsyncContentPreviewItem) in
            asyncContentPreviewRows(item)
        }
        .frame(width: 360, height: 160)
    }

    #Preview("Failed with retry") {
        AsyncContentView(
            state: .failed("Something went wrong loading packages."),
            onRetry: {},
            loaded: { (item: AsyncContentPreviewItem) in
                asyncContentPreviewRows(item)
            },
        )
        .frame(width: 360, height: 200)
    }

    #Preview("Failed without retry") {
        AsyncContentView(
            state: .failed("Something went wrong loading packages."),
        ) { (item: AsyncContentPreviewItem) in
            asyncContentPreviewRows(item)
        }
        .frame(width: 360, height: 200)
    }
#endif
