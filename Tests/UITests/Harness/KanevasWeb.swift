import Foundation
import XCTest

/// The pinned web archive of Kanevas (AD-web-epingle-1 to 3): `Scripts/fetch-kanevas-web.sh` downloads, checks and
/// unpacks it outside the repository tree; the stub is its `lancer-bouchon.mjs`. Nothing of Kanevas is committed here.
enum KanevasWeb {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)   // Tests/UITests/Harness/KanevasWeb.swift
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    /// The version pinned in `KANEVAS_WEB_VERSION` (read at run time).
    static func pinnedVersion() throws -> String {
        let file = repoRoot.appendingPathComponent("KANEVAS_WEB_VERSION")
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let line = text.split(separator: "\n").first.map({ $0.trimmingCharacters(in: .whitespaces) }), !line.isEmpty
        else { throw HarnessError("KANEVAS_WEB_VERSION is missing or empty") }
        return line
    }

    private static var cached: (path: String, version: String)?

    /// The unpacked archive folder; fetched once per run. A script failure (exit 1 or 3) is repeated verbatim.
    static func path() throws -> String {
        if let cached { return cached.path }
        let script = repoRoot.appendingPathComponent("Scripts/fetch-kanevas-web.sh").path
        let env = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin", "HOME": NSHomeDirectory(),
                   "TMPDIR": NSTemporaryDirectory()]
        let result = try Spawn.capture("/bin/sh", [script], env: env)
        let last = result.out.split(separator: "\n").last.map(String.init) ?? ""
        guard result.code == 0, !last.isEmpty else {
            throw HarnessError("fetch-kanevas-web.sh failed (exit \(result.code)): \(result.out.suffix(1500))")
        }
        let pinned = try pinnedVersion()
        let version = try archiveVersion(at: last)
        guard version == pinned.drop(while: { $0 == "v" }) else {
            throw HarnessError("archive VERSION \(version) differs from KANEVAS_WEB_VERSION \(pinned)")
        }
        cached = (last, version)
        // Trace at the head of the suite.
        NSLog("Kanevas web archive: VERSION \(version) (KANEVAS_WEB_VERSION \(pinned)) at \(last)")
        return last
    }

    /// The `VERSION` file of the unpacked archive, without a leading `v`.
    static func archiveVersion(at folder: String) throws -> String {
        guard let text = try? String(contentsOfFile: folder + "/VERSION", encoding: .utf8) else {
            throw HarnessError("no VERSION file in the archive at \(folder)")
        }
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(line.drop(while: { $0 == "v" }))
    }
}
