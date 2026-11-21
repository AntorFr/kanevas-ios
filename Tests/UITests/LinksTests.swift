import XCTest
import Darwin

/// P-5 / B-5: an external link leaves the shell. The page is served by this test (loopback), not by Kanevas.
final class LinksTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testExternalLinkOpensInSystemAndLeavesViewOnPage() throws {
        let server = try LoopbackPageServer()
        addTeardownBlock { server.stop() }

        let app = XCUIApplication()
        app.launchArguments += ["-KANEVAS_FAKE_OPENER"]
        app.launch(pointingAt: server.baseURL)

        let external = app.webViews.links["Lien externe"]
        XCTAssertTrue(external.waitForExistence(timeout: 30), "test page not shown")
        external.tap()

        let count = app.staticTexts["externalOpenCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        let opened = NSPredicate(format: "label == '1'")
        wait(for: [expectation(for: opened, evaluatedWith: count)], timeout: 10)
        XCTAssertEqual(app.staticTexts["lastExternalURL"].label, "https://example.org/")
        XCTAssertTrue(app.webViews.links["Lien externe"].exists, "the web view left its page")
        attachScreenshot("P-5-external-link", of: app)
    }

    func testBlankLinkToBaseHostLoadsInView() throws {
        let server = try LoopbackPageServer()
        addTeardownBlock { server.stop() }

        let app = XCUIApplication()
        app.launchArguments += ["-KANEVAS_FAKE_OPENER"]
        app.launch(pointingAt: server.baseURL)

        let blank = app.webViews.links["Lien nouvelle fenêtre"]
        XCTAssertTrue(blank.waitForExistence(timeout: 30))
        blank.tap()
        XCTAssertTrue(app.webViews.staticTexts["Page suivante"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["externalOpenCount"].label, "0")
    }
}

/// Minimal HTTP server on a loopback port chosen by the system.
private final class LoopbackPageServer {
    let baseURL: URL
    private let fd: Int32
    private var running = true

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 8) == 0 else { throw POSIXError(.EADDRINUSE) }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        let port = UInt16(bigEndian: addr.sin_port)
        self.fd = fd
        baseURL = URL(string: "http://127.0.0.1:\(port)/")!
        let listener = fd
        DispatchQueue.global().async { [weak self] in
            while let self, self.running {
                let client = accept(listener, nil, nil)
                if client < 0 { break }
                self.serve(client)
            }
        }
    }

    func stop() {
        running = false
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }

    private func serve(_ client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let n = read(client, &buffer, buffer.count)
        let request = n > 0 ? String(decoding: buffer[0..<n], as: UTF8.self) : ""
        let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let body: String
        if path.hasPrefix("/next") {
            body = "<html><body style=\"font-size:32px\"><h1>Page suivante</h1></body></html>"
        } else {
            body = """
            <html><head><meta name="viewport" content="width=device-width"></head><body style="font-size:32px">
            <p><a href="https://example.org/">Lien externe</a></p>
            <p><a href="\(baseURL.absoluteString)next" target="_blank">Lien nouvelle fenêtre</a></p>
            </body></html>
            """
        }
        let head = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        let data = Array((head + body).utf8)
        _ = data.withUnsafeBufferPointer { write(client, $0.baseAddress, data.count) }
    }
}
