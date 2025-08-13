//
//  LogView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import UIKit

struct LogView: View {
    @ObservedObject var commandProtocol: CommandProtocol
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var selectedFilter: LogFilter = .all
    @State private var showStatistics = false
    
    enum LogFilter: String, CaseIterable {
        case all = "Tümü"
        case commands = "Komutlar"
        case responses = "Yanıtlar"
        case system = "Sistem"
        case errors = "Hatalar"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .commands: return "arrow.up.circle"
            case .responses: return "arrow.down.circle"
            case .system: return "gear"
            case .errors: return "exclamationmark.triangle"
            }
        }
    }
    
    var filteredLogEntries: [LogEntry] {
        var entries = commandProtocol.logEntries
        
        // Filtre uygula
        switch selectedFilter {
        case .commands:
            entries = entries.filter { $0.type == .commandSent }
        case .responses:
            entries = entries.filter { $0.type == .responseReceived }
        case .system:
            entries = entries.filter { $0.type == .systemMessage }
        case .errors:
            entries = entries.filter { $0.status == .failed || $0.status == .timeout }
        case .all:
            break
        }
        
        // Arama filtresi
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                if let command = entry.command, command.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let response = entry.response, response.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }
        
        return entries
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // İstatistik kartı
            if showStatistics {
                StatisticsCard(commandProtocol: commandProtocol)
                    .padding(.horizontal)
                    .padding(.top)
            }
            
            // Filtre ve arama çubuğu
            VStack(spacing: 12) {
                // Filtre seçici
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LogFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Arama çubuğu
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Log ara...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Kontroller
                HStack {
                    Text("\(filteredLogEntries.count) kayıt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        commandProtocol.sendCustomCommand("test_command")
                    }) {
                        HStack {
                            Image(systemName: "bolt")
                            Text("Test Komut")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                    
                    Button(action: { showStatistics.toggle() }) {
                        HStack {
                            Image(systemName: showStatistics ? "chart.bar.fill" : "chart.bar")
                            Text(showStatistics ? "İstatistikleri Gizle" : "İstatistikleri Göster")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                HStack {
                    Spacer()
                                  Button(action: {
                        commandProtocol.clearLogs()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Temizle")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                                     Spacer()
                    
                    Toggle("Otomatik Kaydır", isOn: $autoScroll)
                        .font(.caption)
                    
      
                    
                }
                .padding(.horizontal)
            }
            
            Divider()
                .padding(.horizontal)
            
            // Log listesi
            if filteredLogEntries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "Henüz log kaydı yok" : "Arama sonucu bulunamadı")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Text("Sistem ve modüllerden gelen mesajlar burada görünecek")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(filteredLogEntries.enumerated()), id: \.element.id) { index, entry in
                            LogEntryRow(entry: entry)
                                .id(index)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: commandProtocol.logEntries.count) { _ in
                        if autoScroll && !filteredLogEntries.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(filteredLogEntries.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Log Mesajları")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { exportLogs() }) {
                        Label("Dışa Aktar", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { shareText(filteredLogEntries.map { $0.description }.joined(separator: "\n")) }) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func exportLogs() {
        let logText = filteredLogEntries.map { $0.description }.joined(separator: "\n")
        shareText(logText)
    }
    
    private func shareText(_ text: String) {
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Statistics Card
struct StatisticsCard: View {
    @ObservedObject var commandProtocol: CommandProtocol
    
    var body: some View {
        let stats = commandProtocol.getLogStatistics()
        
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Komut İstatistikleri")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatItem(title: "Toplam Komut", value: "\(stats.totalCommands)", color: .blue)
                StatItem(title: "Başarılı", value: "\(stats.successfulResponses)", color: .green)
                StatItem(title: "Başarısız", value: "\(stats.failedResponses)", color: .red)
                StatItem(title: "Bekleyen", value: "\(stats.pendingCommands)", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let filter: LogView.LogFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                Text(filter.rawValue)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Durum göstergesi
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Başlık ve zaman
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: typeIcon)
                                .foregroundColor(typeColor)
                            Text(typeTitle)
                                .font(.caption)
                                .foregroundColor(typeColor)
                        }
                        
                        Spacer()
                        
                        Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Komut bilgisi
                    if let command = entry.command {
                        Text("Komut: \(command)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    // Yanıt bilgisi
                    if let response = entry.response {
                        Text("Yanıt: \(response)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    // Genişlet/Daralt butonu
                    if entry.command != nil && entry.response != nil {
                        Button(isExpanded ? "Daralt" : "Genişlet") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch entry.status {
        case .pending: return .orange
        case .success: return .green
        case .failed: return .red
        case .timeout: return .red
        case .noResponse: return .gray
        }
    }
    
    private var typeIcon: String {
        switch entry.type {
        case .commandSent: return "arrow.up.circle"
        case .responseReceived: return "arrow.down.circle"
        case .systemMessage: return "gear"
        case .error: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
    
    private var typeColor: Color {
        switch entry.type {
        case .commandSent: return .blue
        case .responseReceived: return .green
        case .systemMessage: return .purple
        case .error: return .red
        case .info: return .gray
        }
    }
    
    private var typeTitle: String {
        switch entry.type {
        case .commandSent: return "Komut Gönderildi"
        case .responseReceived: return "Yanıt Alındı"
        case .systemMessage: return "Sistem Mesajı"
        case .error: return "Hata"
        case .info: return "Bilgi"
        }
    }
}

// MARK: - Log Entry Extensions
extension LogEntry {
    var description: String {
        let timestamp = timestamp.formatted(.dateTime.hour().minute().second())
        var desc = "[\(timestamp)] "
        
        switch type {
        case .commandSent:
            desc += "Komut gönderildi: \(command ?? "")"
        case .responseReceived:
            desc += "Yanıt alındı: \(response ?? "")"
        case .systemMessage:
            desc += "Sistem: \(response ?? "")"
        case .error:
            desc += "Hata: \(response ?? "")"
        case .info:
            desc += response ?? ""
        }
        
        return desc
    }
}

#Preview {
    NavigationView {
        LogView(commandProtocol: {
            let commandProtocol = CommandProtocol(bluetoothManager: BluetoothManager())
            commandProtocol.logMessages = [
                "10:30:15: Sistem başlatıldı",
                "10:30:16: CAN1 modülü aktif",
                "10:30:17: Hata: CAN2 bağlantı sorunu",
                "10:30:18: Uyarı: Yüksek sıcaklık",
                "10:30:19: Bilgi: Kalibrasyon tamamlandı"
            ]
            return commandProtocol
        }())
    }
}