// ESP32 IAC BLE firmware - compatible with the iOS app's UUIDs and protocol
// Service UUID:       12345678-1234-1234-1234-123456789abc
// Write Characteristic: 87654321-4321-4321-4321-cba987654321 (Write with response)
// Notify Characteristic: 11111111-2222-3333-4444-555555555555 (Notify)

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <map>

// BLE UUIDs (must match the iOS app)
static BLEUUID SERVICE_UUID("12345678-1234-1234-1234-123456789abc");
static BLEUUID WRITE_CHAR_UUID("87654321-4321-4321-4321-cba987654321");
static BLEUUID NOTIFY_CHAR_UUID("11111111-2222-3333-4444-555555555555");

// BLE objects
BLEServer* g_server = nullptr;
BLEService* g_service = nullptr;
BLECharacteristic* g_writeChar = nullptr;
BLECharacteristic* g_notifyChar = nullptr;

// Device state
bool g_systemRunning = false;

struct ModuleState {
  String name;
  bool isActive = false;
  int errorCode = 0;
};

std::map<String, ModuleState> g_modules; // keyed by moduleId (e.g., "CAN1")

// Simple helpers
static String trimString(const String& s) {
  String out = s;
  out.trim();
  return out;
}

static void sendNotifyLineRaw(const String& lineWithNewline) {
  if (!g_notifyChar) return;
  // Split into smaller chunks to be safe (<= 180 bytes)
  const size_t maxChunk = 180;
  size_t len = lineWithNewline.length();
  for (size_t i = 0; i < len; i += maxChunk) {
    String chunk = lineWithNewline.substring(i, min(i + maxChunk, len));
    g_notifyChar->setValue((uint8_t*)chunk.c_str(), chunk.length());
    g_notifyChar->notify();
    delay(10); // small gap between chunks
  }
}

static void sendNotifyLine(const String& line) {
  // All messages are newline-terminated so the iOS app can parse them by lines
  sendNotifyLineRaw(line + "\n");
}

static ModuleState& ensureModule(const String& moduleId) {
  auto it = g_modules.find(moduleId);
  if (it == g_modules.end()) {
    ModuleState st;
    st.name = moduleId; // default name
    auto res = g_modules.emplace(moduleId, st);
    return res.first->second;
  }
  return it->second;
}

static void handleSystemCommand(const String& cmd) {
  if (cmd == "start_system") {
    g_systemRunning = true;
    sendNotifyLine("GNS:OK");
    sendNotifyLine("MSJ:System started");
  } else if (cmd == "stop_system") {
    g_systemRunning = false;
    sendNotifyLine("GNS:STOPPED");
    sendNotifyLine("MSJ:System stopped");
  } else if (cmd == "get_status") {
    sendNotifyLine(g_systemRunning ? "GNS:OK" : "GNS:STOPPED");
  } else if (cmd == "reset") {
    g_systemRunning = false;
    g_modules.clear();
    sendNotifyLine("GNS:RESET");
    sendNotifyLine("MSJ:System state reset");
  } else {
    // Unknown system command
    sendNotifyLine("MSJ:Unknown system command: " + cmd);
  }
}

static void handleModuleCommand(const String& moduleId, const String& action, const String& value) {
  ModuleState& m = ensureModule(moduleId);

  if (action == "RESET") {
    m.isActive = true;
    m.errorCode = 0;
    // Confirm status so UI shows active
    sendNotifyLine(moduleId + ":durum:ok");
    sendNotifyLine(moduleId + ":hata:0");
    sendNotifyLine("MSJ:" + moduleId + " reset");
    return;
  }

  if (action == "get_log") {
    // Send a couple of demo log lines; UI listens for MSJ: prefix
    sendNotifyLine("MSJ:" + moduleId + " -> log line 1");
    sendNotifyLine("MSJ:" + moduleId + " -> log line 2");
    return;
  }

  if (action == "get_isim") {
    sendNotifyLine(moduleId + ":isim:" + m.name);
    return;
  }

  if (action == "get_durum") {
    sendNotifyLine(moduleId + ":durum:" + String(m.isActive ? "1" : "0"));
    return;
  }

  if (action == "get_hata") {
    sendNotifyLine(moduleId + ":hata:" + String(m.errorCode));
    return;
  }

  if (action == "set_isim") {
    // value holds the new name (may be empty, but UI expects echo via isim)
    m.name = value;
    sendNotifyLine(moduleId + ":isim:" + m.name);
    sendNotifyLine("MSJ:" + moduleId + " name set to '" + m.name + "'");
    return;
  }

  if (action == "set_hata") {
    int code = 0;
    if (value.length() > 0) code = value.toInt();
    m.errorCode = code;
    sendNotifyLine(moduleId + ":hata:" + String(m.errorCode));
    return;
  }

  // Fallback: unknown action
  sendNotifyLine("MSJ:Unknown action for " + moduleId + ": " + action);
}

