import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectedDevice: BluetoothDevice?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessages: [String] = []
    @Published var isScanning: Bool = false
    
    // MARK: - Error Management
    @Published var errorManager = ErrorManager()
    @Published var permissionManager = PermissionManager()
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // BLE Service ve Characteristic UUID'leri
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    private let writeCharacteristicUUID = CBUUID(string: "87654321-4321-4321-4321-cba987654321")
    private let notifyCharacteristicUUID = CBUUID(string: "11111111-2222-3333-4444-555555555555")
    
    private var messageBuffer: String = ""
    
    override init() {
        super.init()
        // İzin durumunu kontrol et
        permissionManager.checkBluetoothPermission()
        
        // CBCentralManager'ı direkt initialize et - iOS 13+ için önerilen yöntem
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "iac-bluetooth-manager"
        ])
        
        // İzinleri otomatik iste
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            BluetoothPermissionHelper.shared.requestAllPermissions { success in
                print("📋 Tüm izinler istendi: \(success)")
            }
        }
    }
    
    // MARK: - Public Methods
    func startScanning() {
        print("🔍 Tarama başlatılıyor... Mevcut durum: \(centralManager.state.rawValue)")
        
        // Sadece poweredOn durumunda tarama yap
        guard centralManager.state == .poweredOn else {
            let stateDescription = bluetoothStateDescription(centralManager.state)
            print("❌ Bluetooth durumu uygun değil: \(stateDescription)")
            // Hata durumunu güncelle
            DispatchQueue.main.async {
                self.connectionState = .error("Bluetooth durumu: \(stateDescription)")
            }
            return
        }
        
        // Scanning zaten devam ediyorsa tekrar başlatma
        guard !isScanning else { return }
        
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.isScanning = true
            self.connectionState = .scanning
        }
        
        // Tüm servisleri ara
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("✅ Bluetooth tarama başlatıldı")
        
        // 15 saniye sonra taramayı durdur
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            self.stopScanning()
        }
    }
    
    // MARK: - Helper Methods
    private func bluetoothStateDescription(_ state: CBManagerState) -> String {
        // ... (Bu kısım aynı kalabilir)
        switch state {
        case .unknown: return "Bilinmiyor"
        case .resetting: return "Yeniden başlatılıyor"
        case .unsupported: return "Desteklenmiyor"
        case .unauthorized: return "İzin yok"
        case .poweredOff: return "Kapalı"
        case .poweredOn: return "Açık"
        @unknown default: return "Bilinmeyen durum"
        }
    }
    
    func stopScanning() {
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            if connectionState == .scanning {
                connectionState = .disconnected
            }
        }
    }
    
    func connect(to device: BluetoothDevice) {
        stopScanning()
        connectionState = .connecting
        connectedDevice = device
        centralManager.connect(device.peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }
    
    func sendCommand(_ command: String) {
        // ... (Bu kısım aynı kalabilir)
        // Komut validasyonu
        guard ValidationUtils.validateCommand(command) else {
            errorManager.handleError(.commandSendFailed("Geçersiz komut formatı"))
            return
        }
        
        // Rate limiting kontrolü
        guard SecurityManager.shared.canSendCommand() else {
            errorManager.handleError(.commandSendFailed("Çok fazla komut gönderildi, lütfen bekleyin"))
            return
        }
        
        guard let characteristic = writeCharacteristic,
              let peripheral = connectedPeripheral else {
            errorManager.handleError(.characteristicNotFound)
            return
        }
        
        let sanitizedCommand = ValidationUtils.sanitizeCommand(command)
        let commandWithNewline = sanitizedCommand + "\n"
        guard let data = commandWithNewline.data(using: .utf8) else {
            errorManager.handleError(.commandSendFailed("Komut kodlanamadı"))
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("Komut gönderildi: \(sanitizedCommand)")
    }
    
    private func cleanup() {
        connectedPeripheral = nil
        connectedDevice = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        connectionState = .disconnected
        messageBuffer = ""
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("🔄 CBCentralManager restore state: \(dict)")
        
        // Eğer önceden bağlı peripheraller varsa onları restore et
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                print("📱 Restored peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
                
                // Eğer bu peripheral daha önce bağlıysa, tekrar bağlanmaya çalış
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                    peripheral.delegate = self
                    
                    // Device listesinde yoksa ekle
                    let device = BluetoothDevice(peripheral: peripheral, rssi: NSNumber(value: -50))
                    if !discoveredDevices.contains(device) {
                        DispatchQueue.main.async {
                            self.discoveredDevices.append(device)
                            self.connectedDevice = device
                            self.connectionState = .connected
                        }
                    }
                }
            }
        }
        
        // Eğer tarama yapılıyormuş restore et
        if let scanServices = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            print("📡 Restored scan services: \(scanServices)")
            DispatchQueue.main.async {
                self.isScanning = true
                self.connectionState = .scanning
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔄 Bluetooth durumu değişti: \(bluetoothStateDescription(central.state))")
        
        DispatchQueue.main.async {
            // İzin durumunu güncelle
            self.permissionManager.checkBluetoothPermission()
            
            switch central.state {
            case .poweredOn:
                print("✅ Bluetooth açık ve hazır")
                self.connectionState = .disconnected
                // Otomatik tarama başlat
                if self.discoveredDevices.isEmpty && !self.isScanning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.startScanning()
                    }
                }
            case .poweredOff:
                print("❌ Bluetooth kapalı")
                self.stopScanning()
                self.connectionState = .error("Bluetooth kapalı - Ayarlardan açın")
                self.errorManager.handleError(.bluetoothPoweredOff)
            case .resetting:
                print("🔄 Bluetooth yeniden başlatılıyor")
                self.connectionState = .error("Bluetooth yeniden başlatılıyor")
            case .unauthorized:
                print("❌ Bluetooth izni yok")
                self.stopScanning()
                self.connectionState = .error("Bluetooth izni gerekli")
                self.errorManager.handleError(.unauthorized)
            case .unsupported:
                print("❌ Bluetooth desteklenmiyor")
                self.stopScanning()
                self.connectionState = .error("Bluetooth desteklenmiyor")
                self.errorManager.handleError(.unsupported)
            case .unknown:
                print("❓ Bluetooth durumu bilinmiyor - tekrar kontrol ediliyor")
                self.connectionState = .error("Bluetooth durumu kontrol ediliyor...")
                // 2 saniye sonra tekrar kontrol et
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if central.state == .unknown {
                        self.connectionState = .error("Bluetooth durumu belirlenemedi")
                    }
                }
            @unknown default:
                print("❓ Bilinmeyen Bluetooth durumu")
                self.stopScanning()
                self.connectionState = .error("Bilinmeyen Bluetooth durumu")
                self.errorManager.handleError(.bluetoothUnavailable)
            }
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Bilinmeyen Cihaz"
        print("📱 Cihaz bulundu: \(deviceName) (\(peripheral.identifier)), RSSI: \(RSSI)")
        
        let device = BluetoothDevice(peripheral: peripheral, rssi: RSSI)
        
        // Aynı cihazı tekrar ekleme
        if !discoveredDevices.contains(device) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
                print("✅ Cihaz listeye eklendi: \(deviceName)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Cihaza bağlandı: \(peripheral.name ?? "Bilinmeyen")")
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connected
        
        // Servisleri keşfet
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Bilinmeyen hata"
        print("Bağlantı hatası: \(errorMessage)")
        connectionState = .error("Bağlantı kurulamadı")
        errorManager.handleError(.connectionFailed(errorMessage))
        cleanup()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Bağlantı kesildi: \(error?.localizedDescription ?? "Normal kesinti")")
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Servis keşif hatası: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                print("Hedef servis bulundu")
                peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Karakteristik keşif hatası: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case writeCharacteristicUUID:
                writeCharacteristic = characteristic
                print("Yazma karakteristiği bulundu")
                
            case notifyCharacteristicUUID:
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Bildirim karakteristiği bulundu")
            
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Veri okuma hatası: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value,
              let string = String(data: data, encoding: .utf8) else {
            print("Veri UTF8'e çevrilemedi")
            return
        }
        
        // Gelen veriyi buffer'a ekle
        messageBuffer += string
        
        // \n ile ayrılmış mesajları işle
        let lines = messageBuffer.components(separatedBy: "\n")
        messageBuffer = lines.last ?? "" // Son kısmı buffer'da tut
        
        // Tam mesajları işle
        for line in lines.dropLast() {
            if !line.isEmpty {
                DispatchQueue.main.async {
                    self.receivedMessages.append(line)
                    print("Alınan mesaj: \(line)")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Yazma hatası: \(error.localizedDescription)")
            errorManager.handleError(.commandSendFailed(error.localizedDescription))
        } else {
            print("Komut başarıyla gönderildi")
        }
    }
}