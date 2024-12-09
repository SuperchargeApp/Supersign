import Foundation
import Supersign
import ArgumentParser

public enum SupersignCLI {
    public struct Configuration: Sendable {
        public let superchargeApp: URL?
        public let storage: KeyValueStorage

        public init(
            superchargeApp: URL?,
            storage: KeyValueStorage
        ) {
            self.superchargeApp = superchargeApp
            self.storage = storage
        }
    }

    private static nonisolated(unsafe) var _config: Configuration!
    static var config: Configuration { _config }

    public static func run(configuration: Configuration, arguments: [String]? = nil) async throws {
        _config = configuration
        do {
            var command = try SupersignCommand.parseAsRoot(arguments)
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            SupersignCommand.exit(withError: error)
        }
    }
}

struct SupersignCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "supersign",
        abstract: "The Supersign command line tool",
        subcommands: [
            AuthCommand.self,
            DSCommand.self,
            DevicesCommand.self,
            InstallCommand.self,
            UninstallCommand.self,
            DevCommand.self,
            // no Supercharge support... yet...
            // SuperchargeCommand.self,
            RunCommand.self,
        ]
    )
}
