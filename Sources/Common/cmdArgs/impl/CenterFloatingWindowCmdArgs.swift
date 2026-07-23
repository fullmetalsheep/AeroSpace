public struct CenterFloatingWindowCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .centerFloatingWindow,
        help: center_floating_window_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
        ],
        posArgs: [],
    )
}
