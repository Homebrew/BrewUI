/*
 * [INPUT]: 依赖 Foundation 的延迟本地化文案
 * [OUTPUT]: 提供配置分组的本地化标题与原始诊断字段
 * [POS]: 配置展示映射；只有分组标题翻译，配置键值保留原文
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  ConfigSectionItem.swift
//  BrewFeatureConfig
//

import Foundation

/// A presentation-ready group of config rows (title + ordered rows), mapped from the domain snapshot so
/// the UI-free `BrewConfigSnapshot` never carries section labels (`CONVENTIONS.md` — presentation boundary).
struct ConfigSectionItem: Identifiable {
    let id: String
    let title: String.LocalizationValue
    let rows: [ConfigDisplayRow]
}

/// A single label/value row within a ``ConfigSectionItem``.
struct ConfigDisplayRow: Identifiable {
    let id: String
    let label: String
    let value: String
}
