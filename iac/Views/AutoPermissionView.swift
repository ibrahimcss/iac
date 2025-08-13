//
//  AutoPermissionView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI

struct AutoPermissionView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var hasTriedPermission = false
    
    var body: some View {
        Group {
            if bluetoothManager.permissionManager.permissionStatus == .allowed {
                MainControlView()
            } else {
                requestView
            }
        }
        .onAppear {
            requestPermissionIfNeeded()
        }
        .onChange(of: bluetoothManager.permissionManager.permissionStatus) { newStatus in
            print("📱 İzin durumu değişti: \(newStatus)")
            if newStatus == .notDetermined && !hasTriedPermission {
                requestPermissionIfNeeded()
            }
        }
    }
    
    private var requestView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("IAC Control")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("BLE cihazları ile iletişim için Bluetooth gerekli")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Durum göstergesi
            statusIndicator
            
            Spacer()
            
            // Eğer izin reddedildiyse ayarlar butonu
            if bluetoothManager.permissionManager.permissionStatus == .denied {
                Button("Ayarlara Git") {
                    bluetoothManager.permissionManager.openAppSettings()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch bluetoothManager.permissionManager.permissionStatus {
        case .notDetermined:
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Bluetooth izni isteniyor...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
        case .denied:
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text("Bluetooth İzni Reddedildi")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("Ayarlar'dan manuel olarak izin verebilirsiniz")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
        case .restricted:
            VStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text("Bluetooth Kısıtlı")
                    .font(.headline)
                    .foregroundColor(.orange)
                #if targetEnvironment(simulator)
                Text("iOS Simulator'da Bluetooth desteklenmez")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                #else
                Text("Cihaz ayarlarını kontrol edin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                #endif
            }
            
        case .unknown:
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Bluetooth durumu kontrol ediliyor...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
        case .allowed:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Bluetooth İzni Verildi")
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
    }
    
    private func requestPermissionIfNeeded() {
        #if !targetEnvironment(simulator)
        if bluetoothManager.permissionManager.permissionStatus == .notDetermined && !hasTriedPermission {
            hasTriedPermission = true
            print("🔄 Otomatik izin isteme başlatılıyor...")
            
            // 1 saniye bekleyip izin iste
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                bluetoothManager.permissionManager.requestBluetoothPermission()
            }
        }
        #endif
    }
}

#Preview {
    AutoPermissionView()
}