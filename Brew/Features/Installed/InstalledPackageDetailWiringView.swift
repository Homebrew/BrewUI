//
//  InstalledPackageDetailWiringView.swift
//  Brew
//

import SwiftUI

/// Reads ``EnvironmentValues/brewCommandCenter`` and forwards it into the detail subtree (same instance the composition root put on ``InstalledDetailsViewModel``). No selection or load-state logic here.
struct InstalledPackageDetailWiringView: View {
    @Bindable var viewModel: InstalledDetailsViewModel
    @Environment(\.brewCommandCenter) private var brewCommandCenter

    var body: some View {
        InstalledPackageDetailView(viewModel: viewModel)
            .environment(\.brewCommandCenter, brewCommandCenter)
    }
}
