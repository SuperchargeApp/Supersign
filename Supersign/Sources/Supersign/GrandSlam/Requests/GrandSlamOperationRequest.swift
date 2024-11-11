//
//  GrandSlamOperationRequest.swift
//  Supersign
//
//  Created by Kabir Oberai on 19/11/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

struct GrandSlamOperationError: Error, LocalizedError {
    let code: Int
    let message: String

    var errorDescription: String? {
        "\(message) (\(code))"
    }
}

struct GrandSlamOperationResponseStatusWrapper: Decodable {
    struct Status: Decodable {
        let errorCode: Int
        let errorMessage: String

        private enum CodingKeys: String, CodingKey {
            case errorCode = "ec"
            case errorMessage = "em"
        }
    }
    let status: Status

    private enum CodingKeys: String, CodingKey {
        case status = "Status"
    }
}

struct GrandSlamOperationResponseWrapper<T: Decodable>: Decodable {
    let value: T
    private enum CodingKeys: String, CodingKey {
        case value = "Response"
    }
}

struct GrandSlamOperationDecoder<T: Decodable>: GrandSlamDataDecoder {
    static func decode(data: Data) throws -> T {
        let decoder = PropertyListDecoder()
        let status = try decoder.decode(
            GrandSlamOperationResponseWrapper<GrandSlamOperationResponseStatusWrapper>.self,
            from: data
        ).value.status
        guard status.errorCode == 0 else {
            throw GrandSlamOperationError(code: status.errorCode, message: status.errorMessage)
        }
        return try decoder.decode(GrandSlamOperationResponseWrapper<T>.self, from: data).value
    }
}

protocol GrandSlamOperationRequest: GrandSlamRequest
    where Decoder == GrandSlamOperationDecoder<Value> {
    associatedtype Value: Decodable

    static var operation: String { get }

    var username: String { get }
    var parameters: [String: Any] { get }
}

extension GrandSlamOperationRequest {

    static var endpoint: GrandSlamEndpoint { \.gsService }

    func configure(request: inout HTTPRequest, deviceInfo: DeviceInfo, anisetteData: AnisetteData) {
        request.headers["Accept"] = "*/*"
        request.headers["User-Agent"] = deviceInfo.clientInfo.userAgent
        // as of November 2024 it appears that using Mac clientInfo for auth causes
        // secondaryAuth to fail in some cases. using PC instead causes GSA to immediately
        // prompt for 2fa on o=complete, no secondaryAuth call needed.
        request.headers[DeviceInfo.clientInfoKey] = "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKitWin/1 (com.apple.iCloud/7.21)>"
    }

    func method(deviceInfo: DeviceInfo, anisetteData: AnisetteData) -> GrandSlamMethod {
        var clientData: [String: Any] = [
            "bootstrap": true,
            "icscrec": true,
            "pbe": false,
            "prkgen": true,
            "svct": "iCloud",
            "loc": Locale.current.identifier
        ]
        clientData.merge(deviceInfo.dictionary) { _, b in b }
        clientData.merge(anisetteData.dictionary) { _, b in b }

        var request: [String: Any] = [
            "o": Self.operation,
            "u": username,
            "cpd": clientData
        ]
        request.merge(parameters) { _, b in b }

        let body = [
            "Header": ["Version": "1.0.1"],
            "Request": request
        ]
        return .post(body)
    }

}
