//
//  GrandSlamTwoFactorRequest.swift
//  XKit
//
//  Created by Kabir Oberai on 20/11/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

protocol GrandSlamTwoFactorRequest: GrandSlamRequest {
    var loginData: GrandSlamLoginData { get }
    var extraHeaders: [String: String] { get }
}

extension GrandSlamTwoFactorRequest {

    var extraHeaders: [String: String] { [:] }

    func configure(request: inout HTTPRequest, deviceInfo: DeviceInfo, anisetteData: AnisetteData) {
        request.headerFields[.accept] = "application/x-buddyml"
        request.headerFields[.contentType] = "application/x-plist"
        request.headerFields[.init("X-Apple-App-Info")!] = "com.apple.gs.xcode.auth"
        request.headerFields[.init(DeviceInfo.xcodeVersionKey)!] = DeviceInfo.xcodeVersion
        request.headerFields[.init("X-Apple-Identity-Token")!] = loginData.identityToken
        anisetteData.dictionary.forEach { request.headerFields[.init($0)!] = $1 }
        extraHeaders.forEach { request.headerFields[.init($0)!] = $1 }
    }

    func method(deviceInfo: DeviceInfo, anisetteData: AnisetteData) -> GrandSlamMethod {
        .get
    }

}
