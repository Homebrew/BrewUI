#if DEBUG
    import BrewUIComponents
    import SwiftUI

    /// Owns the `@FocusState` that the packages views expect from their container, which a `#Preview`
    /// closure cannot declare for itself.
    struct SearchFocusPreviewHost<Content: View>: View {
        @FocusState private var focus: SearchFocusTarget?

        @ViewBuilder let content: (FocusState<SearchFocusTarget?>.Binding) -> Content

        var body: some View {
            content($focus)
        }
    }
#endif
