public struct LaunchPolicy: Equatable, Sendable {
    public enum ActivationPolicy: Equatable, Sendable {
        case regular
    }

    public var activationPolicy: ActivationPolicy
    public var activatesIgnoringOtherApps: Bool

    public init(
        activationPolicy: ActivationPolicy = .regular,
        activatesIgnoringOtherApps: Bool = true
    ) {
        self.activationPolicy = activationPolicy
        self.activatesIgnoringOtherApps = activatesIgnoringOtherApps
    }
}
