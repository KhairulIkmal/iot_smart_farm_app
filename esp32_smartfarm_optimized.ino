// Smart Farm ESP32 — Firebase RTDB + SH1107 OLED (128×128) + Pump Control
// Hardware: ESP32 + DHT11 (GPIO17) + Soil ADC (GPIO36) + pH ADC (GPIO39) + Water Level ADC (GPIO32) + Pump via Motor2 + SH1107 OLED
// Firebase Paths:
//   sensors/ESP32_001/live         — real-time sensor data
//   sensors/ESP32_001/history      — periodic historical data (keyed by timestamp)
//   sensors/ESP32_001/sensorHealth — sensor status (ok/error)
//   commands/ESP32_001             — pump control and settings from app

#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include <math.h>
#include "DHT.h"

// Firebase ESP32 Library
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <time.h> // For NTP time

// ================= Credentials =================
#define WIFI_SSID "Kairi"
#define WIFI_PASSWORD "Ikmal0341"
#define FIREBASE_API_KEY "AIzaSyDKEGXzw8kX7k4YvjjxQF4_4AzZYyH_xmQ"
#define FIREBASE_DB_URL "https://iot-smartfarm-system-default-rtdb.asia-southeast1.firebasedatabase.app"

// ================= Pin map =================
#define PIN_DHT 17
#define DHT_TYPE DHT11
#define PIN_SOIL_ADC 36
#define PIN_PH_ADC 39          // pH sensor analog pin
#define PIN_WATER_LEVEL_ADC 32 // Water level sensor on Grove 5 (D32) - CHANGED FROM ULTRASONIC

// ---- Pump on RoboESP32 Motor2 ----
#define M2_EN -1
#define M2A 14
#define M2B 27

// ================ Water Level Calibration ===============
// CALIBRATION: Adjust these values based on your sensor readings!
// DRY_VALUE: ADC reading when sensor is completely out of water
// WET_VALUE: ADC reading when sensor is fully submerged to max level
#define WATER_LEVEL_DRY 0    // Minimum reading (no water)
#define WATER_LEVEL_WET 2500 // Maximum reading (fully submerged) - CALIBRATE THIS!

// ================ Device ID =================
#define DEVICE_ID "ESP32_001"

// ================ OLED (SH1107) ============
#define OLED_WIDTH 128
#define OLED_HEIGHT 128
Adafruit_SH1107 display(OLED_WIDTH, OLED_HEIGHT, &Wire);

// ================ Firebase =================
FirebaseData fbdo;
FirebaseData streamFbdo; // Separate for stream listener
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;
bool signupOK = false;

// ================ Globals ==================
DHT dht(PIN_DHT, DHT_TYPE);

struct EnvState
{
  float dhtTempC = NAN;
  float dhtHum = NAN;
  int soilRaw = 0;
  int soilPct = -1;
  float phValue = NAN;
  int waterLevelRaw = 0; // CHANGED: Store raw ADC value for water level
  int tankPct = -1;
  bool pumpOn = false;
  String lastErr;
} S;

struct SensorHealth
{
  String soil = "ok";
  String ph = "ok";
  String waterLevel = "ok";
  String temp = "ok";
  String humidity = "ok";
  bool changed = true;
} health;

// Command state from Firebase
struct CommandState
{
  String mode = "manual";
  bool pumpCmd = false;
  int soilThreshLow = 30;
  int soilThreshHigh = 50;
  int minWaterLevel = 15;
  uint32_t updatedAt = 0;
} CMD;

// ========= Timing intervals (ms) =========
// IMPORTANT: Split heartbeat from sensor data!
#define INTERVAL_HEARTBEAT 2000     // Send lastSeen every 2 seconds (fast offline detection)
#define INTERVAL_SENSORS 5000       // Read & push sensor data every 5 seconds
#define INTERVAL_HISTORY 300000     // Push history every 5 min
#define INTERVAL_OLED 1200          // Refresh OLED
#define INTERVAL_AUTO 1000          // Auto-water check
#define INTERVAL_SCREEN_ROTATE 4000 // Screen rotation every 4 seconds

uint32_t lastHeartbeat = 0; // NEW: separate heartbeat timer
uint32_t lastSensorPush = 0;
uint32_t lastHistoryPush = 0;
uint32_t lastSensorRead = 0;
uint32_t lastOLED = 0;
uint32_t lastAutoCheck = 0;
uint32_t lastScreenRotate = 0;
int currentScreen = 0; // 0 = Device Status, 1 = Sensors, 2 = Irrigation, 3 = System Status

// ------------- Sensor Helpers ----------------
int mapSoilToPercent(int raw, int dry = 3300, int wet = 1200)
{
  if (raw < wet)
    raw = wet;
  if (raw > dry)
    raw = dry;
  return map(raw, dry, wet, 0, 100);
}

