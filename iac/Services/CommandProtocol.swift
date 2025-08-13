//
//  CommandProtocol.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import Foundation
import Combine

// MARK: - Command Response Parser
struct CommandResponse {
    let rawResponse: String
    let module: String?
    let action: String?
    let value: String?
    
    init(rawResponse: String) {
        self.rawResponse = rawResponse
        
        // Format: "MODULE:ACTION:VALUE" veya "MODULE:ACTION"
        let components = rawResponse.components(separatedBy: ":")
        
        if components.count >= 2 {
            self.module = components[0]
            self.action = components[1]
            self.value = components.count >= 3 ? components[2] : nil
        } else {
            self.module = nil
            self.action = nil
            self.value = nil
        }
    }
}

// MARK: - Log Entry Structure
struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let type: LogEntryType
    let command: String?
    let response: String?
    let status: LogStatus
    
    enum LogEntryType {
        case commandSent
        case responseReceived
        case systemMessage
        case error
        case info
    }
    
    enum LogStatus {
        case pending
        case success
        case failed
        case timeout
        case noResponse
    }
}

class CommandProtocol: ObservableObject {
    // MARK: - Published Properties
    @Published var moduleStatuses: [String: ModuleStatus] = [:]
    @Published var systemStatus: String = "OFFLINE"
    @Published var logMessages: [String] = []
    @Published var logEntries: [LogEntry] = []
    
