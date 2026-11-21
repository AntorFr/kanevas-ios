import XCTest

extension XCUIApplication {
    /// Launches the app pointed at the stub (`-KANEVAS_URL`, AD-5).
    func launch(pointingAt baseURL: URL) {
        launchArguments += ["-KANEVAS_URL", baseURL.absoluteString]
        launch()
    }

    /// Signs in with a stub test account (`/connexion-bouchon`, form field `compte=<id>`): taps the account's
    /// button on the page served by the stub, in the web view. `account` is the display name ("Antor").
    func signIn(account: String, timeout: TimeInterval = 30) {
        let button = webViews.buttons["Se connecter en tant que \(account)"]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "no sign-in button for \(account)")
        button.tap()
    }
}

extension XCTestCase {
    /// Attaches a screenshot to the report, kept even when the test passes.
    func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Starts a stub for the test and stops it at the end; a harness failure fails the test with its reason.
    func startStub(port: Int = StubServer.defaultPort) throws -> StubServer {
        let stub = StubServer(port: port)
        addTeardownBlock { stub.stop() }
        try stub.start()
        return stub
    }
}