float readPH(int raw)
{
  float voltage = raw * (3.3 / 4095.0);
  float ph = 3.5 * voltage + 0.0;
  if (ph < 0 || ph > 14)
    return NAN;
  return ph;
}

// CHANGED: New function for analog water level sensor (replaces ultrasonic)
int readWaterLevelPercent(int raw)
{
  // Map raw ADC value to percentage
  // More water = higher ADC reading = higher percentage
  int pct = map(raw, WATER_LEVEL_DRY, WATER_LEVEL_WET, 0, 100);
  pct = constrain(pct, 0, 100);
  return pct;
}

// ------------- Sensor Health Check ----------------
#define ADC_DISCONNECT_LOW 50
#define ADC_DISCONNECT_HIGH 4000

void updateSensorHealth()
{
  String oldSoil = health.soil;
  String oldPh = health.ph;
  String oldWater = health.waterLevel;
  String oldTemp = health.temp;
  String oldHum = health.humidity;

  // Soil sensor
  if (S.soilRaw < ADC_DISCONNECT_LOW || S.soilRaw > ADC_DISCONNECT_HIGH)
  {
    health.soil = "error";
  }
  else if (S.soilPct >= 0 && S.soilPct <= 100)
  {
    health.soil = "ok";
  }
  else
  {
    health.soil = "error";
  }

  // pH sensor
  int phRaw = analogRead(PIN_PH_ADC);
  if (phRaw < ADC_DISCONNECT_LOW || phRaw > ADC_DISCONNECT_HIGH)
  {
    health.ph = "error";
  }
  else if (!isnan(S.phValue) && S.phValue >= 0 && S.phValue <= 14)
  {
    health.ph = "ok";
  }
  else
  {
    health.ph = "error";
  }

  // CHANGED: Water level sensor health check (now analog instead of ultrasonic)
  if (S.waterLevelRaw < ADC_DISCONNECT_LOW || S.waterLevelRaw > ADC_DISCONNECT_HIGH)
  {
    health.waterLevel = "error";
  }
  else if (S.tankPct >= 0 && S.tankPct <= 100)
  {
    health.waterLevel = "ok";
  }
  else
  {
    health.waterLevel = "error";
  }

  // Temperature
  if (isnan(S.dhtTempC))
  {
    health.temp = "error";
  }
  else
  {
    health.temp = "ok";
  }

  // Humidity
  if (isnan(S.dhtHum))
  {
    health.humidity = "error";
  }
  else
  {
    health.humidity = "ok";
  }

  if (health.soil != oldSoil || health.ph != oldPh ||
      health.waterLevel != oldWater || health.temp != oldTemp ||
      health.humidity != oldHum)
  {
    health.changed = true;
  }
}

// --------- Motor2 (pump) control ----------
void pumpInit()
{
  pinMode(M2A, OUTPUT);
  pinMode(M2B, OUTPUT);
  digitalWrite(M2A, LOW);
  digitalWrite(M2B, LOW);
  if (M2_EN >= 0)
  {
    pinMode(M2_EN, OUTPUT);
    digitalWrite(M2_EN, HIGH);
  }
}

void pumpOn()
{
  digitalWrite(M2A, HIGH);
  digitalWrite(M2B, LOW);
  S.pumpOn = true;
  Serial.println("[PUMP] ON");
}

void pumpOff()
{
  digitalWrite(M2A, LOW);
  digitalWrite(M2B, LOW);
  S.pumpOn = false;
  Serial.println("[PUMP] OFF");
}

// ---------- Command Execution ----------
void executeCommands()
{
  if (CMD.mode == "manual")
  {
    if (CMD.pumpCmd && !S.pumpOn)
    {
      pumpOn();
    }
    else if (!CMD.pumpCmd && S.pumpOn)
    {
      pumpOff();
    }
  }
  else if (CMD.mode == "auto")
  {
    if (S.tankPct >= 0 && S.tankPct < CMD.minWaterLevel)
    {
      if (S.pumpOn)
        pumpOff();
      return;
    }
    if (S.soilPct >= 0)
    {
      if (S.soilPct < CMD.soilThreshLow && !S.pumpOn)
      {
        pumpOn();
      }
      else if (S.soilPct >= CMD.soilThreshHigh && S.pumpOn)
      {
        pumpOff();
      }
    }
  }
}

