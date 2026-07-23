import AppKit
import Common

struct NotificationsCommand: Command {
    let args: NotificationsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let prevState = TrayMenuModel.shared.notificationsEnabled
        let newState: Bool = switch args.targetState.val {
            case .on: true
            case .off: false
            case .toggle: !prevState
        }
        if newState == prevState {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = newState
                        ? "Notifications are already enabled. Tip: use --fail-if-noop to exit with non-zero code"
                        : "Notifications are already disabled. Tip: use --fail-if-noop to exit with non-zero code"
                    return .succ(io.err(msg))
            }
        }

        TrayMenuModel.shared.notificationsEnabled = newState
        return .succ
    }
}
