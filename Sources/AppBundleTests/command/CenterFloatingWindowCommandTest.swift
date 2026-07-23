@testable import AppBundle
import Common
import XCTest

@MainActor
final class CenterFloatingWindowCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseSingleCommandSucc("center-floating-window", CenterFloatingWindowCmdArgs(rawArgs: []))
    }

    func testCentersFloatingWindow_preservingSize() async {
        var window: Window!
        Workspace.get(byName: name).floatingWindowsContainer.apply {
            window = TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 100, topLeftY: 100, width: 200, height: 150))
        }
        _ = window.focusWindow()

        let result = await parseCommand("center-floating-window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)

        // Test monitor is 1920x1080 at the origin => center (960, 540)
        let rect = try! await window.getAxRect(.nonCancellable)!
        assertEquals(rect, Rect(topLeftX: 860, topLeftY: 465, width: 200, height: 150))
    }

    func testAlreadyCentered_isNoop() async {
        var window: Window!
        Workspace.get(byName: name).floatingWindowsContainer.apply {
            window = TestWindow.new(id: 1, parent: $0, rect: Rect(topLeftX: 860, topLeftY: 465, width: 200, height: 150))
        }
        _ = window.focusWindow()

        await parseCommand("center-floating-window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let rect = try! await window.getAxRect(.nonCancellable)!
        assertEquals(rect, Rect(topLeftX: 860, topLeftY: 465, width: 200, height: 150))
    }

    func testTilingWindow_fails() async {
        var window: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            window = TestWindow.new(id: 1, parent: $0)
        }
        _ = window.focusWindow()

        let result = await parseCommand("center-floating-window").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["center-floating-window only works for floating windows. Run 'layout floating' first"])
    }

    func testNoWindowFocused_fails() async {
        let workspace = Workspace.get(byName: name)
        let result = await parseCommand("center-floating-window").cmdOrDie.run(.defaultEnv.withWorkspaceName(name), .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
        assertTrue(workspace.isEffectivelyEmpty)
    }
}
