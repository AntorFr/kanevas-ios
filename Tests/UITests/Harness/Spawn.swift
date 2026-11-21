import Foundation

/// Child processes from a test running in the iOS simulator. `Process` is unavailable on iOS, but the simulator
/// is a macOS process tree, so `posix_spawn` works there.
enum Spawn {
    /// Runs `path` with `args` (without argv[0]) in its own process group, output to `log`. Returns the pid.
    static func run(_ path: String, _ args: [String], env: [String: String], log: String) throws -> pid_t {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 1, log, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        posix_spawn_file_actions_adddup2(&actions, 1, 2)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)

        let argv = ([path] + args).map { strdup($0) } + [nil]
        let envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }

        var pid: pid_t = 0
        let code = posix_spawn(&pid, path, &actions, &attributes, argv, envp)
        guard code == 0 else { throw HarnessError("posix_spawn \(path) failed (errno \(code))") }
        return pid
    }

    /// Runs a command to the end; returns its stdout and exit code.
    static func capture(_ path: String, _ args: [String], env: [String: String]) throws -> (out: String, code: Int32) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("spawn-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appendingPathComponent("out").path
        let pid = try run(path, args, env: env, log: log)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let out = (try? String(contentsOfFile: log)) ?? ""
        let code: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        return (out, code)
    }
}
