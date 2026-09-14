/*
 * [INPUT]: 依赖 SwiftUI、Discover 展示模型与 brewLocalization 环境
 * [OUTPUT]: 提供 DiscoverInstalledBadge
 * [POS]: Discover 界面组合；按当前语言渲染应用文案，外部包数据原样显示
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import BrewUIComponents
import SwiftUI

/// Installed status pill shared by discover list rows and package detail.
struct DiscoverInstalledBadge: View {
    @Environment(\.brewLocalization) private var localization
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
            Image(systemName: "checkmark.circle")
            Text(
                localization.string("INSTALLED"),
            )
        }
        .font(.brewCaption2)
        .foregroundStyle(Color.brewStatusSuccess)
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background {
            Capsule()
                .fill(Color.brewStatusSuccessSubtle)
        }
        .accessibilityLabel(
            localization.string("Installed"),
        )
    }
}

#Preview {
    DiscoverInstalledBadge()
        .padding()
}
