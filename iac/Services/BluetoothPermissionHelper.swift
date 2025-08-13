//
//  BluetoothPermissionHelper.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import Foundation
import CoreBluetooth
import CoreLocation
import UIKit

class BluetoothPermissionHelper: NSObject {
    static let shared = BluetoothPermissionHelper()
    
    private var locationManager: CLLocationManager?
    private var tempCentralManager: CBCentralManager?
    
    override init() {
        super.init()
    }
    
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        print("🔄 Tüm Bluetooth izinleri isteniyor...")
        
        // İlk olarak konum iznini iste (Bluetooth tarama için gerekli)
        requestLocationPermission { [weak self] locationGranted in
            print("📍 Konum izni: \(locationGranted)")
            
            // Ardından Bluetooth iznini iste
            self?.requestBluetoothPermission { bluetoothGranted in
                print("📶 Bluetooth izni: \(bluetoothGranted)")
                completion(locationGranted && bluetoothGranted)
            }
        }
    }
    
    private func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        locationManager = CLLocationManager()
        
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            // İzin iste
            DispatchQueue.main.async {
                self.locationManager?.requestWhenInUseAuthorization()
            }
            
            // 3 saniye bekle ve sonucu kontrol et
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let status = CLLocationManager.authorizationStatus()
                completion(status == .authorizedWhenInUse || status == .authorizedAlways)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func requestBluetoothPermission(completion: @escaping (Bool) -> Void) {
        switch CBManager.authorization {
        case .allowedAlways:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            // CBCentralManager oluştur - bu otomatik olarak izin isteyecek
            tempCentralManager = CBCentralManager(delegate: self, queue: nil)
            
            // 3 saniye bekle ve sonucu kontrol et
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let granted = CBManager.authorization == .allowedAlways
                completion(granted)
                self.tempCentralManager = nil
            }
        @unknown default:
            completion(false)
        }
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func checkAllPermissions() -> (bluetooth: Bool, location: Bool) {
        let bluetoothGranted = CBManager.authorization == .allowedAlways
        let locationGranted = CLLocationManager.authorizationStatus() == .authorizedWhenInUse || 
                             CLLocationManager.authorizationStatus() == .authorizedAlways
        
        print("📋 İzin durumu - Bluetooth: \(bluetoothGranted), Konum: \(locationGranted)")
        return (bluetooth: bluetoothGranted, location: locationGranted)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothPermissionHelper: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔄 Permission Helper - Bluetooth durumu: \(central.state.rawValue)")
        print("📋 Permission Helper - Authorization: \(CBManager.authorization.rawValue)")
    }
}
