import AppKit
import Common
import SwiftUI

/// A tiny, non-intrusive "AppName : Action" toast (à la Amethyst) shown for actions that would
/// otherwise be completely silent - most importantly when triggered by a hotkey, which has no
/// terminal to print errors/results to (see `HotkeyBinding`). Gated on `TrayMenuModel.notificationsEnabled`,
/// which the `notifications` command toggles at runtime.
@MainActor
final class ActionNotificationPanel: NSPanelHud {
    static let shared = ActionNotificationPanel()
    private var timer: Timer?
    private let panelSize = NSSize(width: 240, height: 48)

    override private init() {
        super.init()
    }

    func show(appName: String, action: String) {
        timer?.invalidate()
        contentView?.subviews.removeAll()
        let hostingView = NSHostingView(rootView: ActionNotificationView(appName: appName, action: action))
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        contentView?.addSubview(hostingView)
        // Same "main monitor's Cocoa frame starts at (0, 0)" trick VolumePanel relies on.
        let origin = NSPoint(
            x: (mainMonitor.width - panelSize.width) / 2,
            y: (mainMonitor.height - panelSize.height) / 2,
        )
        setFrame(NSRect(origin: origin, size: panelSize), display: true)
        orderFrontRegardless()
        timer = .scheduledTimer(withTimeInterval: 1.2 /* seconds */, repeats: false) { _ in
            Task.startUnstructured { @MainActor [weak self] in
                self?.close()
            }
        }
    }
}

/// Shows a tiny "AppName : Action" notification, unless notifications are disabled (`notifications off`)
/// or we're running under unit tests (no real windowserver to render a panel against).
@MainActor
func showActionNotification(_ window: Window, _ action: String) {
    guard !isUnitTest, TrayMenuModel.shared.notificationsEnabled else { return }
    ActionNotificationPanel.shared.show(appName: window.app.name ?? "?", action: action)
}

private struct ActionNotificationView: View {
    let appName: String
    let action: String

    @Environment(\.colorScheme) private var colorScheme
    private var textColor: Color { colorScheme == .dark ? .white : .black }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black.opacity(0.75) : Color.white.opacity(0.85) }

    var body: some View {
        HStack(spacing: 6) {
            Text(appName).fontWeight(.semibold)
            Text(":")
            Text(action)
        }
        .font(.system(size: 13))
        .foregroundStyle(textColor)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
