import AppKit
import Common

/// Centers a floating window on whichever monitor it's currently displayed on, preserving its size.
/// Deliberately floating-only: tiling (BSP) windows are positioned by the layout engine from tree weights,
/// so "center" has no meaning for them - `layout floating` first, same as `resize` requires for windows that
/// need direct AX-frame manipulation.
struct CenterFloatingWindowCommand: Command {
    let args: CenterFloatingWindowCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        guard window.isFloating else {
            return .fail(io.err("center-floating-window only works for floating windows. Run 'layout floating' first"))
        }
        guard let (monitor, rect) = try? await window.floatingMonitorAndRect(.nonCancellable) else {
            return .fail(io.err(bugPrompt()))
        }

        let desiredTopLeft = CGPoint(
            x: monitor.visibleRect.center.x - rect.width / 2,
            y: monitor.visibleRect.center.y - rect.height / 2,
        )
        setFloatingFrame(window, desiredTopLeft: desiredTopLeft, size: rect.size, on: monitor)
        showActionNotification(window, "Centered")
        return .succ
    }
}
