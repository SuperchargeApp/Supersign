#if os(Linux)

import Foundation
import CSupersette

public struct SupersetteADIProvider: RawADIProvider {
    @MainActor private static var loadTask: Task<Void, Error>?

    public let directory: URL
    public let httpClient: HTTPClientProtocol

    public init(
        configDirectory: URL,
        httpClientFactory: HTTPClientFactory = defaultHTTPClientFactory
    ) {
        self.directory = configDirectory
        self.httpClient = httpClientFactory.makeClient()
    }

    private func _loadADI(id: UUID) async throws {
        let dir = self.directory
        let libDir = dir.appending(path: "libs")
        if !libDir.dirExists {
            let tmp = dir.appending(path: "tmp")
            try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

            let applemusic = tmp.appending(path: "applemusic.apk")
            if !applemusic.exists {
                print("Downloading libraries...")
                let url = URL(string: "https://apps.mzstatic.com/content/android-apple-music-apk/applemusic.apk")!
                let data = try await httpClient.makeRequest(HTTPRequest(url: url)).body!
                try data.write(to: applemusic)
            }

            #if arch(arm64)
            let arch = "arm64-v8a"
            #elseif arch(x86_64)
            let arch = "x86_64"
            #else
            #error("Unsupported architecture")
            #endif
            let archDir = "lib/\(arch)"

            let proc = Process()
            proc.executableURL = URL(filePath: "/usr/bin/unzip")
            proc.arguments = [
                "-q",
                applemusic.path(),
                "\(archDir)/libCoreADI.so",
                "\(archDir)/libstoreservicescore.so",
                "-d", tmp.path()
            ]
            try proc.run()
            proc.waitUntilExit()
            try FileManager.default.moveItem(
                at: tmp.appending(path: archDir),
                to: libDir
            )
            try? FileManager.default.removeItem(at: tmp)
        }

        supersette_Load(strdup(libDir.path()))

        let rawID = id.uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
        try check(supersette_SetAndroidID(rawID, UInt32(rawID.utf8.count)))

        let adi = dir.appending(path: "adi")
        try? FileManager.default.createDirectory(at: adi, withIntermediateDirectories: true)
        try check(supersette_SetProvisioningPath(adi.path()))
    }

    @MainActor private func loadADI(id: UUID) async throws {
        if let loadTask = Self.loadTask {
            try await loadTask.value
            return
        }
        let loadTask = Task { try await _loadADI(id: id) }
        Self.loadTask = loadTask
        try await loadTask.value
    }

    public func clientInfo() async throws -> String {
        """
        <MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>
        """
    }

    public func startProvisioning(spim: Data, userID: UUID) async throws -> (any RawADIProvisioningSession, Data) {
        try await loadADI(id: userID)

        var sessionID: UInt32 = 0
        var cpimBytes: UnsafeMutableRawPointer?
        var cpimLen: UInt32 = 0
        try check(spim.withUnsafeBytes { spimBytes in
            supersette_ProvisioningStart(
                UInt64(bitPattern: -2),
                spimBytes.baseAddress!, UInt32(spimBytes.count),
                &cpimBytes, &cpimLen,
                &sessionID
            )
        })
        let data = Data(UnsafeRawBufferPointer(start: cpimBytes, count: Int(cpimLen)))
        _ = cpimBytes.map { supersette_Dispose($0) }
        return (
            ADISession(
                sessionID: sessionID,
                adiDirectory: directory.appending(path: "adi")
            ),
            data
        )
    }

    private struct ADISession: RawADIProvisioningSession {
        let sessionID: UInt32
        let adiDirectory: URL

        func endProvisioning(routingInfo: UInt64, ptm: Data, tk: Data) async throws -> Data {
            try check(ptm.withUnsafeBytes { ptmBuf in
                tk.withUnsafeBytes { tkBuf in
                    supersette_ProvisioningEnd(
                        sessionID,
                        ptmBuf.baseAddress!, UInt32(ptmBuf.count),
                        tkBuf.baseAddress!, UInt32(tkBuf.count)
                    )
                }
            })
            let file = adiDirectory.appending(path: "adi.pb")
            return try Data(contentsOf: file)
        }
    }

    public func requestOTP(
        userID: UUID,
        routingInfo: inout UInt64,
        provisioningInfo: Data
    ) async throws -> (machineID: Data, otp: Data) {
        try await loadADI(id: userID)

        var midBytes: UnsafeMutableRawPointer?
        var midLen: UInt32 = 0
        var otpBytes: UnsafeMutableRawPointer?
        var otpLen: UInt32 = 0
        
        let adiDirectory = directory.appending(path: "adi")
        try? FileManager.default.createDirectory(at: adiDirectory, withIntermediateDirectories: true)
        try provisioningInfo.write(to: adiDirectory.appending(path: "adi.pb"))

        try check(supersette_OTPRequest(
            UInt64(bitPattern: -2),
            &midBytes, &midLen,
            &otpBytes, &otpLen
        ))

        let mid = Data(UnsafeRawBufferPointer(start: midBytes, count: Int(midLen)))
        let otp = Data(UnsafeRawBufferPointer(start: otpBytes, count: Int(otpLen)))

        _ = midBytes.map { supersette_Dispose($0) }
        _ = otpBytes.map { supersette_Dispose($0) }

        return (machineID: mid, otp: otp)
    }
}

private func check(_ adiStatus: Int32) throws {
    guard adiStatus == 0 else {
        throw ADIError(code: Int(adiStatus))
    }
}

#endif