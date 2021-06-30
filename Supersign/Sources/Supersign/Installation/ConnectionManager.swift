//
//  ConnectionManager.swift
//  Supercharge Installer
//
//  Created by Kabir Oberai on 19/06/20.
//  Copyright © 2020 Kabir Oberai. All rights reserved.
//

import Foundation
import SwiftyMobileDevice

public protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, clientsDidChangeFrom oldValue: [ConnectionManager.Client])
}

public class ConnectionManager {

    fileprivate struct ConnectionKey: Hashable, Equatable, Comparable {
        let udid: String
        let connectionType: USBMux.ConnectionType

        private static func precedence(for connectionType: USBMux.ConnectionType) -> Int {
            switch connectionType {
            case .network: return 0
            case .usb: return 1
            }
        }

        static func < (lhs: ConnectionManager.ConnectionKey, rhs: ConnectionManager.ConnectionKey) -> Bool {
            lhs.udid < rhs.udid ||
                (lhs.udid == rhs.udid
                    && precedence(for: lhs.connectionType) < precedence(for: rhs.connectionType))
        }
    }

    fileprivate class ConnectionValue {
        let device: Device
        let deviceName: String

        init(key: ConnectionKey) throws {
            let deviceConnectionType: Device.ConnectionType
            switch key.connectionType {
            case .network:
                deviceConnectionType = .network
            case .usb:
                deviceConnectionType = .usb
            }
            let device = try Device(udid: key.udid, lookupMode: .only(deviceConnectionType))
            let client = try LockdownClient(
                device: device,
                label: LockdownClient.installerLabel,
                performHandshake: false
            )
            let deviceName = try client.deviceName()

            self.device = device
            self.deviceName = deviceName
        }
    }

    public class Client {
        private let key: ConnectionKey
        private let value: ConnectionValue

        public var udid: String { key.udid }
        public var connectionType: USBMux.ConnectionType { key.connectionType }
        public var device: Device { value.device }
        public var deviceName: String { value.deviceName }

        fileprivate init(key: ConnectionKey, value: ConnectionValue) {
            self.key = key
            self.value = value
        }
    }

    private var clientsDict: [ConnectionKey: ConnectionValue] = [:] {
        didSet {
            clientsDidChange()
        }
    }

    public private(set) var clients: [Client] = [] {
        didSet {
            delegate?.connectionManager(self, clientsDidChangeFrom: oldValue)
        }
    }

    private var token: USBMux.SubscriptionToken?

    public weak var delegate: ConnectionManagerDelegate?

    private func clientsDidChange() {
        clients = clientsDict.sorted { $0.0 < $1.0 }.map(Client.init)
    }

    public init(delegate: ConnectionManagerDelegate? = nil) throws {
        self.delegate = delegate
        self.token = try USBMux.subscribe { [weak self] event in
            guard let self = self else { return }
            self.handleEvent(event)
        }
    }

    private func handleEvent(_ event: USBMux.Event) {
        let udid = event.device.udid
        let key = ConnectionKey(udid: udid, connectionType: event.device.connectionType)
        switch event.kind {
        case .removed:
            clientsDict[key] = nil
        case .paired:
            return
        case .added:
            clientsDict[key] = try? ConnectionValue(key: key)
        }
    }

    deinit { try? token.map(USBMux.unsubscribe(withToken:)) }

}
