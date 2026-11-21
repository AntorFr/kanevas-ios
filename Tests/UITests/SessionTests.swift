import XCTest

/// P-1 to P-3 on the socle shell, against the Kanevas stub (AD-session-3). Observation is by reading elements
/// of the web content, never by pixels.
final class SessionTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let account = "Antor"

    private func launch(_ stub: StubServer, clearSession: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // the simulator's cookie jar outlives a test: a first launch starts from a cleared store (AD-session-1)
        if clearSession { app.launchArguments += ["-KANEVAS_CLEAR_SESSION"] }
        app.launch(pointingAt: stub.baseURL)
        return app
    }

    private func expectAccountChoice(_ app: XCUIApplication) {
        XCTAssertTrue(app.webViews.staticTexts["Choisir un compte de test"].waitForExistence(timeout: 30),
                      "account choice page not shown")
    }

    private func expectMap(_ app: XCUIApplication) {
        let map = app.webViews.staticTexts["Carte de la côte"]
        let shown = map.waitForExistence(timeout: 30)
        if !shown { attachScreenshot("map-not-shown", of: app) }
        XCTAssertTrue(shown, "map not shown")
        XCTAssertFalse(app.webViews.staticTexts["Choisir un compte de test"].exists, "still on the sign-in page")
    }

    /// P-1: no session → account choice → sign in → map.
    func testFirstLaunchSignsInAndShowsMap() throws {
        let stub = try startStub()
        let app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectMap(app)
        attachScreenshot("P-1-first-launch-map", of: app)
    }

    /// P-2: after the process is killed, the relaunch lands on the map without signing in, then a sheet is opened.
    func testRelaunchKeepsSessionAndOpensSheet() throws {
        let stub = try startStub()
        var app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectMap(app)

        app.terminate()
        app = launch(stub)
        expectMap(app)

        let sheet = app.webViews.staticTexts["Maître Aldric"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "character not on the map")
        sheet.tap()
        XCTAssertTrue(app.webViews.staticTexts["Apparence"].waitForExistence(timeout: 30), "sheet lore not shown")
        attachScreenshot("P-2-character-sheet", of: app)
    }

    /// P-3: relaunched with the session cleared, sign-in comes back, then the map.
    func testExpiredSessionAsksSignInAgain() throws {
        let stub = try startStub()
        var app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectMap(app)

        app.terminate()
        app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        attachScreenshot("P-3-session-expired", of: app)
        app.signIn(account: account)
        expectMap(app)
    }
}
