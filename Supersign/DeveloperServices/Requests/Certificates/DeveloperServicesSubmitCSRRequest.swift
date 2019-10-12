//
//  DeveloperServicesSubmitCSRRequest.swift
//  Supercharge
//
//  Created by Kabir Oberai on 24/07/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

public class DeveloperServicesSubmitCSRRequest: DeveloperServicesPlatformRequest {

    public struct Response: Decodable {
        public let certRequest: DeveloperServicesCSRResponse
    }
    public typealias Value = DeveloperServicesCSRResponse

    public let platform: DeveloperServicesPlatform
    public let teamID: DeveloperServicesTeam.ID
    public let csr: CSR
    public let machineName: String
    public let machineID: String

    var subAction: String { return "submitDevelopmentCSR" }
    var subParameters: [String: Any] {
        let csrString = String(data: csr.data, encoding: .utf8) ?? ""
        return [
            "teamId": teamID.rawValue,
            "csrContent": csrString,
            "machineId": machineID,
            "machineName": machineName
        ]
    }

    public func parse(_ response: Response, completion: @escaping (Result<Value, Error>) -> Void) {
        completion(.success(response.certRequest))
    }

    public init(
        platform: DeveloperServicesPlatform,
        teamID: DeveloperServicesTeam.ID,
        csr: CSR,
        machineName: String,
        machineID: String
    ) {
        self.platform = platform
        self.teamID = teamID
        self.csr = csr
        self.machineName = machineName
        self.machineID = machineID
    }

}
