//
//  PermissionStatusView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import CoreBluetooth
import CoreLocation

struct PermissionStatusView: View {
    @State private var bluetoothPermission: Bool = false
    @State private var locationPermission: Bool = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("İzin Durumu")
                .font(.headline)
            
            VStack(spacing: 12) {
                PermissionRow(
                    title: "Bluetooth",
                    icon: "antenna.radiowaves.left.and.right",
                    isGranted: bluetoothPermission,
                    description: bluetoothPermission ? "İzin verildi" : "İzin gerekli"
                )
                
                PermissionRow(
                    title: "Konum",
                    icon: "location",
                    isGranted: locationPermission,
                    description: locationPermission ? "İzin verildi" : "BLE tarama için gerekli"
                )
            }
            
            if !bluetoothPermission || !locationPermission {
                VStack(spacing: 12) {
                    Button("İzinleri İste") {
                        requestPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Ayarlara Git") {
                        BluetoothPermissionHelper.shared.openAppSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text("Debug Bilgisi:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CBManager.authorization: \(CBManager.authorization.rawValue)")
                Text("CLLocationManager.authorizationStatus: \(CLLocationManager.authorizationStatus().rawValue)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            checkPermissions()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func checkPermissions() {
        let permissions = BluetoothPermissionHelper.shared.checkAllPermissions()
        bluetoothPermission = permissions.bluetooth
        locationPermission = permissions.location
    }
    
    private func requestPermissions() {
        BluetoothPermissionHelper.shared.requestAllPermissions { success in
            DispatchQueue.main.async {
                self.checkPermissions()
            }
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkPermissions()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    PermissionStatusView()
}