    // MARK: - Private Properties
    private let bluetoothManager: BluetoothManager
    private var cancellables = Set<AnyCancellable>()
    private var pendingCommands: [String: Date] = [:] // command: timestamp
    private let commandTimeout: TimeInterval = 10.0 // 10 saniye timeout
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        setupMessageHandling()
        startCommandTimeoutTimer()
    }
    
    // MARK: - Message Handling
    private func setupMessageHandling() {
        bluetoothManager.$receivedMessages
            .sink { [weak self] messages in
                if let lastMessage = messages.last {
                    self?.processReceivedMessage(lastMessage)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processReceivedMessage(_ message: String) {
        let response = CommandResponse(rawResponse: message)
        
        // Komut yanıtı olup olmadığını kontrol et
        if let commandId = findMatchingCommand(for: message) {
            handleCommandResponse(commandId: commandId, response: message)
        }
        
        guard let module = response.module, let action = response.action else {
            // Genel sistem mesajları
            if message.hasPrefix("GNS:") {
                let status = String(message.dropFirst(4))
                DispatchQueue.main.async {
                    self.systemStatus = status
                    self.addLogEntry(type: .systemMessage, command: nil, response: status, status: .success)
                }
            } else if message.hasPrefix("MSJ:") {
                let logMessage = String(message.dropFirst(4))
                DispatchQueue.main.async {
                    self.logMessages.append("\(Date().formatted(.dateTime.hour().minute().second())): \(logMessage)")
                    self.addLogEntry(type: .info, command: nil, response: logMessage, status: .success)
                }
            } else {
                // Genel mesaj
                DispatchQueue.main.async {
                    self.addLogEntry(type: .info, command: nil, response: message, status: .success)
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.handleModuleResponse(module: module, action: action, value: response.value)
        }
    }
    
    private func findMatchingCommand(for response: String) -> String? {
        // Gönderilen komutlarla yanıtları eşleştir
        for (command, _) in pendingCommands {
            if response.lowercased().contains(command.lowercased()) ||
               response.lowercased().contains("ok") ||
               response.lowercased().contains("success") ||
               response.lowercased().contains("error") ||
               response.lowercased().contains("hata") {
                return command
            }
        }
        return nil
    }
    
    private func handleCommandResponse(commandId: String, response: String) {
        DispatchQueue.main.async {
            // Pending komutu kaldır
            self.pendingCommands.removeValue(forKey: commandId)
            
            // Yanıt logunu ekle
            let status: LogEntry.LogStatus = response.lowercased().contains("error") || response.lowercased().contains("hata") ? .failed : .success
            self.addLogEntry(type: .responseReceived, command: commandId, response: response, status: status)
        }
    }
    
    private func handleModuleResponse(module: String, action: String, value: String?) {
        // Modül yoksa oluştur
        if moduleStatuses[module] == nil {
            moduleStatuses[module] = ModuleStatus(moduleId: module, name: module)
        }
        
        guard var moduleStatus = moduleStatuses[module] else { return }
        
        switch action {
        case "durum":
            moduleStatus.isActive = (value == "1" || value?.lowercased() == "ok")
            
        case "hata":
            if let errorCode = value, let code = Int(errorCode) {
                moduleStatus.hasError = (code != 0)
                moduleStatus.errorCode = code
            }
            
        case "isim":
            if let name = value {
                moduleStatus.name = name
            }
            
        default:
            break
        }
        
        moduleStatus.lastUpdate = Date()
        moduleStatuses[module] = moduleStatus
    }
    
    // MARK: - Command Sending Methods
    func startSystem() {
        let command = "start_system"
        sendCommandWithLogging(command)
    }
    
    func resetModule(_ moduleId: String) {
        let command = "\(moduleId):RESET"
        sendCommandWithLogging(command)
    }
    
    func setModuleName(_ moduleId: String, name: String) {
        let command = "\(moduleId):set_isim:\(name)"
        sendCommandWithLogging(command)
    }
    
    func setModuleError(_ moduleId: String, errorState: Bool) {
        let errorValue = errorState ? "1" : "0"
        let command = "\(moduleId):set_hata:\(errorValue)"
        sendCommandWithLogging(command)
    }
    
    func requestModuleLog(_ moduleId: String) {
        let command = "\(moduleId):get_log"
        sendCommandWithLogging(command)
    }
    
    func sendCustomCommand(_ command: String) {
        sendCommandWithLogging(command)
    }
    
    private func sendCommandWithLogging(_ command: String) {
        // Komut gönderildi logunu ekle
        addLogEntry(type: .commandSent, command: command, response: nil, status: .pending)
        
        // Pending komutları takip et
        pendingCommands[command] = Date()
        
        // Bluetooth üzerinden gönder
        bluetoothManager.sendCommand(command)
    }
    
    // MARK: - Predefined Commands
    enum SystemCommand: String, CaseIterable {
        case startSystem = "start_system"
        case stopSystem = "stop_system"
        case getStatus = "get_status"
        case reset = "reset"
        
        var displayName: String {
            switch self {
            case .startSystem:
                return "Sistemi Başlat"
            case .stopSystem:
                return "Sistemi Durdur"
            case .getStatus:
                return "Durum Al"
            case .reset:
                return "Sıfırla"
            }
        }
    }
    
    enum ModuleCommand: String, CaseIterable {
        case reset = "RESET"
        case getLog = "get_log"
        case getName = "get_isim"
        case getStatus = "get_durum"
        case getError = "get_hata"
        
        var displayName: String {
            switch self {
            case .reset:
                return "Sıfırla"
            case .getLog:
                return "Log Al"
            case .getName:
                return "İsim Al"
            case .getStatus:
                return "Durum Al"
            case .getError:
                return "Hata Durumu Al"
            }
        }
    }
    
    func executeSystemCommand(_ command: SystemCommand) {
        sendCommandWithLogging(command.rawValue)
    }
    
    func executeModuleCommand(_ moduleId: String, command: ModuleCommand) {
        let fullCommand = "\(moduleId):\(command.rawValue)"
        sendCommandWithLogging(fullCommand)
    }
    
    // MARK: - Logging Methods
    private func addLogEntry(type: LogEntry.LogEntryType, command: String?, response: String?, status: LogEntry.LogStatus) {
        let entry = LogEntry(
            timestamp: Date(),
            type: type,
            command: command,
            response: response,
            status: status
        )
        
        logEntries.append(entry)
        
        // Eski logları temizle (son 1000 entry)
        if logEntries.count > 1000 {
            logEntries.removeFirst(logEntries.count - 1000)
        }
        
        // Eski logMessages formatını da güncelle
        let timestamp = Date().formatted(.dateTime.hour().minute().second())
        var logMessage = "\(timestamp): "
        
        switch type {
        case .commandSent:
            logMessage += "Komut gönderildi: \(command ?? "")"
        case .responseReceived:
            logMessage += "Yanıt alındı: \(response ?? "")"
        case .systemMessage:
            logMessage += "Sistem: \(response ?? "")"
        case .error:
            logMessage += "Hata: \(response ?? "")"
        case .info:
            logMessage += response ?? ""
        }
        
        logMessages.append(logMessage)
        
        // Eski logMessages'ı da temizle
        if logMessages.count > 1000 {
            logMessages.removeFirst(logMessages.count - 1000)
        }
    }
    
    private func startCommandTimeoutTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkCommandTimeouts()
        }
    }
    
    private func checkCommandTimeouts() {
        let now = Date()
        let timeoutCommands = pendingCommands.filter { now.timeIntervalSince($0.value) > commandTimeout }
        
        for (command, _) in timeoutCommands {
            DispatchQueue.main.async {
                self.pendingCommands.removeValue(forKey: command)
                self.addLogEntry(type: .responseReceived, command: command, response: "Timeout - Yanıt alınamadı", status: .timeout)
            }
        }
    }
    
    // MARK: - Helper Methods
    func clearLogs() {
        logMessages.removeAll()
        logEntries.removeAll()
        pendingCommands.removeAll()
    }
    
    func getModulesList() -> [ModuleStatus] {
        return Array(moduleStatuses.values).sorted { $0.moduleId < $1.moduleId }
    }
    
    func getActiveModulesCount() -> Int {
        return moduleStatuses.values.filter { $0.isActive }.count
    }
    
    func getErrorModulesCount() -> Int {
        return moduleStatuses.values.filter { $0.hasError }.count
    }
    
    // MARK: - Log Statistics
    func getLogStatistics() -> (totalCommands: Int, successfulResponses: Int, failedResponses: Int, pendingCommands: Int) {
        let totalCommands = logEntries.filter { $0.type == .commandSent }.count
        let successfulResponses = logEntries.filter { $0.type == .responseReceived && $0.status == .success }.count
        let failedResponses = logEntries.filter { $0.type == .responseReceived && $0.status == .failed }.count
        let pendingCommands = pendingCommands.count
        
        return (totalCommands, successfulResponses, failedResponses, pendingCommands)
    }
}
