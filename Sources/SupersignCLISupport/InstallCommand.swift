import Foundation
import Supersign
import SwiftyMobileDevice
import ArgumentParser

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install an ipa file to your device"
    )

    @Option(name: .shortAndLong) var account: String?
    @Option(
        name: .shortAndLong,
        help: "Preferred team ID"
    ) var team: String?
    @OptionGroup @FromArguments var client: ConnectionManager.Client

    @Argument(
        help: "The path to a custom app/ipa to install"
    ) var path: String

    func run() async throws {
        let token = try account.flatMap(AuthToken.init(string:)) ?? AuthToken.saved()

        let username = token.appleID
        let credentials: IntegratedInstaller.Credentials = .token(token.dsToken)

        print("Installing to device: \(client.deviceName) (udid: \(client.udid))")

        let installDelegate = SupersignCLIDelegate(preferredTeam: team.map(DeveloperServicesTeam.ID.init))
        let installer = IntegratedInstaller(
            udid: client.udid,
            lookupMode: .only(client.connectionType),
            appleID: username,
            credentials: credentials,
            configureDevice: false,
            storage: SupersignCLI.config.storage,
            delegate: installDelegate
        )

        do {
            try await installer.install(app: URL(fileURLWithPath: path))
            print("\nSuccessfully installed!")
        } catch {
            print("\nFailed :(")
            print("Error: \(error)")
        }
    }
}
