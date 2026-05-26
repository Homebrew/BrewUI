//
//  ConsoleStatusDot.swift
//  Brew
//

import SwiftUI

/// 8pt status indicator for the console strip. Color follows design-system §4.3/§4.4:
/// running uses the BrewUI-owned brand amber; terminal states use semantic green/red; idle is secondary.
struct ConsoleStatusDot: View {
    let state: ConsoleStatusPresentation.DotState

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 8, height: 8)
    }

    private var fill: Color {
        switch state {
        case .running:
            .brewBrandPrimary
        case .succeeded:
            .brewStatusSuccess
        case .failed:
            .brewStatusError
        case .idle:
            .brewTextTertiary
        }
    }
}
