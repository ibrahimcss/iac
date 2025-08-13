//
//  PermissionManager.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import Foundation
import CoreBluetooth
import SwiftUI

class PermissionManager: NSObject, ObservableObject {
    @Published var showingPermissionAlert = false
    @Published var permissionStatus: BluetoothPermissionStatus = .unknown
    
    enum BluetoothPermissionStatus {
        case unknown
        case notDetermined
        case denied
        case allowed
        case restricted
        
        var description: String {
            switch self {
            case .unknown:
                return "Bilinmiyor"
            case .notDetermined:
                return "Henüz sorulmadı"
            case .denied:
                return "Reddedildi"
            case .allowed:
                return "İzin verildi"
            case .restricted:
                return "Kısıtlı"
            }
        }
    }
    
    func checkBluetoothPermission() {
        switch CBManager.authorization {
        case .notDetermined:
            permissionStatus = .notDetermined
            print("📋 Bluetooth izni henüz istenmedi")
        case .denied:
            permissionStatus = .denied
            showingPermissionAlert = true
            print("❌ Bluetooth izni reddedildi")
        case .allowedAlways:
            permissionStatus = .allowed
            print("✅ Bluetooth izni verildi")
        case .restricted:
            permissionStatus = .restricted
            showingPermissionAlert = true
            print("⚠️ Bluetooth izni kısıtlı")
        @unknown default:
            permissionStatus = .unknown
            print("❓ Bilinmeyen izin durumu")
        }
    }
    
    private var tempCentralManager: CBCentralManager?
    
    func requestBluetoothPermission() {
        print("🔄 Bluetooth izni isteme işlemi başlatılıyor...")
        
        // iOS Simulator kontrolü
        #if targetEnvironment(simulator)
        print("⚠️ iOS Simulator'da Bluetooth desteklenmez")
        permissionStatus = .restricted
        showingPermissionAlert = true
        return
        #endif
        
        guard CBManager.authorization == .notDetermined else {
            print("📋 İzin durumu zaten belirlenmiş: \(CBManager.authorization.rawValue)")
            checkBluetoothPermission()
            return
        }
        
        print("🔄 Bluetooth izni isteniyor...")
        // Bu geçici manager izin dialog'unu tetikleyecek - delay ile XPC hatasını önle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.tempCentralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension PermissionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔄 Permission Manager - Bluetooth durumu değişti: \(central.state.rawValue)")
        
        DispatchQueue.main.async {
            self.checkBluetoothPermission()
        }
        
        // Geçici manager'ı temizle
        if tempCentralManager === central {
            tempCentralManager = nil
        }
    }
}

// MARK: - Permission Alert View
struct PermissionAlertView: ViewModifier {
    @ObservedObject var permissionManager: PermissionManager
    
    func body(content: Content) -> some View {
        content
            .alert("Bluetooth İzni Gerekli", isPresented: $permissionManager.showingPermissionAlert) {
                Button("Ayarlara Git") {
                    permissionManager.openAppSettings()
                }
                Button("İptal", role: .cancel) {
                    // Dialog'u kapat
                }
            } message: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bu uygulama BLE cihazları ile iletişim kurmak için Bluetooth izni gerektirir.")
                    
                    Text("Ayarlar → Gizlilik & Güvenlik → Bluetooth → IAC Control yolunu izleyerek izin verebilirsiniz.")
                        .font(.caption)
                }
            }
    }
}

extension View {
    func bluetoothPermissionAlert(_ permissionManager: PermissionManager) -> some View {
        modifier(PermissionAlertView(permissionManager: permissionManager))
    }
}