// ---------- Firebase Stream Callback ----------
void streamCallback(FirebaseStream data)
{
  Serial.printf("[STREAM] Path: %s, Type: %s\n", data.dataPath().c_str(), data.dataType().c_str());

  String path = data.dataPath();

  if (data.dataTypeEnum() == fb_esp_rtdb_data_type_json)
  {
    FirebaseJson json = data.jsonObject();
    FirebaseJsonData result;

    if (json.get(result, "mode") && result.success)
    {
      CMD.mode = result.to<String>();
      Serial.printf("[CMD] Mode: %s\n", CMD.mode.c_str());
    }
    if (json.get(result, "pump") && result.success)
    {
      if (result.typeNum == FirebaseJson::JSON_STRING)
      {
        String pumpStr = result.to<String>();
        CMD.pumpCmd = (pumpStr == "on");
      }
      else if (result.typeNum == FirebaseJson::JSON_BOOL)
      {
        CMD.pumpCmd = result.to<bool>();
      }
      Serial.printf("[CMD] Pump: %s\n", CMD.pumpCmd ? "ON" : "OFF");
    }
    if (json.get(result, "soilThreshLow") && result.success)
    {
      CMD.soilThreshLow = result.to<int>();
    }
    if (json.get(result, "soilThreshHigh") && result.success)
    {
      CMD.soilThreshHigh = result.to<int>();
    }
    if (json.get(result, "minWaterLevel") && result.success)
    {
      CMD.minWaterLevel = result.to<int>();
    }
  }
  else
  {
    if (path == "/mode")
    {
      CMD.mode = data.stringData();
    }
    else if (path == "/pump")
    {
      if (data.dataTypeEnum() == fb_esp_rtdb_data_type_string)
      {
        CMD.pumpCmd = (data.stringData() == "on");
      }
      else if (data.dataTypeEnum() == fb_esp_rtdb_data_type_boolean)
      {
        CMD.pumpCmd = data.boolData();
      }
    }
    else if (path == "/soilThreshLow")
    {
      CMD.soilThreshLow = data.intData();
    }
    else if (path == "/soilThreshHigh")
    {
      CMD.soilThreshHigh = data.intData();
    }
    else if (path == "/minWaterLevel")
    {
      CMD.minWaterLevel = data.intData();
    }
  }

  Serial.printf("[CMD] mode=%s, pump=%d, low=%d, high=%d\n",
                CMD.mode.c_str(), CMD.pumpCmd, CMD.soilThreshLow, CMD.soilThreshHigh);
}

void streamTimeoutCallback(bool timeout)
{
  if (timeout)
  {
    Serial.println("[STREAM] Timeout, reconnecting...");
  }
  if (!streamFbdo.httpConnected())
  {
    Serial.printf("[STREAM] Error: %s\n", streamFbdo.errorReason().c_str());
  }
}

// ========== NEW: Separate Heartbeat Function ==========
// Only updates lastSeen - very lightweight!
void pushHeartbeat()
{
  if (!firebaseReady || !signupOK)
    return;

  String path = "sensors/" DEVICE_ID "/live/lastSeen";

  // Use Firebase server timestamp for accuracy
  if (Firebase.RTDB.setTimestamp(&fbdo, path.c_str()))
  {
    Serial.println("[FB] Heartbeat sent");
  }
  else
  {
    Serial.printf("[FB] Heartbeat failed: %s\n", fbdo.errorReason().c_str());
  }
}

// ========== Push Full Sensor Data (includes lastSeen too) ==========
void pushSensorData()
{
  if (!firebaseReady || !signupOK)
    return;

  String path = "sensors/" DEVICE_ID "/live";

  FirebaseJson json;
  json.set("temp", isnan(S.dhtTempC) ? 0 : (int)roundf(S.dhtTempC));
  json.set("humidity", isnan(S.dhtHum) ? 0 : (int)roundf(S.dhtHum));
  json.set("soil", S.soilPct >= 0 ? S.soilPct : 0);
  json.set("ph", isnan(S.phValue) ? 0.0 : S.phValue);
  json.set("waterLevel", S.tankPct >= 0 ? S.tankPct : 0);
  json.set("pumpOn", S.pumpOn);
  json.set("mode", CMD.mode);
  json.set("lastSeen/.sv", "timestamp");
  json.set("timestamp/.sv", "timestamp"); // For web admin compatibility

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json))
  {
    Serial.println("[FB] Sensor data pushed");
  }
  else
  {
    Serial.printf("[FB] Sensor push failed: %s\n", fbdo.errorReason().c_str());
    S.lastErr = fbdo.errorReason();
  }
}

