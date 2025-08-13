//
//  ModulesView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI

struct ModulesView: View {
    @ObservedObject var commandProtocol: CommandProtocol
    @State private var selectedModule: ModuleStatus?
    @State private var showingModuleDetail = false
    
    var body: some View {
        List {
            ForEach(commandProtocol.getModulesList()) { module in
                ModuleRowView(module: module) {
                    selectedModule = module
                    showingModuleDetail = true
                }
            }
        }
        .navigationTitle("Modüller")
        .sheet(isPresented: $showingModuleDetail) {
            if let module = selectedModule {
                ModuleDetailView(
                    module: module,
                    commandProtocol: commandProtocol,
                    isPresented: $showingModuleDetail
                )
            }
        }
        .refreshable {
            // Tüm modüllerin durumunu güncelle
            for module in commandProtocol.getModulesList() {
                commandProtocol.executeModuleCommand(module.moduleId, command: .getStatus)
                commandProtocol.executeModuleCommand(module.moduleId, command: .getError)
            }
        }
    }
}

struct ModuleRowView: View {
    let module: ModuleStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Modül durumu göstergesi
                VStack(spacing: 4) {
                    Circle()
                        .fill(module.isActive ? .green : .gray)
                        .frame(width: 12, height: 12)
                    
                    if module.hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(module.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(module.moduleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        StatusBadge(
                            text: module.isActive ? "Aktif" : "Pasif",
                            color: module.isActive ? .green : .gray
                        )
                        
                        if module.hasError {
                            StatusBadge(
                                text: "Hata: \(module.errorCode)",
                                color: .red
                            )
                        }
                        
                        Spacer()
                        
                        Text(timeAgoString(from: module.lastUpdate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

struct ModuleDetailView: View {
    let module: ModuleStatus
    @ObservedObject var commandProtocol: CommandProtocol
    @Binding var isPresented: Bool
    @State private var newModuleName: String = ""
    @State private var showingNameEditor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Modül Bilgileri
                    ModuleInfoCard(module: module)
                    
                    // Durum Kontrolü
                    ModuleStatusCard(module: module)
                    
                    // Modül Komutları
                    ModuleCommandsCard(
                        module: module,
                        commandProtocol: commandProtocol
                    )
                    
                    // Modül Ayarları
                    ModuleSettingsCard(
                        module: module,
                        commandProtocol: commandProtocol,
                        newModuleName: $newModuleName,
                        showingNameEditor: $showingNameEditor
                    )
                }
                .padding()
            }
            .navigationTitle(module.name)
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
            newModuleName = module.name
        }
    }
}

struct ModuleInfoCard: View {
    let module: ModuleStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Modül Bilgileri")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "Modül ID", value: module.moduleId)
                InfoRow(title: "İsim", value: module.name)
                InfoRow(title: "Son Güncelleme", value: DateFormatter.localizedString(from: module.lastUpdate, dateStyle: .short, timeStyle: .medium))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ModuleStatusCard: View {
    let module: ModuleStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gauge")
                    .foregroundColor(.green)
                Text("Durum")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(module.isActive ? .green : .gray)
                        .frame(width: 24, height: 24)
                    
                    Text(module.isActive ? "Aktif" : "Pasif")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    Image(systemName: module.hasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(module.hasError ? .red : .green)
                        .font(.title2)
                    
                    Text(module.hasError ? "Hata: \(module.errorCode)" : "Normal")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ModuleCommandsCard: View {
    let module: ModuleStatus
    @ObservedObject var commandProtocol: CommandProtocol
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.purple)
                Text("Modül Komutları")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CommandProtocol.ModuleCommand.allCases, id: \.self) { command in
                    Button(action: {
                        commandProtocol.executeModuleCommand(module.moduleId, command: command)
                    }) {
                        HStack {
                            Image(systemName: iconForModuleCommand(command))
                            Text(command.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconForModuleCommand(_ command: CommandProtocol.ModuleCommand) -> String {
        switch command {
        case .reset:
            return "arrow.clockwise"
        case .getLog:
            return "doc.text"
        case .getName:
            return "tag"
        case .getStatus:
            return "info.circle"
        case .getError:
            return "exclamationmark.triangle"
        }
    }
}

struct ModuleSettingsCard: View {
    let module: ModuleStatus
    @ObservedObject var commandProtocol: CommandProtocol
    @Binding var newModuleName: String
    @Binding var showingNameEditor: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.orange)
                Text("Modül Ayarları")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Modül İsmi")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button("Düzenle") {
                        showingNameEditor = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                
                Divider()
                
                HStack {
                    Text("Hata Durumu Simülasyonu")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Hata Ver") {
                            commandProtocol.setModuleError(module.moduleId, errorState: true)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("Temizle") {
                            commandProtocol.setModuleError(module.moduleId, errorState: false)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Modül İsmi Düzenle", isPresented: $showingNameEditor) {
            TextField("Yeni isim", text: $newModuleName)
            Button("İptal", role: .cancel) { }
            Button("Kaydet") {
                commandProtocol.setModuleName(module.moduleId, name: newModuleName)
            }
        } message: {
            Text("Modül için yeni bir isim girin")
        }
    }
}

#Preview {
    ModulesView(commandProtocol: CommandProtocol(bluetoothManager: BluetoothManager()))
}