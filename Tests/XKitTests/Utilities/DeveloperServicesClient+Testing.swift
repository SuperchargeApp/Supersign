//
//  DeveloperServicesTestClient.swift
//  XKitTests
//
//  Created by Kabir Oberai on 06/11/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation
import XCTest
@testable import XKit

#if false

extension TCPAnisetteDataProvider {

    static func test() -> TCPAnisetteDataProvider {
        TCPAnisetteDataProvider(localPort: 4321)
    }

}

extension NetcatAnisetteDataProvider {

    static func test() -> NetcatAnisetteDataProvider {
        NetcatAnisetteDataProvider(localPort: 4322, deviceInfo: Config.current.deviceInfo)
    }

}

#endif

extension ADIDataProvider {

    static func test(storage: KeyValueStorage) throws -> ADIDataProvider {
        try adiProvider(deviceInfo: Config.current.deviceInfo, storage: storage)
    }

}

extension GrandSlamClient {

    static func test(storage: KeyValueStorage) throws -> GrandSlamClient {
        try GrandSlamClient(
            deviceInfo: Config.current.deviceInfo,
            anisetteProvider: ADIDataProvider.test(storage: storage)
        )
    }

}

extension DeveloperServicesClient {

    static func test(storage: KeyValueStorage) throws -> DeveloperServicesClient {
        try DeveloperServicesClient(
            loginToken: Config.current.appleID.token,
            deviceInfo: Config.current.deviceInfo,
            anisetteProvider: ADIDataProvider.test(storage: storage)
        )
    }

}
