//
//  DeviceSelectionView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import CoreBluetooth

struct DeviceSelectionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Bağlantı durumu
                ConnectionStatusCard(connectionState: bluetoothManager.connectionState)
                
                // Cihaz listesi
                if bluetoothManager.isScanning {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Cihazlar aranıyor...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if bluetoothManager.discoveredDevices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bluetooth.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Cihaz Bulunamadı")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Bluetooth cihazınızın açık ve eşleştirilebilir modda olduğundan emin olun.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(bluetoothManager.discoveredDevices) { device in
                        DeviceRowView(device: device) {
                            bluetoothManager.connect(to: device)
                        }
                    }
                }
                
                Spacer()
                
                // Kontrol butonları
                HStack(spacing: 16) {
                    Button(action: {
                        if bluetoothManager.isScanning {
                            bluetoothManager.stopScanning()
                        } else {
                            bluetoothManager.startScanning()
                        }
                    }) {
                        HStack {
                            Image(systemName: bluetoothManager.isScanning ? "stop.circle" : "arrow.clockwise")
                            Text(bluetoothManager.isScanning ? "Aramayı Durdur" : "Cihaz Ara")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(bluetoothManager.connectionState == .connecting)
                    
                    if bluetoothManager.connectedDevice != nil {
                        Button("Bağlı Cihaza Git") {
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Cihaz Seçimi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            if bluetoothManager.discoveredDevices.isEmpty {
                bluetoothManager.startScanning()
            }
        }
    }
}

struct ConnectionStatusCard: View {
    let connectionState: ConnectionState
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .animation(.easeInOut(duration: 0.3), value: connectionState.description)
            
            Text(connectionState.description)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var statusColor: Color {
        switch connectionState {
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
}

struct DeviceRowView: View {
    let device: BluetoothDevice
    let onConnect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("RSSI: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Bağlan") {
                    onConnect()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DeviceSelectionView(
        bluetoothManager: BluetoothManager(),
        isPresented: .constant(true)
    )
}
