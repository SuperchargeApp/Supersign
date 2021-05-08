//
//  GrandSlamLookupManager.swift
//  Supersign
//
//  Created by Kabir Oberai on 19/11/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

class GrandSlamLookupManager {

    private static let lookupURL = URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!

    private struct Response: Decodable {
        let urls: GrandSlamEndpoints
    }

    private let decoder = PropertyListDecoder()
    private var endpoints: GrandSlamEndpoints?

    let httpClient: HTTPClientProtocol
    let deviceInfo: DeviceInfo
    init(deviceInfo: DeviceInfo, httpFactory: HTTPClientFactory.Type = defaultHTTPClientFactory) {
        self.deviceInfo = deviceInfo
        self.httpClient = httpFactory.shared.makeClient()
    }

    private func performLookup(completion: @escaping (Result<GrandSlamEndpoints, Error>) -> Void) {
        /* {
            "X-Apple-I-Locale" = "en_IN";
            "X-Apple-I-TimeZone" = "Asia/Kolkata";
            "X-Apple-I-TimeZone-Offset" = 19800;
            "X-MMe-Client-Info" = "<MacBookPro11,5> <Mac OS X;10.14.6;18G103> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
            "X-MMe-Country" = IN;
            "X-Mme-Device-Id" = "[REDACTED]";
        } */
        var request = HTTPRequest(url: Self.lookupURL)
        request.headers = [
            DeviceInfo.clientInfoKey: deviceInfo.clientInfo.clientString,
            DeviceInfo.deviceIDKey: deviceInfo.deviceID,
            AnisetteData.iLocaleKey: Locale.current.identifier,
            AnisetteData.timeZoneKey: TimeZone.current.identifier,
            "X-Apple-I-TimeZone-Offset": "\(TimeZone.current.secondsFromGMT())"
        ]
        request.headers["X-MMe-Country"] = Locale.current.regionCode

        httpClient.makeRequest(request) { result in
            guard let resp = result.get(withErrorHandler: completion) else { return }
            completion(Result {
                try self.decoder.decode(Response.self, from: resp.body ?? .init()).urls
            })
        }
    }

    private func fetchEndpoints(completion: @escaping (Result<GrandSlamEndpoints, Error>) -> Void) {
        if let endpoints = endpoints {
            return completion(.success(endpoints))
        }
        performLookup { result in
            if case let .success(endpoints) = result {
                self.endpoints = endpoints
            }
            completion(result)
        }
    }

    func fetchURL(
        forEndpoint endpoint: GrandSlamEndpoint,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        fetchEndpoints { result in
            completion(result.map { URL(string: $0[keyPath: endpoint])! })
        }
    }

}