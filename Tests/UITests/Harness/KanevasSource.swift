import Foundation

/// Where the read-only clone of AntorFr/kanevas is: `KANEVAS_SRC`, else `Scripts/fetch-kanevas.sh` clones it
/// outside the repository tree. Nothing of Kanevas is copied into this repository.
enum KanevasSource {
    static func path() throws -> String {
        if let set = ProcessInfo.processInfo.environment["KANEVAS_SRC"], !set.isEmpty {
            guard FileManager.default.fileExists(atPath: set + "/src/server.ts") else {
                throw HarnessError("KANEVAS_SRC=\(set) is not a Kanevas clone (src/server.ts missing)")
            }
            guard FileManager.default.fileExists(atPath: set + "/dist/public/index.html") else {
                throw HarnessError("KANEVAS_SRC=\(set) has no web build (dist/public/index.html missing): run `npm run build` in it")
            }
            return set
        }
        let repoRoot = URL(fileURLWithPath: #filePath)   // Tests/UITests/Harness/KanevasSource.swift
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let script = repoRoot.appendingPathComponent("Scripts/fetch-kanevas.sh").path
        let env = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin", "HOME": NSHomeDirectory(),
                   "TMPDIR": NSTemporaryDirectory()]
        let result = try Spawn.capture("/bin/sh", [script], env: env)
        let last = result.out.split(separator: "\n").last.map(String.init) ?? ""
        guard result.code == 0, !last.isEmpty else {
            throw HarnessError("fetch-kanevas.sh failed (exit \(result.code)): \(result.out.suffix(1500))")
        }
        return last
    }
}
