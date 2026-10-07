import Foundation

struct ScriptResult: Equatable, Sendable {
    var stdout: String
    var stderr: String
    var status: Int32
}

enum AppleScriptRunner {
    static func run(_ source: String) async -> ScriptResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runSync(source))
            }
        }
    }

    static func isDenied(_ result: ScriptResult) -> Bool {
        let text = (result.stderr + "\n" + result.stdout).lowercased()
        return text.contains("not authorized")
            || text.contains("-1743")
            || text.contains("erraeeventnotpermitted")
    }

    /// Reads both pipes before waiting so a large artwork payload cannot fill the buffer and stall.
    private static func runSync(_ source: String) -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            return ScriptResult(stdout: "", stderr: error.localizedDescription, status: -1)
        }

        var stdoutData = Data()
        var stderrData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        process.waitUntilExit()

        return ScriptResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            status: process.terminationStatus
        )
    }
}
