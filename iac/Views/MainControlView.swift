//
//  MainControlView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI

struct MainControlView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var commandProtocol: CommandProtocol
    @State private var showingDeviceSelection = false
    @State private var selectedTab = 0
    
    init() {
        let btManager = BluetoothManager()
        _bluetoothManager = StateObject(wrappedValue: btManager)
        _commandProtocol = StateObject(wrappedValue: CommandProtocol(bluetoothManager: btManager))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Ana Kontrol Sekmesi
            NavigationView {
                SystemControlView(
                    bluetoothManager: bluetoothManager,
                    commandProtocol: commandProtocol,
                    showingDeviceSelection: $showingDeviceSelection
                )
            }
            .tabItem {
                Image(systemName: "slider.horizontal.3")
                Text("Kontrol")
            }
            .tag(0)
            
            // Modüller Sekmesi
            NavigationView {
                ModulesView(commandProtocol: commandProtocol)
            }
            .tabItem {
                Image(systemName: "cpu")
                Text("Modüller")
            }
            .tag(1)
            
            // Log Sekmesi
            NavigationView {
                LogView(commandProtocol: commandProtocol)
            }
            .tabItem {
                Image(systemName: "doc.text")
                Text("Log")
            }
            .tag(2)
            
            // Ayarlar Sekmesi
            NavigationView {
                SettingsView(
                    bluetoothManager: bluetoothManager,
                    showingDeviceSelection: $showingDeviceSelection
                )
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Ayarlar")
            }
            .tag(3)
        }
        .sheet(isPresented: $showingDeviceSelection) {
            DeviceSelectionView(
                bluetoothManager: bluetoothManager,
                isPresented: $showingDeviceSelection
            )
        }
        .errorHandling(bluetoothManager.errorManager)
        .bluetoothPermissionAlert(bluetoothManager.permissionManager)
    }
}

struct SystemControlView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var commandProtocol: CommandProtocol
    @Binding var showingDeviceSelection: Bool
    @State private var customCommand: String = ""
    @State private var showingCustomCommandAlert = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Bağlantı Durumu Kartı
                ConnectionCard(
                    bluetoothManager: bluetoothManager,
                    showingDeviceSelection: $showingDeviceSelection
                )
                
                // Sistem Durumu Kartı
                SystemStatusCard(
                    systemStatus: commandProtocol.systemStatus,
                    activeModules: commandProtocol.getActiveModulesCount(),
                    errorModules: commandProtocol.getErrorModulesCount()
                )
                
                // Hızlı Komutlar
                QuickCommandsCard(commandProtocol: commandProtocol)
                
                // Özel Komut
                CustomCommandCard(
                    customCommand: $customCommand,
                    showingAlert: $showingCustomCommandAlert,
                    onSendCommand: { command in
                        commandProtocol.sendCustomCommand(command)
                        customCommand = ""
                    }
                )
            }
            .padding()
        }
        .navigationTitle("IAC Kontrol")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ConnectionCard: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var showingDeviceSelection: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("Bağlantı Durumu")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetoothManager.connectionState.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let device = bluetoothManager.connectedDevice {
                        Text("Bağlı: \(device.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Cihaz bağlantısı için Ayarlar > Cihaz Seç")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(bluetoothManager.connectedDevice == nil ? "Cihaz Seç" : "Değiştir") {
                    showingDeviceSelection = true
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            // Otomatik tarama durumu
            if bluetoothManager.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cihaz aranıyor...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionColor: Color {
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
}

struct SystemStatusCard: View {
    let systemStatus: String
    let activeModules: Int
    let errorModules: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gauge")
                    .foregroundColor(.green)
                Text("Sistem Durumu")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatusItem(
                    title: "Durum",
                    value: systemStatus,
                    color: systemStatus == "OK" ? .green : .red
                )
                
                Divider()
                
                StatusItem(
                    title: "Aktif Modüller",
                    value: "\(activeModules)",
                    color: .blue
                )
                
                Divider()
                
                StatusItem(
                    title: "Hatalı Modüller",
                    value: "\(errorModules)",
                    color: errorModules > 0 ? .red : .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickCommandsCard: View {
    @ObservedObject var commandProtocol: CommandProtocol
    
    let commands = CommandProtocol.SystemCommand.allCases
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt")
                    .foregroundColor(.orange)
                Text("Hızlı Komutlar")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(commands, id: \.self) { command in
                    Button(action: {
                        commandProtocol.executeSystemCommand(command)
                    }) {
                        HStack {
                            Image(systemName: iconForCommand(command))
                            Text(command.displayName)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconForCommand(_ command: CommandProtocol.SystemCommand) -> String {
        switch command {
        case .startSystem:
            return "play.circle"
        case .stopSystem:
            return "stop.circle"
        case .getStatus:
            return "info.circle"
        case .reset:
            return "arrow.clockwise"
        }
    }
}

struct CustomCommandCard: View {
    @Binding var customCommand: String
    @Binding var showingAlert: Bool
    let onSendCommand: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.purple)
                Text("Özel Komut")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                TextField("Komut girin (örn: CAN1:get_log)", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                Button("Gönder") {
                    if !customCommand.isEmpty {
                        onSendCommand(customCommand)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(customCommand.isEmpty)
            }
            
            Text("Örnek komutlar: start_system, CAN1:RESET, CAN2:get_log")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    MainControlView()
}