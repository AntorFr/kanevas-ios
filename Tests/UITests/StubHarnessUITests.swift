import XCTest

final class StubHarnessUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The stub can start after the app has launched, on the targeted port, and stops on demand.
    func testStubStartsAfterAppLaunch() throws {
        let stub = StubServer(port: ProcessInfo.processInfo.environment["KANEVAS_STUB_PORT"].flatMap { Int($0) } ?? StubServer.freePort() ?? StubServer.defaultPort)
        addTeardownBlock { stub.stop() }
        XCTAssertFalse(stub.isAnswering(), "port \(stub.port) already served before the test")

        let app = XCUIApplication()
        app.launch(pointingAt: stub.baseURL)   // nothing answers yet: the app must survive it
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        try stub.start()
        XCTAssertTrue(stub.isAnswering())
        let page = StubServer.fetch(stub.baseURL.appendingPathComponent("connexion-bouchon"))
        XCTAssertTrue(page?.body.contains("Choisir un compte de test") == true)

        stub.stop()
        XCTAssertFalse(stub.isAnswering())
        attachScreenshot("app-after-stub-start", of: app)
    }
}
