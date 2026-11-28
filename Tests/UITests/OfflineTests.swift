import Darwin
import XCTest

/// P-4 (AD-reseau-4): nothing listens at Kanevas' address, E-2 shows; the stub then starts on that port and Retry loads Kanevas.
final class OfflineTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testUnreachableThenRetryLoadsKanevas() throws {
        let port = try freeLoopbackPort()
        let app = XCUIApplication()
        app.launch(pointingAt: URL(string: "http://127.0.0.1:\(port)")!)

        XCTAssertTrue(app.staticTexts["unreachableMessage"].waitForExistence(timeout: 30), "E-2 not shown")
        let retry = app.buttons["retryButton"]
        XCTAssertTrue(retry.exists, "Retry button missing")
        attachScreenshot("P-4-unreachable", of: app)

        let stub = try startStub(port: port)
        XCTAssertTrue(stub.isRunning)
        retry.tap()

        let page = app.webViews.staticTexts["Choisir un compte de test"]
        XCTAssertTrue(page.waitForExistence(timeout: 30), "Kanevas not loaded after Retry")
        XCTAssertFalse(app.buttons["retryButton"].exists)
        attachScreenshot("P-4-after-retry", of: app)
    }

    /// A loopback port nobody listens on: bind to port 0, read the port, close.
    private func freeLoopbackPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HarnessError("socket() failed") }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { throw HarnessError("bind() failed") }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        guard named == 0 else { throw HarnessError("getsockname() failed") }
        return Int(UInt16(bigEndian: addr.sin_port))
    }
}
