@testable import AppBundle
import Common
import XCTest

@MainActor
final class NotificationsCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        TrayMenuModel.shared.notificationsEnabled = true // Shared singleton - reset before each test
    }

    override func tearDown() async throws {
        TrayMenuModel.shared.notificationsEnabled = true
    }

    func testParseCommand() {
        testParseSingleCommandSucc("notifications on", NotificationsCmdArgs(rawArgs: [], targetState: .on))
        testParseSingleCommandSucc("notifications off", NotificationsCmdArgs(rawArgs: [], targetState: .off))
        testParseSingleCommandSucc("notifications toggle", NotificationsCmdArgs(rawArgs: [], targetState: .toggle))
        testParseSingleCommandSucc(
            "notifications --fail-if-noop on",
            NotificationsCmdArgs(rawArgs: [], targetState: .on).copy(\.failIfNoop, true),
        )
        testParseCommandFail(
            "notifications --fail-if-noop toggle",
            msg: "--fail-if-noop is incompatible with 'toggle' argument",
            exitCode: 2,
        )
    }

    func testOff_disables() async {
        let result = await parseCommand("notifications off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(TrayMenuModel.shared.notificationsEnabled, false)
    }

    func testOn_enables() async {
        TrayMenuModel.shared.notificationsEnabled = false
        let result = await parseCommand("notifications on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(TrayMenuModel.shared.notificationsEnabled, true)
    }

    func testToggle_flipsCurrentState() async {
        await parseCommand("notifications toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(TrayMenuModel.shared.notificationsEnabled, false)

        await parseCommand("notifications toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(TrayMenuModel.shared.notificationsEnabled, true)
    }

    func testAlreadyOn_isNoop() async {
        let result = await parseCommand("notifications on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Notifications are already enabled. Tip: use --fail-if-noop to exit with non-zero code"])
        assertEquals(TrayMenuModel.shared.notificationsEnabled, true)
    }

    func testAlreadyOn_failIfNoop() async {
        let result = await parseCommand("notifications --fail-if-noop on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(TrayMenuModel.shared.notificationsEnabled, true)
    }
}
