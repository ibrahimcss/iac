//
//  Device.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import Foundation
import CoreBluetooth

// MARK: - Device Model
struct BluetoothDevice: Identifiable, Equatable {
    let id = UUID()
    let peripheral: CBPeripheral
    let name: String
    let rssi: NSNumber
    var isConnected: Bool = false
    
    init(peripheral: CBPeripheral, rssi: NSNumber) {
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Bilinmeyen Cihaz"
        self.rssi = rssi
    }
    
    static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}

// MARK: - Module Status Model
struct ModuleStatus: Identifiable {
    let id = UUID()
    let moduleId: String
    var name: String
    var isActive: Bool = false
    var hasError: Bool = false
    var errorCode: Int = 0
    var lastUpdate: Date = Date()
    
    init(moduleId: String, name: String) {
        self.moduleId = moduleId
        self.name = name
    }
}

// MARK: - Connection State
enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case error(String)
    
    var description: String {
        switch self {
        case .disconnected:
            return "Bağlantı Yok"
        case .scanning:
            return "Cihaz Aranıyor..."
        case .connecting:
            return "Bağlanıyor..."
        case .connected:
            return "Bağlı"
        case .error(let message):
            return "Hata: \(message)"
        }
    }
    
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.scanning, .scanning),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}