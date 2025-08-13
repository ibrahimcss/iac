//
//  PermissionRequestView.swift
//  iac
//
//  Created by İbrahim Yıldırım on 6.08.2025.
//

import SwiftUI
import CoreBluetooth

struct PermissionRequestView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var showingOnboarding = true
    
    var body: some View {
        if bluetoothManager.permissionManager.permissionStatus == .allowed {
            MainControlView()
        } else {
            onboardingView
        }
    }
    
    private var onboardingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Uygulama İkonu
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("IAC Control'e Hoş Geldiniz")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("BLE cihazları ile iletişim kurmak için Bluetooth izni gerekli")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // İzin durumu göstergesi
                HStack {
                    Circle()
                        .fill(permissionColor)
                        .frame(width: 12, height: 12)
                    
                    Text("Bluetooth İzni: \(bluetoothManager.permissionManager.permissionStatus.description)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Aksiyon butonları - sadece reddedilmişse veya kısıtlıysa göster
                if bluetoothManager.permissionManager.permissionStatus == .denied || 
                   bluetoothManager.permissionManager.permissionStatus == .restricted {
                    VStack(spacing: 12) {
                        Button(action: {
                            bluetoothManager.permissionManager.openAppSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Ayarlara Git")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Simulator uyarısı
                        #if targetEnvironment(simulator)
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("iOS Simulator")
                                    .fontWeight(.medium)
                            }
                            Text("Bluetooth iOS Simulator'da desteklenmez. Gerçek cihazda test edin.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        #endif
                    }
                } else if bluetoothManager.permissionManager.permissionStatus == .notDetermined {
                    // İzin henüz istenmemişse, otomatik olarak isteniyor mesajı göster
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Bluetooth izni isteniyor...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Bilgilendirme metni - duruma göre
            if bluetoothManager.permissionManager.permissionStatus != .allowed {
                VStack(spacing: 8) {
                    Text(infoTitle)
                        .font(.headline)
                    
                    Text(infoMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            bluetoothManager.permissionManager.checkBluetoothPermission()
            
            // Otomatik izin isteme - sadece gerçek cihazda ve izin belirlenmemişse
            #if !targetEnvironment(simulator)
            if bluetoothManager.permissionManager.permissionStatus == .notDetermined {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    bluetoothManager.permissionManager.requestBluetoothPermission()
                }
            }
            #endif
        }
    }
    
    private var permissionColor: Color {
        switch bluetoothManager.permissionManager.permissionStatus {
        case .allowed:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    private var infoTitle: String {
        switch bluetoothManager.permissionManager.permissionStatus {
        case .notDetermined:
            return "İzin Nasıl Verilir?"
        case .denied:
            return "İzin Reddedildi"
        case .restricted:
            #if targetEnvironment(simulator)
            return "Simulator Uyarısı"
            #else
            return "İzin Kısıtlı"
            #endif
        default:
            return "Bluetooth Durumu"
        }
    }
    
    private var infoMessage: String {
        switch bluetoothManager.permissionManager.permissionStatus {
        case .notDetermined:
            return "Bluetooth izni otomatik olarak isteniyor. Çıkan dialog'dan \"Allow\" seçin."
        case .denied:
            return "Ayarlar → Gizlilik & Güvenlik → Bluetooth → IAC Control yolunu izleyerek izin verin."
        case .restricted:
            #if targetEnvironment(simulator)
            return "Bluetooth özellikleri gerçek iOS cihazında test edilmelidir."
            #else
            return "Bluetooth izni sistem tarafından kısıtlanmış. Cihaz ayarlarını kontrol edin."
            #endif
        default:
            return ""
        }
    }
    

}

#Preview {
    PermissionRequestView(bluetoothManager: BluetoothManager())
}