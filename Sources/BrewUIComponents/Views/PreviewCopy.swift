//
//  PreviewCopy.swift
//  BrewUIComponents
//

import Foundation

#if DEBUG
    /// Sample copy for `#Preview` bodies. A literal written straight into a
    /// `LocalizedStringResource` parameter is an extraction site; routing through a runtime `String`
    /// keeps preview text out of the catalogs.
    public func previewCopy(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: text)
    }
#endif
