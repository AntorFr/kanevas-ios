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
    /// The port is free, chosen per test (`KANEVAS_STUB_PORT` forces one), never a possibly stale default.
    func startStub(port: Int? = nil) throws -> StubServer {
        let forced = ProcessInfo.processInfo.environment["KANEVAS_STUB_PORT"].flatMap { Int($0) }
        guard let chosen = port ?? forced ?? StubServer.freePort() else {
            throw HarnessError("no free local TCP port for the stub")
        }
        let stub = StubServer(port: chosen)
        addTeardownBlock { stub.stop() }
        try stub.start()
        return stub
    }

    /// One short entry per request of the stub log (pino JSON lines): "req-1 GET / 302".
    private func requestSummary(_ log: String) -> String {
        var urls: [String: String] = [:], order: [String] = []
        var out: [String] = []
        for line in log.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = json["reqId"] as? String else { continue }
            if let req = json["req"] as? [String: Any] {
                urls[id] = "\(req["method"] ?? "?") \(req["url"] ?? "?")"; order.append(id)
            } else if let res = json["res"] as? [String: Any] {
                out.append("\(urls[id] ?? id) -> \(res["statusCode"] ?? "?")")
            }
        }
        return out.isEmpty ? "none (log: \(log.suffix(200).debugDescription))" : out.joined(separator: "; ")
    }

    private func attachText(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for `element` (inside the app's web view); on failure attaches the stub log, the answer of
    /// `GET /connexion-bouchon` seen from the test process, the accessibility hierarchy and a screenshot, and
    /// fails with the cause: stub not answering, page served differently, or page served but element not found.
    func expectInWebView(_ element: XCUIElement, of app: XCUIApplication, stub: StubServer,
                         expecting pageText: String, timeout: TimeInterval = 30,
                         file: StaticString = #filePath, line: UInt = #line) {
        if element.waitForExistence(timeout: timeout) { return }
        let answer = StubServer.fetch(stub.baseURL.appendingPathComponent("connexion-bouchon"))
        let log = stub.logContents
        let hierarchy = app.debugDescription
        let cause: String
        if let answer = answer {
            if answer.status == 200 && answer.body.contains(pageText) {
                cause = "page served by the stub (HTTP 200, contains \"\(pageText)\") but not found in the app (app state \(app.state.rawValue), web views: \(app.webViews.count))"
            } else {
                cause = "stub answers differently from expected: HTTP \(answer.status), body starts \(answer.body.prefix(200).debugDescription)"
            }
        } else {
            cause = "stub does not answer on \(stub.baseURL) (running: \(stub.isRunning))"
        }
        attachText("stub.log", log)
        attachText("GET /connexion-bouchon",
                   answer.map { "status \($0.status)\n\($0.body)" } ?? "no answer from \(stub.baseURL)")
        attachText("app.debugDescription", hierarchy)
        attachScreenshot("failure", of: app)
        XCTFail("\"\(pageText)\" not shown: \(cause); stub requests: \(requestSummary(log)); web view hierarchy: \(app.webViews.firstMatch.debugDescription.prefix(1500))",
                file: file, line: line)
    }
}
