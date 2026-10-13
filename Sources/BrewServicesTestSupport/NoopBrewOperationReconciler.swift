//
//  NoopBrewOperationReconciler.swift
//  BrewServicesTestSupport
//

import BrewCore
import Foundation

/// Reconciler for tests whose subject is not the settling window. Production always reconciles against
/// the installed inventory, so ``SerialBrewCommandCenter`` requires one.
public final class NoopBrewOperationReconciler: BrewOperationReconciling {
    public init() {}

    public func reconcile() async {}
}
