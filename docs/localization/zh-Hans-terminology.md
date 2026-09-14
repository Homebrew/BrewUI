# Simplified Chinese Terminology / 简体中文术语规范

This document defines terminology for maintaining BrewUI's optional Simplified Chinese localization. The term list is a maintenance guide, not a list of new UI strings. See [zh-Hans-glossary.md](zh-Hans-glossary.md) for the complete catalog snapshot.

本文件用于后续新增或更新中文翻译时统一用词。术语表与完整句子词表分开维护；其中部分术语用于说明或文档，不代表界面中新增了同名字符串。

## Nouns and labels / 名词与界面名称

| English term | 统一中文 | 含义与使用规则 |
| --- | --- | --- |
| Package / Packages | 软件包 | Formula 和 Cask 的统称。 |
| Formula / Formulae | Formula | 保留 Homebrew 包类型名称，不译为“公式”。 |
| Cask / Casks | Cask | 保留 Homebrew 包类型名称。 |
| Tap / Taps | Tap | 保留 Homebrew 软件源术语；命令中的 tap 名称保持原样。 |
| Dependency / Dependencies | 依赖 | 当前软件包运行或安装所需的软件包。 |
| Dependent / Dependents | 依赖者 | 依赖当前软件包的其他软件包；与“依赖”方向相反。 |
| Installed | 已安装 | 导航名称或安装状态。 |
| Installed packages | 已安装软件包 | 已安装的软件包集合。 |
| Discover | 发现 | 导航及页面名称。 |
| Doctor | 诊断 | 界面名称；命令 brew doctor 保持原样。 |
| Configuration | 配置 | 配置页面名称。 |
| Language | 语言 | App 显示语言设置。 |
| System Default | 跟随系统 | 采用系统语言偏好；语言菜单的默认选项。 |
| English | English | 语言菜单保留语言自称。 |
| Simplified Chinese | 简体中文 | 对应语言代码 zh-Hans。 |
| Details | 详细信息 | 软件包详情区域标题。 |
| Latest version | 最新版本 | 当前可用的最新版本。 |
| Source | 来源 | 软件包来源字段。 |
| Homepage | 主页 | 软件包项目主页。 |
| License | 许可证 | 软件包许可证字段。 |
| Installed on | 安装时间 | 安装日期或时间字段。 |
| Install reason | 安装原因 | 安装原因字段。 |
| Trending | 热门趋势 | 发现页面中的热门趋势区域。 |
| 30-day installs | 30 天安装量 | 过去 30 天的安装次数。 |
| Results | 搜索结果 | 搜索结果区域标题。 |
| Warning | 警告 | 诊断严重程度。 |
| Danger | 危险 | 诊断严重程度。 |
| Unsupported | 不受支持 | 不受支持状态。 |
| Raw output | 原始输出 | 保留原始诊断文本的区域。 |
| Terminal | 终端 | macOS 终端应用及运行环境。 |
| Terminal command / Terminal commands | 终端命令 | 命令块标题。 |
| Command Line Tools | 命令行工具 | Apple Command Line Tools；Xcode 名称及版本号保持原样。 |
| Report | 报告 | 例如“复制报告”“保存报告”。 |
| Console | 控制台 | App 内命令输出区域；与外部终端区别。 |
| Homebrew / BrewUI / Xcode | 保留原名 | 项目与产品名称不翻译。 |

## Actions and status text / 操作与状态用词

| English | 统一中文 | 使用规则 |
| --- | --- | --- |
| Upgrade / Upgrades | 更新 | 所有界面用词统一为“更新”；brew upgrade 命令不改写。 |
| Install | 安装 | 安装操作。 |
| Uninstall | 卸载 | 卸载操作。 |
| Refresh | 刷新 | 重新读取或刷新数据。 |
| Search | 搜索 | 搜索框及搜索状态；Find 对应“查找”。 |
| Copy | 复制 | 复制操作。 |
| Save | 保存 | 保存操作。 |
| Clear | 清除 | 清除操作。 |
| Loading packages… | 正在加载软件包… | 保留省略号表示进行中。 |
| Restart Required | 需要重启 | 语言切换提示框标题。 |
| Everything is up to date | 所有软件包均为最新版本 | “Everything”明确指软件包。 |

## Maintenance rules / 后续维护规则

1. Consult this table before translating new strings. Reuse the established term for the same concept. 新增文案先查本表，同一概念使用相同译法。
2. Distinguish dependencies from dependents. “依赖”是当前软件包需要的包；“依赖者”是需要当前软件包的包。
3. Update `Homebrew/Resources/Localizable.xcstrings` and the complete glossary together. If terminology changes, update this document and every affected translation in the same change.
4. Preserve format placeholders such as `%@` and `%lld`, including their number, type and intended meaning. Keep command syntax, paths, URLs, package tokens and version numbers unchanged.
5. Keep untranslated diagnostics verbatim when no supported mapping exists. Do not change raw output to make localization appear complete.
6. Check the string catalog and review the affected UI after changes. Do not mark unperformed manual checks as complete.

词表之外的新增术语应在同一次改动中补充英文、中文、含义和必要的使用例子。不得将通用软件包名称、路径或命令语法当作界面标签翻译。
