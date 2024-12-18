//
//  DeveloperServicesAssignAppGroupsOperation.swift
//  Supersign
//
//  Created by Kabir Oberai on 14/10/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

import Foundation

public struct DeveloperServicesAssignAppGroupsOperation: DeveloperServicesOperation {

    public let context: SigningContext
    public let groupIDs: [DeveloperServicesAppGroup.GroupID]
    public let appID: DeveloperServicesAppID
    public init(context: SigningContext, groupIDs: [DeveloperServicesAppGroup.GroupID], appID: DeveloperServicesAppID) {
        self.context = context
        self.groupIDs = groupIDs
        self.appID = appID
    }

    private func upsertAppGroup(
        _ groupID: DeveloperServicesAppGroup.GroupID,
        existingGroups: [String: DeveloperServicesAppGroup],
        appID: DeveloperServicesAppID
    ) async throws -> DeveloperServicesAppGroup.GroupID {
        let sanitized = ProvisioningIdentifiers.sanitize(groupID: groupID)
        let group: DeveloperServicesAppGroup
        if let existingGroup = existingGroups[sanitized] {
            group = existingGroup
        } else {
            let groupID = ProvisioningIdentifiers.groupID(fromSanitized: sanitized, context: context)
            let name = ProvisioningIdentifiers.groupName(fromSanitized: sanitized)
            let request = DeveloperServicesAddAppGroupRequest(
                platform: context.platform, teamID: context.teamID, name: name, groupID: groupID
            )
            group = try await context.client.send(request)
        }

        _ = try await context.client.send(DeveloperServicesAssignAppGroupRequest(
            platform: context.platform, teamID: context.teamID, appIDID: appID.id, groupID: group.id
        ))

        return group.groupID
    }

    public func perform() async throws -> [DeveloperServicesAppGroup.GroupID] {
        let existing = try await context.client.send(DeveloperServicesListAppGroupsRequest(
            platform: context.platform, teamID: context.teamID
        ))
        let sanitized = existing.map { (ProvisioningIdentifiers.sanitize(groupID: $0.groupID), $0) }
        let dict = Dictionary(sanitized, uniquingKeysWith: { $1 })
        return try await withThrowingTaskGroup(of: DeveloperServicesAppGroup.GroupID.self) { group in
            for groupID in groupIDs {
                group.addTask {
                    try await upsertAppGroup(groupID, existingGroups: dict, appID: appID)
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }

}
