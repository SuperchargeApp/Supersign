import Foundation
import Supersign
import ConcurrencyExtras

final class SupersignCLIAuthDelegate: TwoFactorAuthDelegate {
    func fetchCode() async -> String? {
        try? await Console.prompt("Code: ")
    }
}

actor SupersignCLIDelegate: IntegratedInstallerDelegate {
    public enum Error: Swift.Error {
        case decompressionFailed
        case compressionFailed
    }

    init() {}

    private let updateTask = LockIsolated<Task<Void, Never>?>(nil)

    nonisolated func setPresentedMessage(_ message: IntegratedInstaller.Message?) {
        let text: String
        switch message {
        case .pairDevice:
            text = "Please tap 'trust' on your device..."
        case .unlockDevice:
            text = "Please unlock your device..."
        case nil:
            text = "Continuing..."
        }
        print("\n\(text)", terminator: "")
        fflush(stdoutSafe)
    }

    var prevStage: String?
    var prevProgress: String?

    private func _installerDidUpdate(toStage stage: String, progress: Double?) {
        let progString: String?
        if let progress = progress {
            let progInt = Int(progress * 100)
            if progInt < 10 {
                progString = "  \(progInt)%"
            } else if progInt < 100 {
                progString = " \(progInt)%"
            } else {
                progString = "\(progInt)%"
            }
        } else {
            progString = nil
        }

        defer {
            prevStage = stage
            prevProgress = progString
        }

        if stage != prevStage {
            if let progString = progString {
                print("\n[\(stage)] \(progString)", terminator: "")
                fflush(stdoutSafe)
            } else {
                print("\n[\(stage)] ...", terminator: "")
                fflush(stdoutSafe)
            }
        } else if progString != prevProgress {
            if let progString = progString {
                print("\r[\(stage)] \(progString)", terminator: "")
                fflush(stdoutSafe)
            } else {
                print("\r[\(stage)]", terminator: "")
                fflush(stdoutSafe)
            }
        }
    }

    nonisolated func installerDidUpdate(toStage stage: String, progress: Double?) {
        updateTask.withValue { task in
            task = Task { [prev = task] in
                await prev?.value
                await _installerDidUpdate(toStage: stage, progress: progress)
            }
        }
    }

    func confirmRevocation(of certificates: [DeveloperServicesCertificate]) async -> Bool {
        print("\nThe following certificates must be revoked:")
        print(
            certificates.map {
                "- \($0.attributes!.name!) (expires \($0.attributes!.expirationDate!.formatted(date: .abbreviated, time: .shortened)))"
            }.joined(separator: "\n")
        )
        do {
            return try await Console.confirm("Continue?")
        } catch {
            return false
        }
    }

    // TODO: Use `powershell Compress-Archive` and `powershell Expand-Archive` on Windows

    func decompress(
        ipa: URL,
        in directory: URL,
        progress: @escaping (Double?) -> Void
    ) async throws {
        progress(nil)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        unzip.arguments = ["unzip", "-q", ipa.path, "-d", directory.path]
        try await unzip.launchAndWait()
        guard unzip.terminationStatus == 0 else {
            throw Error.decompressionFailed
        }
    }

    func compress(
        payloadDir: URL,
        progress: @escaping (Double?) -> Void
    ) async throws -> URL {
        progress(nil)

        let dest = payloadDir.deletingLastPathComponent().appendingPathComponent("app.ipa")

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        zip.currentDirectoryURL = payloadDir.deletingLastPathComponent()
        zip.arguments = ["zip", "-yqru0", dest.path, "Payload"]
        try await zip.launchAndWait()
        guard zip.terminationStatus == 0 else { throw Error.compressionFailed }

        return dest
    }
}

extension Process {
    fileprivate func launchAndWait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try self.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            Task.detached { self.waitUntilExit() }
        }
    }
}
