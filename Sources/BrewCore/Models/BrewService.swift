/// A service reported by `brew services info`.
public struct BrewService: Identifiable, Equatable, Sendable {
    public let name: String, status: String
    public let running: Bool
    public let pid: Int?, exitCode: Int?
    public let user: String?
    public let registered: Bool?, schedulable: Bool?
    public let file: String?
    public let logPath: String?, errorLogPath: String?

    public var id: String {
        name
    }

    public init(
        name: String, status: String, running: Bool,
        pid: Int? = nil, exitCode: Int? = nil, user: String? = nil, registered: Bool? = nil, schedulable: Bool? = nil,
        file: String? = nil, logPath: String? = nil, errorLogPath: String? = nil,
    ) {
        self.name = name
        self.status = status
        self.running = running
        self.pid = pid
        self.exitCode = exitCode
        self.user = user
        self.registered = registered
        self.schedulable = schedulable
        self.file = file
        self.logPath = logPath
        self.errorLogPath = errorLogPath
    }
}
