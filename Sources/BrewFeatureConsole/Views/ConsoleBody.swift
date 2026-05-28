//
//  ConsoleBody.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Output area of the expanded console — virtualizing `List` over the selected job's output buffer
/// with auto-pin-to-bottom when new lines arrive. User scroll-lock-on-scroll-up is deferred to polish.
struct ConsoleBody: View {
    let viewModel: ConsoleViewModel

    var body: some View {
        if let job = viewModel.selectedJob {
            outputList(for: job)
        } else {
            ContentUnavailableView(
                "No activity",
                systemImage: "terminal",
                description: Text("Run a brew command to see output here."),
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.brewSurfaceElevated)
        }
    }

    private func outputList(for job: CommandJob) -> some View {
        ScrollViewReader { proxy in
            List(job.output) { line in
                Text(line.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(line.stream == .stderr ? Color.brewStatusError : Color.brewTextPrimary)
                    .textSelection(.enabled)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 1, leading: BrewSpacing.lg, bottom: 1, trailing: BrewSpacing.lg))
                    .id(line.id)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.brewSurfaceElevated)
            .onAppear {
                if let last = job.output.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: job.output.count) {
                guard let last = job.output.last else {
                    return
                }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
