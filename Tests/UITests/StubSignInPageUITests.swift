import XCTest

final class StubSignInPageUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Without a session, Kanevas serves the stub's account choice page; the app shows it in its web view.
    func testAppShowsAccountChoicePage() throws {
        let stub = try startStub()
        let app = XCUIApplication()
        app.launch(pointingAt: stub.baseURL)

        let page = app.webViews.staticTexts["Choisir un compte de test"]
        expectInWebView(page, of: app, stub: stub, expecting: "Choisir un compte de test")
        XCTAssertTrue(app.webViews.buttons["Se connecter en tant que Antor"].exists)
        attachScreenshot("account-choice", of: app)
    }
}
