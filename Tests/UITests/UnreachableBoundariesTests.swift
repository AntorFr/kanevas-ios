import Darwin
import XCTest

/// B-6 / P-4 / E-2, written from the need only: the HTTP boundaries of "Kanevas unreachable" (5xx yes, 4xx no),
/// a connection cut with no answer, Retry reloading the *last* address (not the base one), and the main frame only.
final class UnreachableBoundariesTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Per-path routes: path -> (status, html body). `cutPaths` accept the connection and close it unanswered.
    private final class RouteServer {
        private(set) var port = 0
        private var fd: Int32 = -1
        private let lock = NSLock()
        private var routes: [String: (Int, String)] = [:]
        private var cut = Set<String>()

        func set(_ path: String, _ status: Int, _ html: String) { lock.lock(); routes[path] = (status, html); cut.remove(path); lock.unlock() }
        func cutConnection(_ path: String) { lock.lock(); cut.insert(path); lock.unlock() }

        func start() throws {
            let s = socket(AF_INET, SOCK_STREAM, 0)
            guard s >= 0 else { throw HarnessError("socket() failed") }
            var yes: Int32 = 1
            setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            addr.sin_port = 0
            let ok = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard ok == 0, listen(s, 16) == 0 else { close(s); throw HarnessError("bind/listen failed") }
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &len) }
            }
            port = Int(UInt16(bigEndian: addr.sin_port))
            fd = s
            DispatchQueue.global().async { [weak self] in
                while true {
                    let c = accept(s, nil, nil)
                    if c < 0 { return }
                    DispatchQueue.global().async { self?.serve(c) }
                }
            }
        }

        func stop() { if fd >= 0 { shutdown(fd, SHUT_RDWR); close(fd); fd = -1 } }

        private func serve(_ client: Int32) {
            defer { close(client) }
            var buf = [UInt8](repeating: 0, count: 8192)
            let n = read(client, &buf, buf.count)
            guard n > 0 else { return }
            let request = String(decoding: buf[0..<n], as: UTF8.self)
            let parts = request.split(separator: " ", maxSplits: 2)
            let path = parts.count > 1 ? String(parts[1]) : "/"
            lock.lock(); let route = routes[path]; let cutIt = cut.contains(path); lock.unlock()
            if cutIt { return }
            let (code, html) = route ?? (404, "<html><body>none</body></html>")
            let head = "HTTP/1.1 \(code) X\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n"
            let out = Array((head + html).utf8)
            _ = write(client, out, out.count)
        }
    }

    private func makeServer() throws -> RouteServer {
        let server = RouteServer()
        try server.start()
        addTeardownBlock { server.stop() }
        return server
    }

    private func launch(_ server: RouteServer) -> XCUIApplication {
        let app = XCUIApplication()
        app.launch(pointingAt: URL(string: "http://127.0.0.1:\(server.port)")!)
        return app
    }

    private func page(_ text: String) -> String { "<html><body><h1>\(text)</h1></body></html>" }

    // MARK: HTTP boundaries

    /// E-2. Fails if the 5xx range is cut short at its lower bound (500) or its upper bound (599).
    func testLowestAndHighest5xxShowE2() throws {
        for status in [500, 599] {
            let server = try makeServer()
            server.set("/", status, page("Status \(status) body"))
            let app = launch(server)
            XCTAssertTrue(app.staticTexts["unreachableMessage"].waitForExistence(timeout: 30), "no E-2 for \(status)")
            XCTAssertTrue(app.buttons["retryButton"].exists, "no Retry for \(status)")
            XCTAssertFalse(app.webViews.staticTexts["Status \(status) body"].exists, "page visible under E-2 for \(status)")
            app.terminate()
        }
    }

    /// E-1 (not E-2). Fails if any 4xx (401 and 403 included, the sign-in and permission cases) is treated as unreachable.
    func testClientErrors401403499StayOnKanevasPage() throws {
        for status in [401, 403, 499] {
            let server = try makeServer()
            server.set("/", status, page("Own page \(status)"))
            let app = launch(server)
            XCTAssertTrue(app.webViews.staticTexts["Own page \(status)"].waitForExistence(timeout: 30), "page \(status) not shown")
            XCTAssertFalse(app.staticTexts["unreachableMessage"].exists, "E-2 wrongly shown for \(status)")
            XCTAssertFalse(app.buttons["retryButton"].exists)
            app.terminate()
        }
    }

    // MARK: failure without HTTP answer

    /// E-2 (P-4). Fails if a connection accepted then closed with no answer leaves a blank page.
    func testConnectionCutWithoutAnswerShowsE2() throws {
        let server = try makeServer()
        server.cutConnection("/")
        let app = launch(server)
        XCTAssertTrue(app.staticTexts["unreachableMessage"].waitForExistence(timeout: 30), "E-2 not shown")
        XCTAssertEqual(app.staticTexts["unreachableMessage"].label, "Kanevas is unreachable")
        XCTAssertEqual(app.buttons["retryButton"].label, "Retry")
        attachScreenshot("P-4-connection-cut", of: app)
    }

    // MARK: Retry reloads the last address

    /// E-2 then E-1. Fails if Retry reloads the base address instead of the address that failed
    /// (the home page would show, not the recovered page), or if the page stays covered.
    func testRetryReloadsTheAddressThatFailedNotTheBaseOne() throws {
        let server = try makeServer()
        server.set("/", 200, "<html><body><h1>Home page</h1><a href=\"/fiche\">Open sheet</a></body></html>")
        server.set("/fiche", 503, page("Sheet broken"))
        let app = launch(server)
        let link = app.webViews.links["Open sheet"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "home page not loaded")
        link.tap()
        XCTAssertTrue(app.staticTexts["unreachableMessage"].waitForExistence(timeout: 30), "E-2 not shown for the 503 sheet")
        attachScreenshot("P-4-503-on-sheet", of: app)

        server.set("/fiche", 200, page("Sheet recovered"))
        app.buttons["retryButton"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Sheet recovered"].waitForExistence(timeout: 30), "Retry did not load the failed address")
        XCTAssertFalse(app.buttons["retryButton"].exists, "E-2 still up after a successful Retry")
        XCTAssertFalse(app.webViews.staticTexts["Home page"].exists, "Retry reloaded the base address")
    }

    // MARK: the main frame only

    /// E-1 (not E-2). Fails if a 5xx on a sub-resource (an image) of a healthy page shows E-2: only the main frame counts.
    func testSubresource500DoesNotShowE2() throws {
        let server = try makeServer()
        server.set("/", 200, "<html><body><h1>Healthy page</h1><img src=\"/pic.png\" width=\"10\" height=\"10\"></body></html>")
        server.set("/pic.png", 500, "x")
        let app = launch(server)
        XCTAssertTrue(app.webViews.staticTexts["Healthy page"].waitForExistence(timeout: 30), "page not shown")
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.staticTexts["unreachableMessage"].exists, "E-2 wrongly shown for a failing image")
        XCTAssertTrue(app.webViews.staticTexts["Healthy page"].exists)
    }
}
