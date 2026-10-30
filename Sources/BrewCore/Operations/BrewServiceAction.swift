/// Runtime controls that preserve a service's login registration.
public enum BrewServiceAction: Equatable, Sendable {
    case start, stop, restart
}
