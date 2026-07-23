import AppKit
import Common

/// Shared geometry helpers for commands that reposition/resize *floating* windows directly via their AX
/// frame (as opposed to tiling windows, which are repositioned indirectly by adjusting tree weights and
/// letting `layoutRecursive` compute the physical frame).
///
/// Floating windows aren't bound to a particular monitor (see `Window.layoutFloatingWindow`), so "which
/// monitor is this window on" is always derived from its live AX position rather than from its workspace.
extension Window {
    @MainActor
    func floatingMonitorAndRect(_ cm: CancellationMode) async throws -> (monitor: Monitor, rect: Rect)? {
        guard let rect = try await getAxRect(cm) else { return nil }
        return (rect.center.monitorApproximation, rect)
    }
}

/// Moves/resizes a floating window's AX frame to `size` at `desiredTopLeft`, clamping so the window stays
/// fully visible on `monitor`, and keeps `Window.lastFloatingSize` (consulted by `layout floating` and
/// corner-hide/unhide) in sync with the change.
@MainActor
func setFloatingFrame(_ window: Window, desiredTopLeft: CGPoint, size: CGSize, on monitor: Monitor) {
    let topLeft = monitor.visibleRect.coerceTopLeft(desiredTopLeft, forWindowSize: size)
    window.setAxFrame(topLeft, size)
    window.lastFloatingSize = size
}