void pushHistoryData()
{
  if (!firebaseReady || !signupOK)
    return;

  time_t now = time(nullptr);
  if (now < 1000000000)
  {
    now = (millis() / 1000) + 1700000000UL;
  }

  String basePath = "sensors/" DEVICE_ID "/history/";

  if (!isnan(S.dhtTempC))
  {
    Firebase.RTDB.setInt(&fbdo, (basePath + "temp/" + String((unsigned long)now)).c_str(), (int)S.dhtTempC);
  }
  if (!isnan(S.dhtHum))
  {
    Firebase.RTDB.setInt(&fbdo, (basePath + "humidity/" + String((unsigned long)now)).c_str(), (int)S.dhtHum);
  }
  if (S.soilPct >= 0)
  {
    Firebase.RTDB.setInt(&fbdo, (basePath + "soil/" + String((unsigned long)now)).c_str(), S.soilPct);
  }
  if (!isnan(S.phValue))
  {
    Firebase.RTDB.setFloat(&fbdo, (basePath + "ph/" + String((unsigned long)now)).c_str(), S.phValue);
  }
  if (S.tankPct >= 0)
  {
    Firebase.RTDB.setInt(&fbdo, (basePath + "waterLevel/" + String((unsigned long)now)).c_str(), S.tankPct);
  }

  Serial.println("[FB] History pushed");
}

void pushSensorHealth()
{
  if (!firebaseReady || !health.changed)
    return;

  String path = "sensors/" DEVICE_ID "/sensorHealth";

  FirebaseJson json;
  json.set("soil", health.soil);
  json.set("ph", health.ph);
  json.set("waterLevel", health.waterLevel);
  json.set("temp", health.temp);
  json.set("humidity", health.humidity);

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json))
  {
    Serial.println("[FB] Health pushed");
    health.changed = false;
  }
}

// ========================= OLED UI =========================
// Modern 16x16 Icons for better visibility
const uint8_t ICON_WIFI[] PROGMEM = {
    0x00, 0x00, 0x07, 0xE0, 0x1F, 0xF8, 0x3E, 0x7C, 0x78, 0x1E, 0x61, 0x86,
    0x07, 0xE0, 0x0F, 0xF0, 0x1C, 0x38, 0x01, 0x80, 0x03, 0xC0, 0x03, 0xC0,
    0x00, 0x00, 0x01, 0x80, 0x01, 0x80, 0x00, 0x00};

const uint8_t ICON_CLOUD[] PROGMEM = {
    0x00, 0x00, 0x00, 0x00, 0x03, 0x80, 0x0C, 0x60, 0x10, 0x10, 0x20, 0x08,
    0x47, 0xC4, 0x58, 0x34, 0xA0, 0x0A, 0xA0, 0x0A, 0xA0, 0x0A, 0x50, 0x14,
    0x4F, 0xE4, 0x20, 0x08, 0x1F, 0xF0, 0x00, 0x00};

const uint8_t ICON_SOIL[] PROGMEM = {
    0x00, 0x00, 0x08, 0x10, 0x14, 0x28, 0x22, 0x44, 0x41, 0x82, 0x80, 0x01,
    0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0xFF, 0xFF,
    0xAA, 0xAA, 0x55, 0x55, 0xFF, 0xFF, 0x00, 0x00};

const uint8_t ICON_TEMP[] PROGMEM = {
    0x00, 0x00, 0x03, 0x00, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80,
    0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0x0E, 0xE0, 0x1F, 0xF0, 0x1F, 0xF0,
    0x1F, 0xF0, 0x0E, 0xE0, 0x04, 0x40, 0x00, 0x00};

const uint8_t ICON_WATER[] PROGMEM = {
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x80, 0x02, 0x80, 0x04, 0x40,
    0x04, 0x40, 0x08, 0x20, 0x10, 0x10, 0x20, 0x08, 0x40, 0x04, 0x40, 0x04,
    0x40, 0x04, 0x20, 0x08, 0x1F, 0xF0, 0x00, 0x00};

