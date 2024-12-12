import Foundation
import Supersign
import ArgumentParser

struct AuthOperation {
    var username: String?
    var password: String?
    var logoutFromExisting: Bool

    func run() async throws {
        if let token = try? AuthToken.saved() {
            if logoutFromExisting {
                try AuthToken.clear()
            } else {
                print("Logged in as \(token.appleID)")
                return
            }
        }

        guard let username = username ?? Console.prompt("Apple ID: "), !username.isEmpty else {
            throw Console.Error("A non-empty Apple ID is required.")
        }
        guard let password = password ?? Console.getPassword("Password: "), !password.isEmpty else {
            throw Console.Error("A non-empty password is required.")
        }

        let deviceInfo = try DeviceInfo.fetch()

        let provider = try ADIDataProvider.adiProvider(
            deviceInfo: deviceInfo,
            storage: SupersignCLI.config.storage
        )
        let authDelegate = SupersignCLIAuthDelegate()
        let manager = try DeveloperServicesLoginManager(
            deviceInfo: deviceInfo,
            anisetteProvider: provider
        )
        let token = try await manager.logIn(
            withUsername: username,
            password: password,
            twoFactorDelegate: authDelegate
        )
        let fullToken = AuthToken(appleID: username, dsToken: token)
        try fullToken.save()
        print("Logged in")
    }
}

struct AuthLoginCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Log in to Apple Developer Services"
    )

    @Option(name: [.short, .long], help: "Apple ID") var username: String?
    @Option(name: [.short, .long]) var password: String?

    func run() async throws {
        try await AuthOperation(
            username: username,
            password: password,
            logoutFromExisting: true
        ).run()
    }
}

struct AuthLogoutCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Log out of Apple Developer Services"
    )

    @Flag(
        name: [.short, .customLong("reset-2fa")],
        help: ArgumentHelp(
            "Reset 2-factor authentication data",
            discussion: """
            This resets the "pseudo-device" that Supersign presents itself as \
            when authenticating with Apple.

            Effectively, this means you will be prompted to complete 2-factor \
            authentication again the next time you log in.
            """
        )
    ) var reset2FA = false

    func run() async throws {
        if (try? AuthToken.saved()) != nil {
            try AuthToken.clear()
            print("Logged out")
        } else {
            print("Already logged out")
        }

        if reset2FA {
            try ADIDataProvider.adiProvider(
                deviceInfo: .fetch(),
                storage: SupersignCLI.config.storage
            )
            .resetProvisioning()
            print("Forgot device")
        }
    }
}

struct AuthStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Get Apple Developer Services auth status"
    )

    func run() async throws {
        if let token = try? AuthToken.saved() {
            print("Logged in: \(token.appleID)")
        } else {
            print("Logged out")
        }
    }
}

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Authenticate with Apple Developer Services",
        subcommands: [
            AuthLoginCommand.self,
            AuthLogoutCommand.self,
            AuthStatusCommand.self,
        ],
        defaultSubcommand: AuthLoginCommand.self
    )
}

extension DeviceInfo {
    static func fetch() throws -> Self {
        guard let deviceInfo = DeviceInfo.current() else {
            throw Console.Error("Could not fetch client info.")
        }
        return deviceInfo
    }
}