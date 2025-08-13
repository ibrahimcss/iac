//
//  ErrorManager.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import Foundation
import SwiftUI

// MARK: - Error Types
enum IACError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothPoweredOff
    case deviceNotFound
    case connectionFailed(String)
    case connectionTimeout
    case characteristicNotFound
    case commandSendFailed(String)
    case invalidResponse(String)
    case unauthorized
    case unsupported
    
    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth mevcut değil"
        case .bluetoothPoweredOff:
            return "Bluetooth kapalı. Lütfen ayarlardan açın."
        case .deviceNotFound:
            return "Cihaz bulunamadı"
        case .connectionFailed(let reason):
            return "Bağlantı hatası: \(reason)"
        case .connectionTimeout:
            return "Bağlantı zaman aşımına uğradı"
        case .characteristicNotFound:
            return "Gerekli BLE karakteristiği bulunamadı"
        case .commandSendFailed(let command):
            return "Komut gönderilemedi: \(command)"
        case .invalidResponse(let response):
            return "Geçersiz yanıt: \(response)"
        case .unauthorized:
            return "Bluetooth izni gerekli"
        case .unsupported:
            return "Bu cihaz Bluetooth desteklemiyor"
        }
    }
    
    var recoveryDescription: String {
        switch self {
        case .bluetoothUnavailable, .unsupported:
            return "Bu cihaz Bluetooth Low Energy desteklemiyor."
        case .bluetoothPoweredOff:
            return "Ayarlar > Bluetooth'dan Bluetooth'u açın."
        case .unauthorized:
            return "Ayarlar > Gizlilik & Güvenlik > Bluetooth'dan izin verin."
        case .deviceNotFound:
            return "Cihazın açık ve eşleştirilebilir modda olduğundan emin olun."
        case .connectionTimeout, .connectionFailed:
            return "Cihaza daha yakın olun ve tekrar deneyin."
        case .characteristicNotFound:
            return "Cihazın uyumlu firmware'e sahip olduğundan emin olun."
        case .commandSendFailed, .invalidResponse:
            return "Bağlantınızı kontrol edin ve tekrar deneyin."
        }
    }
}

// MARK: - Error Manager
class ErrorManager: ObservableObject {
    @Published var currentError: IACError?
    @Published var showingError = false
    @Published var errorHistory: [ErrorEntry] = []
    
    private let maxErrorHistory = 50
    
    func handleError(_ error: IACError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showingError = true
            
            // Error history'ye ekle
            let entry = ErrorEntry(error: error, timestamp: Date())
            self.errorHistory.insert(entry, at: 0)
            
            // Maksimum history sayısını kontrol et
            if self.errorHistory.count > self.maxErrorHistory {
                self.errorHistory.removeLast()
            }
        }
        
        // Log'a kaydet
        logError(error)
    }
    
    func dismissError() {
        currentError = nil
        showingError = false
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    private func logError(_ error: IACError) {
        print("🔴 IAC Error: \(error.localizedDescription)")
        #if DEBUG
        print("🔴 Recovery: \(error.recoveryDescription)")
        #endif
    }
}

// MARK: - Error Entry
struct ErrorEntry: Identifiable {
    let id = UUID()
    let error: IACError
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Error View Modifier
struct ErrorHandling: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert("Hata", isPresented: $errorManager.showingError) {
                Button("Tamam") {
                    errorManager.dismissError()
                }
                
                if let error = errorManager.currentError {
                    if shouldShowRetryButton(for: error) {
                        Button("Yeniden Dene") {
                            errorManager.dismissError()
                            // Retry logic buraya eklenebilir
                        }
                    }
                    
                    if shouldShowSettingsButton(for: error) {
                        Button("Ayarlar") {
                            errorManager.dismissError()
                            openSettings()
                        }
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription)
                        Text(error.recoveryDescription)
                            .font(.caption)
                    }
                }
            }
    }
    
    private func shouldShowRetryButton(for error: IACError) -> Bool {
        switch error {
        case .deviceNotFound, .connectionFailed, .connectionTimeout, .commandSendFailed:
            return true
        default:
            return false
        }
    }
    
    private func shouldShowSettingsButton(for error: IACError) -> Bool {
        switch error {
        case .bluetoothPoweredOff, .unauthorized:
            return true
        default:
            return false
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

extension View {
    func errorHandling(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorHandling(errorManager: errorManager))
    }
}

// MARK: - Validation Utilities
struct ValidationUtils {
    static func validateCommand(_ command: String) -> Bool {
        // Boş komut kontrolü
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // ASCII karakter kontrolü
        guard command.allSatisfy({ $0.isASCII }) else {
            return false
        }
        
        // Maksimum uzunluk kontrolü (BLE karakteristik limiti)
        guard command.count <= 512 else {
            return false
        }
        
        return true
    }
    
    static func sanitizeCommand(_ command: String) -> String {
        return command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }
    
    static func validateModuleId(_ moduleId: String) -> Bool {
        // Modül ID formatı: CAN1, CAN2, etc.
        let pattern = "^[A-Z]{2,4}[0-9]{1,2}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: moduleId.count)
        return regex?.firstMatch(in: moduleId, options: [], range: range) != nil
    }
}

// MARK: - Security Manager
class SecurityManager {
    static let shared = SecurityManager()
    
    private init() {}
    
    // Rate limiting için komut sayacı
    private var commandCounts: [String: (count: Int, lastReset: Date)] = [:]
    private let maxCommandsPerMinute = 60
    
    func canSendCommand(from source: String = "default") -> Bool {
        let now = Date()
        
        if var entry = commandCounts[source] {
            // Dakika geçmişse sayacı sıfırla
            if now.timeIntervalSince(entry.lastReset) >= 60 {
                entry = (count: 0, lastReset: now)
            }
            
            // Maksimum sayıyı kontrol et
            if entry.count >= maxCommandsPerMinute {
                return false
            }
            
            // Sayacı artır
            commandCounts[source] = (count: entry.count + 1, lastReset: entry.lastReset)
        } else {
            // İlk komut
            commandCounts[source] = (count: 1, lastReset: now)
        }
        
        return true
    }
    
    func validateUUID(_ uuidString: String) -> Bool {
        return UUID(uuidString: uuidString) != nil
    }
    
    func generateSecureToken() -> String {
        let length = 32
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
}