const uint8_t ICON_PH[] PROGMEM = {
    0x00, 0x00, 0x7E, 0x00, 0x63, 0x00, 0x63, 0x00, 0x63, 0x00, 0x7E, 0x00,
    0x60, 0x00, 0x60, 0x00, 0x60, 0x00, 0x60, 0x00, 0x60, 0x00, 0x60, 0x00,
    0x60, 0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t ICON_PUMP[] PROGMEM = {
    0x00, 0x00, 0x1F, 0xF8, 0x10, 0x08, 0x13, 0xC8, 0x12, 0x48, 0x12, 0x48,
    0x13, 0xC8, 0x10, 0x08, 0x1F, 0xF8, 0x01, 0x00, 0x01, 0x00, 0x7F, 0xFE,
    0x55, 0x54, 0x55, 0x54, 0x7F, 0xFE, 0x00, 0x00};

const uint8_t ICON_AUTO[] PROGMEM = {
    0x00, 0x00, 0x01, 0x80, 0x03, 0xC0, 0x07, 0xE0, 0x0D, 0xB0, 0x18, 0x18,
    0x30, 0x0C, 0x60, 0x06, 0x60, 0x06, 0x60, 0x06, 0x60, 0x06, 0x30, 0x0C,
    0x18, 0x18, 0x0F, 0xF0, 0x00, 0x00, 0x00, 0x00};

const uint8_t ICON_WARNING[] PROGMEM = {
    0x00, 0x00, 0x01, 0x80, 0x03, 0xC0, 0x03, 0xC0, 0x06, 0x60, 0x06, 0x60,
    0x0C, 0x30, 0x0C, 0x30, 0x18, 0x18, 0x18, 0x18, 0x30, 0x0C, 0x30, 0x0C,
    0x7F, 0xFE, 0x7F, 0xFE, 0xFF, 0xFF, 0x00, 0x00};

const uint8_t ICON_CHECK[] PROGMEM = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x06, 0x00, 0x0C,
    0x40, 0x18, 0x60, 0x30, 0x30, 0x60, 0x18, 0xC0, 0x0D, 0x80, 0x07, 0x00,
    0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

// Helper functions
inline String fmtIntOrDash(int v) { return v >= 0 ? String(v) : String("--"); }
inline String fmtFloat0OrDash(float f) { return isnan(f) ? String("--") : String((int)roundf(f)); }
inline String fmtFloat1OrDash(float f) { return isnan(f) ? String("--") : String(f, 1); }

// Check if any sensor has error
bool hasAnyError()
{
  return (health.soil != "ok" || health.ph != "ok" || health.waterLevel != "ok" ||
          health.temp != "ok" || health.humidity != "ok" || S.lastErr.length() > 0 ||
          !firebaseReady);
}

// Draw centered text
void drawCenteredText(const char *text, int y, int textSize = 1)
{
  display.setTextSize(textSize);
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((128 - w) / 2, y);
  display.print(text);
}

// Draw progress bar
void drawProgressBar(int16_t x, int16_t y, int16_t w, int16_t h, int pct)
{
  if (pct < 0)
    pct = 0;
  if (pct > 100)
    pct = 100;
  int fillw = (w - 2) * pct / 100;
  display.drawRect(x, y, w, h, SH110X_WHITE);
  display.fillRect(x + 1, y + 1, fillw, h - 2, SH110X_WHITE);
}

// ========== SCREEN 1: DEVICE STATUS ==========
void drawScreen1_DeviceStatus()
{
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);

  // Header
  drawCenteredText("IoT Smart Farm", 5, 1);
  display.drawLine(10, 18, 118, 18, SH110X_WHITE);

  display.setTextSize(1);
  display.setCursor(35, 22);
  display.print(DEVICE_ID);

  // WiFi Status
  display.drawBitmap(20, 40, ICON_WIFI, 16, 16, SH110X_WHITE);
  display.setTextSize(1);
  display.setCursor(40, 43);
  display.print("WiFi: ");
  display.print(WiFi.status() == WL_CONNECTED ? "ONLINE" : "OFFLINE");

  // Cloud Status
  display.drawBitmap(20, 60, ICON_CLOUD, 16, 16, SH110X_WHITE);
  display.setCursor(40, 63);
  display.print("Cloud: ");
  display.print(firebaseReady ? "ONLINE" : "OFFLINE");

  // Last Sync
  display.drawBitmap(20, 80, ICON_CHECK, 16, 16, SH110X_WHITE);
  display.setCursor(40, 83);
  display.print("Sync: ");
  display.print(S.lastErr.length() ? "ERROR" : "OK");

  // Screen indicator
  display.setTextSize(1);
  display.setCursor(56, 115);
  display.print("1/4");

  display.display();
}

// ========== SCREEN 2: SENSOR SUMMARY ==========
void drawScreen2_Sensors()
{
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);

  // Header
  drawCenteredText("Sensor Status", 5, 1);
  display.drawLine(10, 18, 118, 18, SH110X_WHITE);

  int y = 25;

  // Soil Moisture
  display.drawBitmap(5, y, ICON_SOIL, 16, 16, SH110X_WHITE);
  display.setTextSize(1);
  display.setCursor(25, y + 4);
  display.print("Soil: ");
  display.print(fmtIntOrDash(S.soilPct));
  display.print("%");
  display.setCursor(80, y + 4);
  display.print(health.soil == "ok" ? "[OK]" : "[ERR]");
  y += 20;

  // Temperature
  display.drawBitmap(5, y, ICON_TEMP, 16, 16, SH110X_WHITE);
  display.setCursor(25, y + 4);
  display.print("Temp: ");
  display.print(fmtFloat0OrDash(S.dhtTempC));
  display.print("C");
  display.setCursor(80, y + 4);
  display.print(health.temp == "ok" ? "[OK]" : "[ERR]");
  y += 20;

  // pH Level
  display.drawBitmap(5, y, ICON_PH, 16, 16, SH110X_WHITE);
  display.setCursor(25, y + 4);
  display.print("pH: ");
  display.print(fmtFloat1OrDash(S.phValue));
  display.setCursor(80, y + 4);
  display.print(health.ph == "ok" ? "[OK]" : "[ERR]");
  y += 20;

  // Water Level
  display.drawBitmap(5, y, ICON_WATER, 16, 16, SH110X_WHITE);
  display.setCursor(25, y + 4);
  display.print("Water: ");
  display.print(fmtIntOrDash(S.tankPct));
  display.print("%");
  display.setCursor(80, y + 4);
  display.print(health.waterLevel == "ok" ? "[OK]" : "[ERR]");

  // Screen indicator
  display.setTextSize(1);
  display.setCursor(56, 115);
  display.print("2/4");

  display.display();
}

