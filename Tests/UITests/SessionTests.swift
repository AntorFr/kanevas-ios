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

    /// Any element of the web content carrying this label (a link, a heading, a card: the page decides).
    private func element(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// The stub serves « Mes univers » at `/` (its default target after sign-in and on a relaunch with a session).
    private func expectLanding(_ app: XCUIApplication) {
        let shown = element(app, "Lame d'Ébène").waitForExistence(timeout: 30)
        if !shown { attachScreenshot("landing-not-shown", of: app) }
        XCTAssertTrue(shown, "universe list not shown")
        XCTAssertFalse(app.webViews.staticTexts["Choisir un compte de test"].exists, "still on the sign-in page")
    }

    private func tap(_ app: XCUIApplication, _ label: String) {
        let target = element(app, label)
        if !target.waitForExistence(timeout: 30) { attachScreenshot("missing-\(label)", of: app) }
        XCTAssertTrue(target.exists, "« \(label) » not shown")
        // the web view reports some links as not hittable (cards, sidebar): tap their centre instead
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// From the universe list to the map, through the page's own links (the app draws no navigation, E-1).
    private func openMap(_ app: XCUIApplication) {
        tap(app, "Lame d'Ébène")
        tap(app, "Cartes")
        tap(app, "Carte de la côte")
        let shown = element(app, "Maître Aldric").waitForExistence(timeout: 30)
        if !shown { attachScreenshot("map-not-shown", of: app) }
        XCTAssertTrue(shown, "map not shown")
    }

    /// P-1: no session → account choice → sign in → universe list → map.
    func testFirstLaunchSignsInAndShowsMap() throws {
        let stub = try startStub()
        let app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectLanding(app)
        openMap(app)
        attachScreenshot("P-1-first-launch-map", of: app)
    }

    /// P-2: after the process is killed, the relaunch lands on the universe list without signing in, then the map and a sheet are opened.
    func testRelaunchKeepsSessionAndOpensSheet() throws {
        let stub = try startStub()
        var app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectLanding(app)

        app.terminate()
        app = launch(stub)
        expectLanding(app)
        openMap(app)

        tap(app, "Maître Aldric")
        let lore = element(app, "Apparence").waitForExistence(timeout: 30)
        if !lore { attachScreenshot("sheet-not-shown", of: app) }
        XCTAssertTrue(lore, "sheet lore not shown")
        attachScreenshot("P-2-character-sheet", of: app)
    }

    /// P-3: relaunched with the session cleared, sign-in comes back, then the universe list and the map.
    func testExpiredSessionAsksSignInAgain() throws {
        let stub = try startStub()
        var app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        app.signIn(account: account)
        expectLanding(app)

        app.terminate()
        app = launch(stub, clearSession: true)
        expectAccountChoice(app)
        attachScreenshot("P-3-session-expired", of: app)
        app.signIn(account: account)
        expectLanding(app)
        openMap(app)
    }
}
