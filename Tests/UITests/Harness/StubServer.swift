import Foundation
import XCTest

/// Failure of the harness itself (clone, node, stub start): a bench problem, not a red product test.
struct HarnessError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The Kanevas stub (`KANEVAS_STUB=1`, node only) on a chosen host and port, startable and stoppable at any
/// moment of a test, also after the app has launched (AD-socle-2). The clone of Kanevas is read-only: the
/// database and the session secret live in a temporary folder.
final class StubServer {
    let host: String
    let port: Int
    private(set) var pid: pid_t = 0
    private let workDir: URL

    init(host: String = "127.0.0.1", port: Int = StubServer.defaultPort) {
        self.host = host
        self.port = port
        self.workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanevas-stub-\(UUID().uuidString)")
    }

    /// Port the tests aim at; `KANEVAS_STUB_PORT` overrides it.
    static var defaultPort: Int {
        Int(ProcessInfo.processInfo.environment["KANEVAS_STUB_PORT"] ?? "") ?? 3055
    }

    var baseURL: URL { URL(string: "http://\(host):\(port)")! }
    var isRunning: Bool { pid != 0 }

    /// Starts the stub and returns once `/connexion-bouchon` answers.
    func start(timeout: TimeInterval = 90) throws {
        guard pid == 0 else { return }
        let source = try KanevasSource.path()
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let env: [String: String] = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory(),
            "KANEVAS_STUB": "1",
            "PORT": String(port),
            "DB_PATH": workDir.appendingPathComponent("kanevas.db").path,
            "SESSION_SECRET": "kanevas-ios-harness-secret",
            "NODE_ENV": "development",
        ]
        // The clone is read-only: `tsx` runs the TypeScript sources, no build writes into it.
        pid = try Spawn.run("/bin/sh",
                            ["-c", "cd \"$1\" && exec node --import tsx src/server.ts", "sh", source],
                            env: env,
                            log: workDir.appendingPathComponent("stub.log").path)
        do {
            try waitUntilReady(timeout: timeout)
        } catch {
            let log = (try? String(contentsOf: workDir.appendingPathComponent("stub.log"))) ?? ""
            stop()
            throw HarnessError("\(error)\nstub log:\n\(log.suffix(2000))")
        }
    }

    func stop() {
        guard pid != 0 else { return }
        kill(-pid, SIGTERM)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        pid = 0
        try? FileManager.default.removeItem(at: workDir)
    }

    /// True when the stub answers its sign-in page.
    func isAnswering() -> Bool {
        Self.fetch(baseURL.appendingPathComponent("connexion-bouchon"))?.status == 200
    }

    private func waitUntilReady(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isAnswering() { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        throw HarnessError("stub did not answer on \(baseURL) within \(Int(timeout)) s")
    }

    /// Synchronous GET; nil when nothing answers.
    static func fetch(_ url: URL) -> (status: Int, body: String)? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        let done = DispatchSemaphore(value: 0)
        var result: (Int, String)?
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                result = (http.statusCode, String(data: data ?? Data(), encoding: .utf8) ?? "")
            }
            done.signal()
        }.resume()
        done.wait()
        return result
    }
}