// ========== SCREEN 3: IRRIGATION STATUS (MODERN UI) ==========
void drawScreen3_Irrigation()
{
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);

  // Header
  drawCenteredText("Irrigation", 5, 1);
  display.drawLine(10, 18, 118, 18, SH110X_WHITE);

  // ===== MODE CARD (Left) =====
  int cardY = 25;
  display.drawRoundRect(5, cardY, 58, 40, 4, SH110X_WHITE);

  // Mode icon (centered in card)
  if (CMD.mode == "auto")
  {
    display.drawBitmap(26, cardY + 5, ICON_AUTO, 16, 16, SH110X_WHITE);
  }
  else
  {
    display.drawBitmap(26, cardY + 5, ICON_PUMP, 16, 16, SH110X_WHITE);
  }

  // Mode text
  display.setTextSize(1);
  const char *modeText = CMD.mode == "auto" ? "AUTO" : "MANUAL";
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(modeText, 0, 0, &x1, &y1, &w, &h);
  display.setCursor(5 + (58 - w) / 2, cardY + 28);
  display.print(modeText);

  // ===== PUMP STATUS CARD (Right) =====
  display.drawRoundRect(65, cardY, 58, 40, 4, SH110X_WHITE);

  // Pump icon with animation effect (filled if ON)
  if (S.pumpOn)
  {
    // Draw filled pump icon when active
    display.fillRoundRect(66, cardY + 1, 56, 38, 3, SH110X_WHITE);
    display.drawBitmap(86, cardY + 5, ICON_PUMP, 16, 16, SH110X_BLACK);
    display.setTextColor(SH110X_BLACK);
  }
  else
  {
    display.drawBitmap(86, cardY + 5, ICON_PUMP, 16, 16, SH110X_WHITE);
    display.setTextColor(SH110X_WHITE);
  }

  // Pump status text
  const char *pumpText = S.pumpOn ? "ON" : "OFF";
  display.getTextBounds(pumpText, 0, 0, &x1, &y1, &w, &h);
  display.setCursor(65 + (58 - w) / 2, cardY + 28);
  display.print(pumpText);
  display.setTextColor(SH110X_WHITE); // Reset color

  // ===== STATUS INFO PANEL =====
  int infoY = 70;
  display.drawRoundRect(5, infoY, 118, 35, 4, SH110X_WHITE);

  display.setTextSize(1);
  if (CMD.mode == "auto")
  {
    // Show auto mode details
    display.setCursor(10, infoY + 5);
    display.print("Soil Range:");
    display.setCursor(75, infoY + 5);
    display.printf("%d-%d%%", CMD.soilThreshLow, CMD.soilThreshHigh);

    display.setCursor(10, infoY + 15);
    display.print("Current:");
    display.setCursor(75, infoY + 15);
    display.print(fmtIntOrDash(S.soilPct));
    display.print("%");

    display.setCursor(10, infoY + 25);
    display.print("Status:");
    display.setCursor(55, infoY + 25);

    // Smart status message
    if (S.tankPct >= 0 && S.tankPct < CMD.minWaterLevel)
    {
      display.print("Low Tank!");
    }
    else if (S.pumpOn)
    {
      display.print("Watering");
    }
    else if (S.soilPct >= CMD.soilThreshHigh)
    {
      display.print("Soil OK");
    }
    else if (S.soilPct >= CMD.soilThreshLow)
    {
      display.print("Waiting");
    }
    else
    {
      display.print("Ready");
    }
  }
  else
  {
    // Manual mode info
    display.setCursor(10, infoY + 5);
    display.print("Control: Manual");

    display.setCursor(10, infoY + 17);
    display.print("User operated pump");

    display.setCursor(10, infoY + 27);
    if (S.pumpOn)
    {
      display.print(">> Pump running");
    }
    else
    {
      display.print("Standby mode");
    }
  }

  // Screen indicator
  display.setTextSize(1);
  display.setCursor(56, 115);
  display.print("3/4");

  display.display();
}

