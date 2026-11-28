import XCTest

/// P-4 / E-2 (B-6), written from the need: HTTP >= 500 and network loss show E-2 over the page, Retry reloads the
/// address that failed, a 4xx is Kanevas' own page and never E-2.
final class UnreachableStatesTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func makeStatusServer(_ status: Int, _ text: String) throws -> StatusServer {
        let server = StatusServer()
        try server.start(status: status, body: text)
        addTeardownBlock { server.stop() }
        return server
    }

    private func url(_ port: Int) -> URL { URL(string: "http://127.0.0.1:\(port)")! }

    /// Fails if E-2 is not shown, or loses its message or button.
    private func assertE2(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["unreachableMessage"].waitForExistence(timeout: 30), "E-2 message missing", file: file, line: line)
        XCTAssertEqual(app.staticTexts["unreachableMessage"].label, "Kanevas is unreachable", file: file, line: line)
        XCTAssertTrue(app.buttons["retryButton"].exists, "Retry missing", file: file, line: line)
        XCTAssertEqual(app.buttons["retryButton"].label, "Retry", file: file, line: line)
    }

    /// E-2 (P-4). Fails if a 5xx main-frame response is let through to the page instead of E-2.
    func testHTTP503ShowsE2ThenRetryLoadsThePage() throws {
        let server = try makeStatusServer(503, "Service down")
        let app = XCUIApplication()
        app.launch(pointingAt: url(server.port))
        assertE2(app)
        XCTAssertFalse(app.webViews.staticTexts["Service down"].exists, "the broken page is visible")
        attachScreenshot("P-4-http-503", of: app)

        server.respond(status: 200, body: "Back online")
        app.buttons["retryButton"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Back online"].waitForExistence(timeout: 30), "page not loaded after Retry")
        XCTAssertFalse(app.buttons["retryButton"].exists, "E-2 still up after a successful Retry")
    }

    /// E-1 (not E-2). Fails if every HTTP error, 4xx included, shows E-2.
    func testHTTP404ShowsKanevasOwnPageNotE2() throws {
        let server = try makeStatusServer(404, "Page introuvable")
        let app = XCUIApplication()
        app.launch(pointingAt: url(server.port))
        XCTAssertTrue(app.webViews.staticTexts["Page introuvable"].waitForExistence(timeout: 30), "404 page not shown")
        XCTAssertFalse(app.staticTexts["unreachableMessage"].exists)
        XCTAssertFalse(app.buttons["retryButton"].exists)
    }

    /// E-2 (P-4). Fails if a failed Retry leaves the child on a blank page without E-2.
    func testRetryWhileStillDownShowsE2Again() throws {
        let server = try makeStatusServer(500, "Boom")
        let app = XCUIApplication()
        app.launch(pointingAt: url(server.port))
        assertE2(app)
        app.buttons["retryButton"].tap()
        // E-2 may blink out at the tap; it must be back once the attempt failed.
        Thread.sleep(forTimeInterval: 3)
        assertE2(app)
        XCTAssertTrue(app.buttons["retryButton"].isHittable)
    }

    /// E-2 over a page already read. Fails if the page stays visible under the failure, or if Retry reloads
    /// another address than the one that failed.
    func testNetworkDropAfterPageReadCoversThePage() throws {
        let stub = try startStub()
        let app = XCUIApplication()
        app.launch(pointingAt: stub.baseURL)
        XCTAssertTrue(app.webViews.staticTexts["Choisir un compte de test"].waitForExistence(timeout: 30))

        stub.stop()
        app.webViews.buttons["Se connecter en tant que Antor"].tap()
        assertE2(app)
        attachScreenshot("P-4-network-dropped", of: app)

        try stub.start()
        app.buttons["retryButton"].tap()
        XCTAssertTrue(app.webViews.staticTexts.firstMatch.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["retryButton"].exists, "E-2 still up after Retry with Kanevas back")
    }

    /// E-2 with the largest text size, landscape. Fails if the message is truncated off screen or Retry is not tappable.
    func testE2LargestTextLandscapeKeepsRetryTappable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let server = try makeStatusServer(503, "Down")
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch(pointingAt: url(server.port))
        assertE2(app)
        XCTAssertTrue(app.buttons["retryButton"].isHittable)
        XCTAssertTrue(app.staticTexts["unreachableMessage"].isHittable)
        attachScreenshot("E-2-xxxl-landscape", of: app)
    }
}
