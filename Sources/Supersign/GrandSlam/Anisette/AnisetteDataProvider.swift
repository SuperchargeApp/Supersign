//
//  AnisetteDataProvider.swift
//  Supersign
//
//  Created by Kabir Oberai on 19/11/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

public protocol AnisetteDataProvider: Sendable {
    // This is a suggestion and not a requirement.
    func resetProvisioning() async
    func provisioningData() -> ProvisioningData?

    func fetchAnisetteData() async throws -> AnisetteData
}

public struct ProvisioningData: Hashable, Codable, Sendable {
    public var localUserUID: UUID
    public var routingInfo: UInt64
    public var adiPb: Data
}

extension AnisetteDataProvider {
    public func provisioningData() -> ProvisioningData? { nil }
    public func setProvisioningData(_ data: ProvisioningData) {}
}