// ========== SCREEN 4: SYSTEM STATUS ==========
void drawScreen4_Error()
{
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);

  // Check if there are any errors
  bool hasErrors = hasAnyError();

  if (hasErrors)
  {
    // Warning Icon
    display.drawBitmap(56, 10, ICON_WARNING, 16, 16, SH110X_WHITE);
    drawCenteredText("WARNING", 32, 2);
  }
  else
  {
    // Check Icon
    display.drawBitmap(56, 10, ICON_CHECK, 16, 16, SH110X_WHITE);
    drawCenteredText("ALL OK", 32, 2);
  }

  // Draw box for status message
  display.drawRoundRect(5, 55, 118, 60, 4, SH110X_WHITE);

  display.setTextSize(1);
  int y = 62;

  // Show first error found, or "All Systems OK"
  if (health.soil != "ok")
  {
    display.setCursor(12, y);
    display.print("Soil Sensor");
    display.setCursor(12, y + 10);
    display.print("ERROR");
  }
  else if (health.ph != "ok")
  {
    display.setCursor(12, y);
    display.print("pH Sensor");
    display.setCursor(12, y + 10);
    display.print("ERROR");
  }
  else if (health.waterLevel != "ok")
  {
    display.setCursor(12, y);
    display.print("Water Sensor");
    display.setCursor(12, y + 10);
    display.print("ERROR");
  }
  else if (health.temp != "ok")
  {
    display.setCursor(12, y);
    display.print("Temp Sensor");
    display.setCursor(12, y + 10);
    display.print("ERROR");
  }
  else if (health.humidity != "ok")
  {
    display.setCursor(12, y);
    display.print("Humidity Sensor");
    display.setCursor(12, y + 10);
    display.print("ERROR");
  }
  else if (!firebaseReady)
  {
    display.setCursor(12, y);
    display.print("Cloud Offline");
    display.setCursor(12, y + 10);
    display.print("Check Connection");
  }
  else if (S.lastErr.length())
  {
    display.setCursor(12, y);
    display.print("System Error");
    display.setCursor(12, y + 10);
    String errMsg = S.lastErr.substring(0, 14);
    display.print(errMsg);
  }
  else
  {
    // All systems OK
    display.setCursor(12, y);
    display.print("All Systems");
    display.setCursor(12, y + 10);
    display.print("Operational");
    display.setCursor(12, y + 25);
    display.print("No Errors");
  }

  // Screen indicator
  display.setTextSize(1);
  display.setCursor(56, 115);
  display.print("4/4");

  display.display();
}

// ========== MAIN OLED DRAW FUNCTION ==========
void drawOLED()
{
  // All screens have equal priority - continuous rotation
  // Rotation: 0 -> 1 -> 2 -> 3 -> 0 (Device -> Sensors -> Irrigation -> Error)
  switch (currentScreen)
  {
  case 0:
    drawScreen1_DeviceStatus();
    break;
  case 1:
    drawScreen2_Sensors();
    break;
  case 2:
    drawScreen3_Irrigation();
    break;
  case 3:
    drawScreen4_Error();
    break;
  default:
    currentScreen = 0;
    drawScreen1_DeviceStatus();
    break;
  }
}

// ------------- Setup --------------
void setup()
{
  Serial.begin(115200);
  Serial.println("\n[BOOT] Smart Farm Starting...");

  // CHANGED: Setup for analog water level sensor (removed ultrasonic pin setup)
  pinMode(PIN_WATER_LEVEL_ADC, INPUT);
  pinMode(PIN_SOIL_ADC, INPUT);
  pinMode(PIN_PH_ADC, INPUT);

  // OLED
  Wire.begin(21, 22);
  display.begin(0x3C, true);
  display.setRotation(1);
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setTextWrap(false);
  display.setCursor(0, 0);
  display.print("Smart Farm Boot...");
  display.display();

  dht.begin();
  pumpInit();

  // Wi-Fi
  display.setCursor(0, 16);
  display.print("Connecting WiFi...");
  display.display();

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Connecting");
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 30)
  {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    display.setCursor(0, 32);
    display.print("WiFi: OK");
    display.display();

    // Initialize NTP
    configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    Serial.println("[NTP] Syncing time...");

    int ntpRetry = 0;
    while (time(nullptr) < 1000000000 && ntpRetry < 10)
    {
      delay(500);
      ntpRetry++;
    }
    if (time(nullptr) > 1000000000)
    {
      Serial.printf("[NTP] Time synced: %ld\n", time(nullptr));
    }
    else
    {
      Serial.println("[NTP] Sync failed, using fallback");
    }
  }
  else
  {
    Serial.println("\n[WiFi] FAILED!");
    display.setCursor(0, 32);
    display.print("WiFi: FAIL");
    display.display();
    return;
  }

  // Firebase setup
  display.setCursor(0, 48);
  display.print("Firebase...");
  display.display();

  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DB_URL;
  config.token_status_callback = tokenStatusCallback;

  // Email/Password Authentication
  // IMPORTANT: Create this user in Firebase Console → Authentication → Users first!
  // Email: esp32_device@smartfarm.com
  // Password: YourStrongPassword123
  auth.user.email = "esp32_device@smartfarm.com"; // Change this to your actual email
  auth.user.password = "esp32_pass";              // Change this to your actual password

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("[FB] Signing in with email/password...");
  signupOK = true; // Set to true when using existing credentials

  unsigned long fbStart = millis();
  while (!Firebase.ready() && (millis() - fbStart < 15000))
  {
    delay(200);
    Serial.print(".");
  }
  Serial.println();

  if (Firebase.ready())
  {
    firebaseReady = true;
    Serial.println("[FB] Ready!");

    String cmdPath = "commands/" DEVICE_ID;
    if (!Firebase.RTDB.beginStream(&streamFbdo, cmdPath.c_str()))
    {
      Serial.printf("[FB] Stream failed: %s\n", streamFbdo.errorReason().c_str());
    }
    else
    {
      Firebase.RTDB.setStreamCallback(&streamFbdo, streamCallback, streamTimeoutCallback);
      Serial.println("[FB] Stream started");
    }
  }
  else
  {
    Serial.println("[FB] NOT READY!");
    S.lastErr = "FB not ready";
  }

  display.setCursor(0, 64);
  display.print(firebaseReady ? "Firebase: OK" : "Firebase: FAIL");
  display.display();

  delay(1500);
  drawOLED();
}

