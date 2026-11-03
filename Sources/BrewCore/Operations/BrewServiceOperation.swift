/// One service action, including the inventory refresh that confirms its result.
public struct BrewServiceOperation: Equatable, Sendable {
    public let serviceID: String
    public let action: BrewServiceAction
    public let phase: BrewOperationPhase

    public init(serviceID: String, action: BrewServiceAction, phase: BrewOperationPhase) {
        self.serviceID = serviceID
        self.action = action
        self.phase = phase
    }
}
