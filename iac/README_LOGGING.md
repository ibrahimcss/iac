# ESP32 Komut Loglama Sistemi

Bu dokümantasyon, iOS IAC uygulamasında ESP32 cihazına gönderilen komutların ve alınan yanıtların nasıl loglandığını açıklar.

## Özellikler

### 1. Komut Takibi
- **Gönderilen Komutlar**: ESP32'ye gönderilen tüm komutlar timestamp ile kaydedilir
- **Yanıt Takibi**: Cihazdan gelen yanıtlar otomatik olarak eşleştirilir
- **Timeout Kontrolü**: 10 saniye içinde yanıt alınmayan komutlar timeout olarak işaretlenir

### 2. Log Kategorileri
- **Komut Gönderildi** (🔵): ESP32'ye gönderilen komutlar
- **Yanıt Alındı** (🟢): Cihazdan gelen yanıtlar
- **Sistem Mesajı** (🟣): Genel sistem durumu mesajları
- **Hata** (🔴): Hata mesajları ve timeout'lar
- **Bilgi** (⚪): Genel bilgi mesajları

### 3. Durum Göstergeleri
- **🟠 Bekliyor**: Komut gönderildi, yanıt bekleniyor
- **🟢 Başarılı**: Komut başarıyla tamamlandı
- **🔴 Başarısız**: Komut hata ile sonuçlandı
- **🔴 Timeout**: Yanıt zaman aşımına uğradı

## Kullanım

### Komut Gönderme
```swift
// Sistem komutu
commandProtocol.startSystem()

// Modül komutu
commandProtocol.resetModule("CAN1")

// Özel komut
commandProtocol.sendCustomCommand("custom_command")
```

### Log Görüntüleme
- **Log Sekmesi**: Tüm log kayıtlarını görüntüler
- **Filtreleme**: Komut tipine göre filtreleme yapabilirsiniz
- **Arama**: Komut veya yanıt metnine göre arama yapabilirsiniz
- **İstatistikler**: Komut başarı oranlarını görüntüler

## Teknik Detaylar

### LogEntry Yapısı
```swift
struct LogEntry {
    let timestamp: Date
    let type: LogEntryType
    let command: String?
    let response: String?
    let status: LogStatus
}
```

### Komut Eşleştirme
Sistem, gönderilen komutları ve gelen yanıtları akıllıca eşleştirir:
- Komut metni içeren yanıtlar
- "OK", "SUCCESS" gibi başarı mesajları
- "ERROR", "HATA" gibi hata mesajları

### Otomatik Temizlik
- Son 1000 log kaydı tutulur
- Eski kayıtlar otomatik olarak temizlenir
- Bellek kullanımı optimize edilir

## ESP32 Yanıt Formatları

### Beklenen Yanıt Formatları
```
MODULE:ACTION:VALUE
CAN1:RESET:OK
CAN2:STATUS:ACTIVE
```

### Sistem Mesajları
```
GNS:ONLINE          // Genel sistem durumu
MSJ:Kalibrasyon tamamlandı  // Genel mesaj
```

## Hata Yönetimi

### Timeout Durumu
- Komut gönderildikten 10 saniye sonra yanıt alınmazsa timeout olur
- Timeout durumu log'da kırmızı renk ile gösterilir
- Pending komutlar otomatik olarak temizlenir

### Hata Durumları
- Bluetooth bağlantı hataları
- Komut gönderme hataları
- Yanıt alma hataları

## Performans

### Optimizasyonlar
- Asenkron log işleme
- Otomatik bellek temizliği
- Efisien komut eşleştirme algoritması

### Sınırlar
- Maksimum 1000 log kaydı
- 10 saniye komut timeout
- 1 saniye timeout kontrol aralığı

## Test Etme

Log ekranında "Test Komut" butonuna tıklayarak loglama sistemini test edebilirsiniz. Bu buton `test_command` komutunu gönderir ve log kaydını oluşturur.

## Gelecek Geliştirmeler

- [ ] Log kayıtlarını dosyaya kaydetme
- [ ] Log seviyesi filtreleme (DEBUG, INFO, WARNING, ERROR)
- [ ] Log kayıtlarını dışa aktarma (CSV, JSON)
- [ ] Gerçek zamanlı log analizi
- [ ] Komut performans metrikleri
