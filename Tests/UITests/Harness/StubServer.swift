import Foundation
import XCTest

/// Failure of the harness itself (archive fetch, node, stub start): a bench problem, not a red product test.
struct HarnessError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The Kanevas stub (`KANEVAS_STUB=1`, node only) on a chosen host and port, startable and stoppable at any
/// moment of a test, also after the app has launched (AD-socle-2). The archive of Kanevas is read-only: the
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

    /// A TCP port nobody listens on right now (the kernel picks it), so a stub left over from a cut run
    /// on the default port cannot answer in place of the test's own. Nil when none could be obtained.
    static func freePort() -> Int? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        guard named == 0 else { return nil }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    var baseURL: URL { URL(string: "http://\(host):\(port)")! }
    var isRunning: Bool { pid != 0 }

    /// Starts the stub and returns once `/connexion-bouchon` answers.
    func start(timeout: TimeInterval = 90) throws {
        guard pid == 0 else { return }
        // A stub left over from a cut run would answer in place of ours: fail cleanly instead of testing it.
        if isAnswering() {
            throw HarnessError("port \(port) is already served by another process (a stub left from an interrupted run?): free it or set KANEVAS_STUB_PORT")
        }
        let source = try KanevasWeb.path()
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        // The archive's launcher (`node lancer-bouchon.mjs [--port N] [--data DIR]`) takes the port and the database
        // folder as options; the session secret is read by the server from the environment (inherited by the launcher).
        let env: [String: String] = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory(),
            // Fresh per stub: a session cookie left in the simulator's web view data store by an earlier test or run
            // (cookies ignore the port) no longer verifies, so the app starts signed out, as the tests assume.
            "SESSION_SECRET": "kanevas-ios-harness-\(UUID().uuidString)",
        ]
        pid = try Spawn.run("/bin/sh",
                            ["-c", "cd \"$1\" && exec node lancer-bouchon.mjs --port \"$2\" --data \"$3\"", "sh",
                             source, String(port), workDir.path],
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

    /// Output of the stub process so far (`stub.log`); empty when it never started.
    var logContents: String {
        (try? String(contentsOf: workDir.appendingPathComponent("stub.log"))) ?? ""
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
