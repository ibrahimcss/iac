//
//  SimpleConnectionView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI

struct SimpleConnectionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var showingDeviceList = false
    @State private var connectionAttempted = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Bağlantı durumu kartı
            connectionStatusCard
            
            // Ana aksiyon butonu
            mainActionButton
            
            // Bulunan cihazlar listesi (varsa)
            if !bluetoothManager.discoveredDevices.isEmpty && showingDeviceList {
                devicesList
            }
        }
        .padding()
        .onAppear {
            initializeBluetooth()
        }
    }
    
    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bluetooth Durumu")
                        .font(.headline)
                    
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let device = bluetoothManager.connectedDevice {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bağlı Cihaz:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(device.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Button("Bağlantıyı Kes") {
                        bluetoothManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var mainActionButton: some View {
        VStack(spacing: 12) {
            if bluetoothManager.connectedDevice != nil {
                // Bağlıysa ana uygulamaya geç butonu
                Button(action: {
                    // Ana uygulama zaten görünür durumda
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Bağlantı Başarılı")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(true)
                
            } else if bluetoothManager.isScanning {
                // Tarama yapılıyorsa durdurma butonu
                Button(action: {
                    bluetoothManager.stopScanning()
                    showingDeviceList = false
                }) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Aramayı Durdur")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
            } else {
                // Bağlantı başlatma butonu
                Button(action: startConnection) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(connectionAttempted ? "Tekrar Bağlan" : "Bluetooth Cihazı Bul")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canAttemptConnection)
            }
            
            // Hata durumlarında ek butonlar
            if case .error(let message) = bluetoothManager.connectionState {
                if message.contains("izin") || message.contains("kapalı") {
                    Button("Ayarlara Git") {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var devicesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bulunan Cihazlar")
                    .font(.headline)
                Spacer()
                Text("\(bluetoothManager.discoveredDevices.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(bluetoothManager.discoveredDevices) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("RSSI: \(device.rssi) dBm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Bağlan") {
                            bluetoothManager.connect(to: device)
                            showingDeviceList = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .animation(.easeInOut, value: bluetoothManager.discoveredDevices.count)
    }
    
    // MARK: - Computed Properties
    
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
    
    private var statusMessage: String {
        if bluetoothManager.connectedDevice != nil {
            return "Cihaz bağlı ve hazır"
        } else {
            return bluetoothManager.connectionState.description
        }
    }
    
    private var canAttemptConnection: Bool {
        switch bluetoothManager.connectionState {
        case .disconnected:
            return true
        case .error(let message):
            return !message.contains("desteklenmiyor")
        default:
            return false
        }
    }
    
    // MARK: - Methods
    
    private func initializeBluetooth() {
        // Bluetooth başlatma - otomatik izin isteme arka planda
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // İlk durum kontrolü
            print("🔄 Bluetooth durumu kontrol ediliyor...")
        }
    }
    
    private func startConnection() {
        connectionAttempted = true
        showingDeviceList = true
        
        print("🔍 Bluetooth bağlantısı başlatılıyor...")
        bluetoothManager.startScanning()
        
        // 15 saniye sonra otomatik olarak liste gizlensin
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if bluetoothManager.isScanning {
                showingDeviceList = false
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SimpleConnectionView(bluetoothManager: BluetoothManager())
}