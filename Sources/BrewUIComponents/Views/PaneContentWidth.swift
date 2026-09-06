//
//  PaneContentWidth.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// The outer frame keeps the enclosing scroll view full-width, so its scroller stays at the pane's
    /// trailing edge rather than stopping where the content does.
    func brewPaneContentWidth() -> some View {
        frame(maxWidth: BrewLayout.paneContentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
