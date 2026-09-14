/*
 * [INPUT]: 依赖 Foundation 的本地化资源 Bundle 与 Locale
 * [OUTPUT]: 提供不可变 AppLocalization，将延迟文案按当前语言解析
 * [POS]: 展示边界的语言快照；不依赖偏好存储，也不改变命令或领域数据
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import Foundation
import SwiftUI

public struct AppLocalization {
    public let locale: Locale
    private let bundle: Bundle

    public init(language: String? = nil, bundle: Bundle = .main) {
        let language = language ?? bundle.preferredLocalizations.first ?? "en"
        locale = Locale(identifier: language)
        // 显式选择资源目录；仅传 locale 不足以改变 Foundation 的 Bundle 查找语言。
        let path = bundle.path(forResource: language, ofType: "lproj")
            ?? bundle.path(forResource: "en", ofType: "lproj")
        self.bundle = path.flatMap(Bundle.init(path:)) ?? bundle
    }

    public var layoutDirection: LayoutDirection {
        locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    public func string(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle, locale: locale)
    }
}

public extension EnvironmentValues {
    @Entry var brewLocalization = AppLocalization()
}
