import BrewUIComponents
import SwiftUI

/// 两个分组共用普通标题外观；吸顶定位仍由原生 List 决定。
struct DiscoverSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .brewPlainListSectionHeader()
    }
}
