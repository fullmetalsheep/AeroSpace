import AppKit
import Common

struct ResizeCommand: Command {
    let args: ResizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }

        switch window.windowParentCases {
            case .floatingWindowsContainer:
                return await resizeFloatingWindow(window, args, io)
            case .tilingContainer:
                return resizeTilingWindow(window, args, io)
            case .unbound, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer, .macosPopupWindowsContainer:
                return .fail(io.err("resize command doesn't support macOS fullscreen, minimized windows, or windows of hidden apps"))
        }
    }
}

// MARK: - Tiling (BSP) windows

@MainActor private func resizeTilingWindow(_ window: Window, _ args: ResizeCmdArgs, _ io: CmdIo) -> BinaryExitCode {
    let candidates = window.parentsWithSelf
        .filter { ($0.parent as? TilingContainer)?.layout == .tiles }

    let orientation: Orientation?
    let parent: TilingContainer?
    let node: TreeNode?
    switch args.dimension.val {
        case .width:
            orientation = .h
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
            parent = node?.parent as? TilingContainer
        case .height:
            orientation = .v
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
            parent = node?.parent as? TilingContainer
        case .smart:
            node = candidates.first
            parent = node?.parent as? TilingContainer
            orientation = parent?.orientation
        case .smartOpposite:
            orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
            node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
            parent = node?.parent as? TilingContainer
    }
    guard let parent else {
        return .fail(io.err("The window doesn't have siblings to resize against (its tiling container has no 'tiles' ancestor along that axis)"))
    }
    guard let orientation else { return .fail }
    guard let node else { return .fail }
    let diff: CGFloat = switch args.units.val {
        case .set(let unit): CGFloat(unit) - node.getWeight(orientation)
        case .add(let unit): CGFloat(unit)
        case .subtract(let unit): -CGFloat(unit)
    }

    guard let childDiff = diff.div(parent.children.count - 1) else { return .fail }
    parent.children.lazy
        .filter { $0 != node }
        .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

    node.setWeight(orientation, node.getWeight(orientation) + diff)
    return .succ
}

// MARK: - Floating windows

/// Floating windows have no tiling "weight" - they have a real, physical AX frame. Resizing one means
/// growing/shrinking its actual frame around its current center, then clamping so it stays fully visible on
/// whichever monitor it's currently displayed on. There's no tiling container to derive an orientation from,
/// so `smart`/`smart-opposite` fall back to a documented, fixed mapping (`smart` == `width`, `smart-opposite`
/// == `height`) instead of failing outright - this keeps a single keybinding-agnostic `resize` config
/// (e.g. `alt-shift-h = 'resize smart -50'`) usable regardless of whether the focused window is floating or
/// tiled, which is the whole point of `smart` in the first place.
@MainActor private func resizeFloatingWindow(_ window: Window, _ args: ResizeCmdArgs, _ io: CmdIo) async -> BinaryExitCode {
    guard let (monitor, rect) = try? await window.floatingMonitorAndRect(.nonCancellable) else {
        return .fail(io.err(bugPrompt()))
    }

    let isWidth: Bool = switch args.dimension.val {
        case .width, .smart: true
        case .height, .smartOpposite: false
    }

    let currentValue = isWidth ? rect.width : rect.height
    let requestedValue: CGFloat = switch args.units.val {
        case .set(let unit): CGFloat(unit)
        case .add(let unit): currentValue + CGFloat(unit)
        case .subtract(let unit): currentValue - CGFloat(unit)
    }
    // A window can't shrink to nothing; mirrors macOS itself refusing sub-1pt frames.
    let newValue = max(1, requestedValue)

    let newSize = isWidth ? CGSize(width: newValue, height: rect.height) : CGSize(width: rect.width, height: newValue)
    // Anchor on the window's current center so growing/shrinking feels symmetric instead of the window
    // jumping toward its bottom-right corner.
    let desiredTopLeft = CGPoint(x: rect.center.x - newSize.width / 2, y: rect.center.y - newSize.height / 2)

    setFloatingFrame(window, desiredTopLeft: desiredTopLeft, size: newSize, on: monitor)
    return .succ
}
