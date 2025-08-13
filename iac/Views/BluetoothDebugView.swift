//
//  BluetoothDebugView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import CoreBluetooth

struct BluetoothDebugView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isShowingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Bluetooth Durumu") {
                    HStack {
                        Text("Mevcut Durum")
                        Spacer()
                        Text(bluetoothManager.connectionState.description)
                            .foregroundColor(statusColor)
                    }
                    
                    HStack {
                        Text("Bulunan Cihaz Sayısı")
                        Spacer()
                        Text("\(bluetoothManager.discoveredDevices.count)")
                    }
                    
                    HStack {
                        Text("Tarama Aktif")
                        Spacer()
                        Text(bluetoothManager.isScanning ? "Evet" : "Hayır")
                            .foregroundColor(bluetoothManager.isScanning ? .green : .secondary)
                    }
                }
                
                Section("İzinler") {
                    Button("İzin Durumunu Kontrol Et") {
                        checkBluetoothPermissions()
                    }
                    
                    Button("Ayarlara Git") {
                        openSettings()
                    }
                }
                
                Section("Test İşlemleri") {
                    Button("Manuel Tarama Başlat") {
                        bluetoothManager.startScanning()
                    }
                    .disabled(bluetoothManager.isScanning)
                    
                    Button("Taramayı Durdur") {
                        bluetoothManager.stopScanning()
                    }
                    .disabled(!bluetoothManager.isScanning)
                    
                    Button("Cihaz Listesini Temizle") {
                        bluetoothManager.discoveredDevices.removeAll()
                    }
                }
                
                if !bluetoothManager.discoveredDevices.isEmpty {
                    Section("Bulunan Cihazlar") {
                        ForEach(bluetoothManager.discoveredDevices) { device in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text("UUID: \(device.peripheral.identifier.uuidString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("RSSI: \(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Bluetooth Debug")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Bluetooth İzni", isPresented: $isShowingPermissionAlert) {
                Button("Ayarlara Git") {
                    openSettings()
                }
                Button("İptal", role: .cancel) { }
            } message: {
                Text("Bluetooth kullanımı için izin gerekli. Lütfen ayarlardan izin verin.")
            }
        }
    }
    
    private var statusColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private func checkBluetoothPermissions() {
        // iOS 13+ için CBManager authorization durumunu kontrol et
        switch CBManager.authorization {
        case .allowedAlways:
            print("✅ Bluetooth izni verilmiş (Always)")
        case .denied:
            print("❌ Bluetooth izni reddedilmiş")
            isShowingPermissionAlert = true
        case .restricted:
            print("⚠️ Bluetooth izni kısıtlı")
            isShowingPermissionAlert = true
        case .notDetermined:
            print("❓ Bluetooth izni belirlenmemiş")
            isShowingPermissionAlert = true
        @unknown default:
            print("❓ Bilinmeyen Bluetooth izin durumu")
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    BluetoothDebugView(bluetoothManager: BluetoothManager())
}