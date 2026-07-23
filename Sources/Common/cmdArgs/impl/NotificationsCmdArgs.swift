public struct NotificationsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .notifications,
        help: notifications_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newMandatoryPosArgParser(\.targetState, parseState, placeholder: NotificationsCmdArgs.State.unionLiteral)],
    )
    public var targetState: Lateinit<State> = .uninitialized
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], targetState: State) {
        self.commonState = .init(rawArgs.slice)
        self.targetState = .initialized(targetState)
    }

    public enum State: String, CaseIterable, Sendable {
        case on, off, toggle
    }
}

func parseNotificationsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<NotificationsCmdArgs> {
    return parseSpecificCmdArgs(NotificationsCmdArgs(rawArgs: args), args)
        .filterNot("--fail-if-noop is incompatible with 'toggle' argument") { $0.targetState.val == .toggle && $0.failIfNoop }
}

private func parseState(i: PosArgParserInput) -> ParsedCliArgs<NotificationsCmdArgs.State> {
    .init(parseEnum(i.arg, NotificationsCmdArgs.State.self), advanceBy: 1)
}
