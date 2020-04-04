//
//  SignerImpl.swift
//  Supersign
//
//  Created by Kabir Oberai on 10/10/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

extension signer_t: CLinkedListElement {}

/// a wrapper around signer_t
public struct SignerImpl {

    private static let signingQueue = DispatchQueue(
        label: "com.kabiroberai.Supercharge.signing-queue",
        attributes: .concurrent
    )

    public enum Error: LocalizedError {
        case notFound
        case badFilePath
        case signer(String?)

        public var errorDescription: String? {
            switch self {
            case .notFound:
                return NSLocalizedString(
                    "signer_impl.error.not_found", value: "No signer implementation found", comment: ""
                )
            case .badFilePath:
                return NSLocalizedString(
                    "signer_impl.error.bad_file_path", value: "A bad file path was provided", comment: ""
                )
            case .signer(let error?):
                return error
            case .signer(nil):
                return NSLocalizedString(
                    "signer_impl.error.unknown", value: "An unknown signing error occurred", comment: ""
                )
            }
        }
    }

    public let name: String
    private let sign: sign_func
    private let analyze: analyze_func

    private init(signer: signer_t) {
        name = String(cString: signer.name)
        sign = signer.sign
        analyze = signer.analyze
    }

    private static func all() -> AnySequence<SignerImpl> {
        .init(CLinkedList(first: signer_list).lazy.map(SignerImpl.init))
    }

    public static func first() throws -> SignerImpl {
        try all().makeIterator().next().orThrow(Error.notFound)
    }

    private func _sign(
        app: URL,
        certificate: Certificate,
        privateKey: PrivateKey,
        entitlementMapping: [URL: Entitlements],
        progress: @escaping (Double) -> Void
    ) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let entsArray: [entitlements_data_t] = try entitlementMapping.map { url, ents in
            try url.withUnsafeFileSystemRepresentation { bundlePath in
                guard let bundlePath = bundlePath else { throw Error.badFilePath }
                return try encoder.encode(ents).withUnsafeBytes { bytes in
                    let bound = bytes.bindMemory(to: Int8.self)
                    return entitlements_data_t(
                        bundle_path: bundlePath, data: bound.baseAddress!, len: bound.count
                    )
                }
            }
        }
        try entsArray.withUnsafeBufferPointer { ents in
            try certificate.data().withUnsafeBytes { certBytes in
                try privateKey.data.withUnsafeBytes { privBytes in
                    let certBound = certBytes.bindMemory(to: Int8.self)
                    let privBound = privBytes.bindMemory(to: Int8.self)

                    var exception: UnsafeMutablePointer<Int8>?
                    defer { exception.map { free($0) } }

                    guard sign(
                        app.path,
                        certBound.baseAddress!,
                        certBound.count,
                        privBound.baseAddress!,
                        privBound.count,
                        ents.baseAddress!,
                        ents.count,
                        progress,
                        &exception
                    ) == 0 else {
                        throw Error.signer(exception.map { String(cString: $0) })
                    }
                }
            }
        }
    }

    public func sign(
        app: URL,
        certificate: Certificate,
        privateKey: PrivateKey,
        entitlementMapping: [URL: Entitlements],
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<(), Swift.Error>) -> Void
    ) {
        Self.signingQueue.async {
            do {
                try self._sign(
                    app: app,
                    certificate: certificate,
                    privateKey: privateKey,
                    entitlementMapping: entitlementMapping,
                    progress: progress
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func analyze(executable: URL) throws -> Data {
        try executable.withUnsafeFileSystemRepresentation { (path: UnsafePointer<Int8>?) -> Data in
            var exception: UnsafeMutablePointer<Int8>?
            defer { exception.map { free($0) } }
            var len = 0
            guard let out = analyze(path!, &len, &exception) else {
                throw Error.signer(exception.map { String(cString: $0) })
            }
            defer { free(out) }
            return Data(bytes: out, count: len)
        }
    }

}