// ========== Main Loop - Split Heartbeat & Sensor Updates ==========
void loop()
{
  uint32_t now = millis();

  // 1. HEARTBEAT - Every 2 seconds (fast offline detection)
  if (now - lastHeartbeat >= INTERVAL_HEARTBEAT)
  {
    lastHeartbeat = now;
    pushHeartbeat(); // Only updates lastSeen field
  }

  // 2. READ SENSORS - Every 5 seconds
  if (now - lastSensorRead >= INTERVAL_SENSORS)
  {
    lastSensorRead = now;

    S.dhtTempC = dht.readTemperature();
    S.dhtHum = dht.readHumidity();

    S.soilRaw = analogRead(PIN_SOIL_ADC);
    if (S.soilRaw < 50 || S.soilRaw > 4000)
    {
      S.soilPct = -1;
    }
    else
    {
      S.soilPct = mapSoilToPercent(S.soilRaw);
    }

    int phRaw = analogRead(PIN_PH_ADC);
    if (phRaw < 50 || phRaw > 4000)
    {
      S.phValue = NAN;
    }
    else
    {
      S.phValue = readPH(phRaw);
    }

    // CHANGED: Read analog water level sensor (replaced ultrasonic)
    S.waterLevelRaw = analogRead(PIN_WATER_LEVEL_ADC);
    if (S.waterLevelRaw < 50 || S.waterLevelRaw > 4000)
    {
      S.tankPct = -1;
    }
    else
    {
      S.tankPct = readWaterLevelPercent(S.waterLevelRaw);
    }

    // Debug output for calibration
    Serial.printf("[WATER] Raw: %d, Percent: %d%%\n", S.waterLevelRaw, S.tankPct);

    updateSensorHealth();
  }

  // 3. PUSH SENSOR DATA - Every 5 seconds (includes all sensor values)
  if (now - lastSensorPush >= INTERVAL_SENSORS)
  {
    lastSensorPush = now;
    if (firebaseReady && signupOK)
    {
      pushSensorData();   // Pushes temp, humidity, soil, pH, waterLevel, pump, mode
      pushSensorHealth(); // Pushes sensor health if changed
    }
  }

  // 4. AUTO CONTROL - Every 1 second
  if (now - lastAutoCheck >= INTERVAL_AUTO)
  {
    lastAutoCheck = now;
    executeCommands();
  }

  // 5. HISTORY - Every 5 minutes
  if (now - lastHistoryPush >= INTERVAL_HISTORY)
  {
    lastHistoryPush = now;
    if (firebaseReady && signupOK)
    {
      pushHistoryData();
    }
  }

  // 6. SCREEN ROTATION - Every 4 seconds
  if (now - lastScreenRotate >= INTERVAL_SCREEN_ROTATE)
  {
    lastScreenRotate = now;
    // Rotate through all 4 screens: 0 -> 1 -> 2 -> 3 -> 0
    currentScreen = (currentScreen + 1) % 4;
  }

  // 7. OLED UPDATE - Every 1.2 seconds
  if (now - lastOLED >= INTERVAL_OLED)
  {
    lastOLED = now;
    drawOLED();
  }
}
