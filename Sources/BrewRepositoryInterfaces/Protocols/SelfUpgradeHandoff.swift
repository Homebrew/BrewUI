/*
 * [INPUT]: 依赖 Swift 并发与交接生命周期
 * [OUTPUT]: 提供 SelfUpgradeHandoff 及无 UI 文案的交接错误
 * [POS]: 交接协议边界；实现只返回失败原因，不选择界面语言
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  SelfUpgradeHandoff.swift
//  BrewRepositoryInterfaces
//

import Foundation

/// Hands off to a short-lived external helper, then quits: ``performUpgrade()`` does not return on success.
/// A thrown error means the handoff never started.
@MainActor
public protocol SelfUpgradeHandoff: Sendable {
    func performUpgrade() async throws
}

/// 交接边界的可恢复失败；具体文案由展示层决定。
public enum SelfUpgradeHandoffError: Error, Sendable {
    case operationRunning
    case helperUnavailable
}
