//
//  SettingsView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var showingDeviceSelection: Bool
    @AppStorage("autoReconnect") private var autoReconnect = true
    @AppStorage("keepScreenOn") private var keepScreenOn = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showingAbout = false
    
    var body: some View {
        List {
            // Bağlantı Ayarları
            Section("Bağlantı") {
                HStack {
                    Label("Mevcut Cihaz", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    if let device = bluetoothManager.connectedDevice {
                        Text(device.name)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Bağlı değil")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { showingDeviceSelection = true }) {
                    Label("Cihaz Seç", systemImage: "magnifyingglass")
                }
                
                if bluetoothManager.connectedDevice != nil {
                    Button(action: { bluetoothManager.disconnect() }) {
                        Label("Bağlantıyı Kes", systemImage: "xmark.circle")
                    }
                    .foregroundColor(.red)
                }
                
                Toggle(isOn: $autoReconnect) {
                    Label("Otomatik Yeniden Bağlan", systemImage: "arrow.clockwise")
                }
            }
            
            // Uygulama Ayarları
            Section("Uygulama") {
                Toggle(isOn: $keepScreenOn) {
                    Label("Ekranı Açık Tut", systemImage: "sun.max")
                }
                
                Toggle(isOn: $notificationsEnabled) {
                    Label("Bildirimler", systemImage: "bell")
                }
            }
            
            // BLE Ayarları
            Section("Bluetooth Ayarları") {
                BluetoothSettingsView()
            }
            
            // Debug Bilgileri
            Section("Debug") {
                NavigationLink(destination: BluetoothDebugView(bluetoothManager: bluetoothManager)) {
                    Label("Bluetooth Debug", systemImage: "ant")
                }
                
                NavigationLink(destination: PermissionStatusView()) {
                    Label("İzin Durumu", systemImage: "checkmark.shield")
                }
                
                DebugInfoView(bluetoothManager: bluetoothManager)
            }
            
            // Uygulama Bilgileri
            Section("Hakkında") {
                Button(action: { showingAbout = true }) {
                    Label("Uygulama Hakkında", systemImage: "info.circle")
                }
                
                Label("Sürüm 1.0.0", systemImage: "number")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Ayarlar")
        .sheet(isPresented: $showingAbout) {
            AboutView(isPresented: $showingAbout)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepScreenOn
        }
        .onChange(of: keepScreenOn) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
}

struct BluetoothSettingsView: View {
    @AppStorage("scanDuration") private var scanDuration = 10.0
    @AppStorage("connectionTimeout") private var connectionTimeout = 15.0
    @AppStorage("allowDuplicates") private var allowDuplicates = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tarama Süresi")
                    Spacer()
                    Text("\(Int(scanDuration)) saniye")
                        .foregroundColor(.secondary)
                }
                Slider(value: $scanDuration, in: 5...30, step: 5)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bağlantı Zaman Aşımı")
                    Spacer()
                    Text("\(Int(connectionTimeout)) saniye")
                        .foregroundColor(.secondary)
                }
                Slider(value: $connectionTimeout, in: 10...60, step: 5)
            }
            
            Toggle(isOn: $allowDuplicates) {
                Text("Tekrar Eden Cihazlara İzin Ver")
            }
        }
        .padding(.vertical, 8)
    }
}

struct DebugInfoView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DebugRow(title: "Bluetooth Durumu", value: bluetoothStateDescription)
            DebugRow(title: "Bağlantı Durumu", value: bluetoothManager.connectionState.description)
            DebugRow(title: "Bulunan Cihaz Sayısı", value: "\(bluetoothManager.discoveredDevices.count)")
            DebugRow(title: "Alınan Mesaj Sayısı", value: "\(bluetoothManager.receivedMessages.count)")
            
            if let device = bluetoothManager.connectedDevice {
                DebugRow(title: "Bağlı Cihaz ID", value: device.peripheral.identifier.uuidString)
                DebugRow(title: "RSSI", value: "\(device.rssi) dBm")
            }
        }
        .padding(.vertical, 8)
    }
    
    private var bluetoothStateDescription: String {
        // CBCentralManager state'ini string'e çevir
        switch bluetoothManager.connectionState {
        case .connected:
            return "Bağlı"
        case .connecting:
            return "Bağlanıyor"
        case .scanning:
            return "Tarıyor"
        case .disconnected:
            return "Bağlı Değil"
        case .error(let message):
            return "Hata: \(message)"
        }
    }
}

struct DebugRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Uygulama İkonu
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("IAC Control")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sürüm 1.0.0")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("IAC Control, Bluetooth Low Energy (BLE) üzerinden ASCII komutları ile çalışan sistemleri kontrol etmek için geliştirilmiş bir iOS uygulamasıdır.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Özellikler:")
                                .font(.headline)
                            
                            FeatureRow(icon: "antenna.radiowaves.left.and.right", text: "BLE üzerinden cihaz bağlantısı")
                            FeatureRow(icon: "terminal", text: "ASCII komut protokolü desteği")
                            FeatureRow(icon: "cpu", text: "Modül durumu izleme")
                            FeatureRow(icon: "doc.text", text: "Gerçek zamanlı log görüntüleme")
                            FeatureRow(icon: "gear", text: "Gelişmiş yapılandırma seçenekleri")
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Desteklenen Komutlar:")
                                .font(.headline)
                            
                            CommandRow(command: "start_system", description: "Sistemi başlat")
                            CommandRow(command: "CANx:RESET", description: "Modül sıfırla")
                            CommandRow(command: "CANx:get_log", description: "Modül logu al")
                            CommandRow(command: "CANx:set_isim:İsim", description: "Modül ismini değiştir")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("© 2025 İbrahim Yıldırım")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Hakkında")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct CommandRow: View {
    let command: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(4)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView(
        bluetoothManager: BluetoothManager(),
        showingDeviceSelection: .constant(false)
    )
}