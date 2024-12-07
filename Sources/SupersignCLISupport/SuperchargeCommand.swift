import Foundation
import Supersign
import ArgumentParser

struct InstallSuperchargeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install Supercharge"
    )

    @Option(name: .shortAndLong) var udid: String?

    func run() async throws {
        guard let app = SupersignCLI.config.superchargeApp else {
            throw Console.Error("This copy of Supersign is not configured to install Supercharge.")
        }

        let auth = try AuthToken.saved()
        let username = auth.appleID
        let credentials: IntegratedInstaller.Credentials = .token(auth.dsToken)

        let client = try await ConnectionOptions(udid: udid, search: .usb).client()

        print("Installing to device: \(client.deviceName) (udid: \(client.udid))")

        let installDelegate = SupersignCLIDelegate(preferredTeam: nil)
        let installer = IntegratedInstaller(
            udid: client.udid,
            lookupMode: .only(.usb),
            appleID: username,
            credentials: credentials,
            configureDevice: true,
            storage: SupersignCLI.config.storage,
            delegate: installDelegate
        )

        do {
            let bundleID = try await installer.install(app: app)
            print("\nSuccessfully installed!")
            if let file = ProcessInfo.processInfo.environment["SUPERSIGN_METADATA_FILE"] {
                do {
                    try Data("\(bundleID)\n".utf8).write(to: URL(fileURLWithPath: file))
                } catch {
                    print("warning: Failed to write metadata to SUPERSIGN_METADATA_FILE: \(error)")
                }
            }
        } catch {
            print("\nFailed :(")
            print("Error: \(error)")
            return
        }
    }
}

struct SuperchargeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "supercharge",
        abstract: "Configure/install Supercharge",
        subcommands: [InstallSuperchargeCommand.self],
        defaultSubcommand: InstallSuperchargeCommand.self
    )
}