static void processCommandLine(String line) {
  line = trimString(line);
  if (line.length() == 0) return;

  // System-level commands (no module prefix)
  if (line.indexOf(':') == -1) {
    handleSystemCommand(line);
    return;
  }

  // MODULE:ACTION[:VALUE]
  int firstColon = line.indexOf(':');
  int secondColon = line.indexOf(':', firstColon + 1);

  String moduleId = line.substring(0, firstColon);
  String action = (secondColon == -1) ? line.substring(firstColon + 1) : line.substring(firstColon + 1, secondColon);
  String value = (secondColon == -1) ? "" : line.substring(secondColon + 1);

  moduleId.trim();
  action.trim();
  value.trim();

  if (moduleId.length() == 0 || action.length() == 0) {
    sendNotifyLine("MSJ:Invalid command format: " + line);
    return;
  }

  handleModuleCommand(moduleId, action, value);
}

class WriteCallbacks : public BLECharacteristicCallbacks {
 public:
  void onWrite(BLECharacteristic* pCharacteristic) override {
    // Make compatible with libraries returning either std::string or Arduino String
    String rx = String(pCharacteristic->getValue().c_str());
    if (rx.length() == 0) return;

    // Append to buffer and split by \n
    buffer += rx;

    int newlineIdx = buffer.indexOf('\n');
    while (newlineIdx != -1) {
      String line = buffer.substring(0, newlineIdx);
      // Remove optional carriage return
      if (line.length() > 0 && line.charAt(line.length() - 1) == '\r') {
        line.remove(line.length() - 1);
      }
      processCommandLine(line);
      buffer = buffer.substring(newlineIdx + 1);
      newlineIdx = buffer.indexOf('\n');
    }
  }

 private:
  String buffer;
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    // Optionally adjust connection params/MTU if needed
    // pServer->updateConnParams( /* min*/6, /* max*/12, /* latency*/0, /* timeout*/200 );
  }

  void onDisconnect(BLEServer* pServer) override {
    // Restart advertising so app can reconnect
    BLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("IAC ESP32 BLE starting...");

  BLEDevice::init("IAC-ESP32");
  BLEDevice::setPower(ESP_PWR_LVL_P9); // daha yüksek reklam gücü

  g_server = BLEDevice::createServer();
  g_server->setCallbacks(new ServerCallbacks());

  g_service = g_server->createService(SERVICE_UUID);

  // Write characteristic (Write with response)
  g_writeChar = g_service->createCharacteristic(
      WRITE_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  g_writeChar->setCallbacks(new WriteCallbacks());

  // Notify characteristic
  g_notifyChar = g_service->createCharacteristic(
      NOTIFY_CHAR_UUID,
      BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  g_notifyChar->addDescriptor(new BLE2902()); // enable notifications on iOS

  // Optional: initial value
  g_notifyChar->setValue("IAC Ready\n");

  g_service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);  // helps iOS discoverability
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("Advertising started");
}

void loop() {
  // Periodically send a heartbeat log when system is running
  static uint32_t lastBeat = 0;
  uint32_t now = millis();
  if (g_systemRunning && now - lastBeat > 5000) {
    lastBeat = now;
    sendNotifyLine("MSJ:Heartbeat OK");
  }
  delay(10);
}