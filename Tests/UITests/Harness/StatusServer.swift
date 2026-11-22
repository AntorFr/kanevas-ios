import Darwin
import Foundation

/// A tiny loopback HTTP server answering every request with a chosen status and a short HTML body, so a test
/// can make "Kanevas" answer 503 or 404, then change its mind. Lives in the test process (a simulator process).
final class StatusServer {
    private(set) var port = 0
    private var listenFD: Int32 = -1
    private let lock = NSLock()
    private var status = 200
    private var body = ""

    /// Answers `status` with `body` from now on.
    func respond(status: Int, body: String) {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.body = body
    }

    private func current() -> (Int, String) {
        lock.lock(); defer { lock.unlock() }
        return (status, body)
    }

    func start(status: Int, body: String) throws {
        respond(status: status, body: body)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HarnessError("socket() failed") }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { close(fd); throw HarnessError("bind/listen failed") }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        port = Int(UInt16(bigEndian: addr.sin_port))
        listenFD = fd
        DispatchQueue.global().async { [weak self] in self?.acceptLoop(fd) }
    }

    func stop() {
        if listenFD >= 0 { shutdown(listenFD, SHUT_RDWR); close(listenFD); listenFD = -1 }
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { return }
            DispatchQueue.global().async { [weak self] in self?.serve(client) }
        }
    }

    private func serve(_ client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 8192)
        _ = read(client, &buffer, buffer.count)
        let (code, text) = current()
        let html = "<html><body><h1>\(text)</h1></body></html>"
        let head = "HTTP/1.1 \(code) X\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n"
        let out = Array((head + html).utf8)
        _ = write(client, out, out.count)
    }
}
