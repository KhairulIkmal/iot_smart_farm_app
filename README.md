# IoT Smart Farm

![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)
![ESP32](https://img.shields.io/badge/ESP32-Arduino-E7352C?logo=arduino)
![Claude AI](https://img.shields.io/badge/Claude_AI-Haiku-8B5CF6)
![PutraHack 2026](https://img.shields.io/badge/PutraHack_2026-Food_Security-2D6A4F)

> Real-time IoT-powered farm monitoring and intelligent crop advisory for sustainable food production.

---

## Problem Statement

Over 800 million people face food insecurity globally, yet smallholder farmers — who produce 70% of the world's food — lack access to affordable, real-time tools to monitor and manage their crops. Inefficient irrigation, undetected soil degradation, and poor crop decisions lead to significant yield loss and resource waste.

**IoT Smart Farm** addresses this by putting precision agriculture in the hands of every farmer through a mobile app, low-cost IoT hardware, and AI-powered advisory — all connected through the cloud.

---

## Solution

A complete farm monitoring and control system consisting of:

- **Flutter mobile app** — real-time sensor dashboard, irrigation control, AI crop advisor
- **ESP32 IoT hardware** — soil, pH, temperature, humidity, and water level sensors with pump control
- **Firebase backend** — live data streaming, push notifications, and persistent storage
- **Claude AI integration** — natural language crop advisory with live sensor context

---

## Features

| Feature | Description |
|---------|-------------|
| Real-Time Dashboard | Live sensor readings updated every 5 seconds via Firebase RTDB |
| Irrigation Control | Manual pump control + AI-threshold-based auto-irrigation mode |
| AI Crop Advisor | Claude-powered chatbot with live sensor context for actionable advice |
| Weather Integration | OpenWeatherMap hourly + weekly forecast per farm location |
| Crop Management | Multi-crop support, device claiming, and crop profile editing |
| Push Notifications | FCM alerts for critical soil, pH, and water level conditions |
| Farm Location | GPS-based farm mapping with flutter_map |
| Sensor Health | Per-sensor health status monitoring (ok / error) |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                           │
│   Dashboard │ Sensors │ Irrigation │ AI Advisor │ Weather   │
└──────────────────────┬──────────────────────────────────────┘
                       │ Firebase SDK
         ┌─────────────┴──────────────┐
         │                            │
┌────────▼────────┐        ┌──────────▼──────────┐
│  Firebase RTDB  │        │  Cloud Firestore     │
│  (live sensors  │        │  (users, crops,      │
│   & commands)   │        │   irrigation rules)  │
└────────▲────────┘        └─────────────────────┘
         │ WiFi
┌────────┴────────────────────────────────────────┐
│                   ESP32 Hardware                 │
│  DHT11 (Temp/Humidity)  │  Soil ADC (GPIO36)    │
│  pH ADC (GPIO39)        │  Water ADC (GPIO32)   │
│  Pump Motor (GPIO14/27) │  OLED Display         │
└──────────────────────────────────────────────────┘

External APIs:
  Claude AI (Anthropic) ──── AI Crop Advisor
  OpenWeatherMap ─────────── Weather Forecast
```

---

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile Framework | Flutter | ^3.9.2 |
| Authentication | Firebase Auth + Google Sign-In | ^5.3.1 |
| Live Data | Firebase Realtime Database | ^11.1.4 |
| Persistent Data | Cloud Firestore | ^5.4.4 |
| File Storage | Firebase Storage | ^12.3.4 |
| Notifications | Firebase Cloud Messaging | ^15.1.3 |
| AI Advisory | Claude API (claude-haiku-4-5) | Anthropic |
| Weather | OpenWeatherMap API | REST |
| Mapping | flutter_map + geolocator | ^6.1.0 |
| IoT Hardware | ESP32 (Arduino) | — |
| Sensors | DHT11, ADC (soil/pH/water) | GPIO |

---

## Installation & Setup

### Prerequisites
- Flutter SDK ≥ 3.9.2
- Android Studio or VS Code with Flutter extension
- Firebase project (free tier is sufficient)
- Anthropic API key (for AI Advisor)
- OpenWeatherMap API key (free tier)

### Flutter App

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/iot_smart_farm_app.git
   cd iot_smart_farm_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable: Authentication (Email + Google), Firestore, Realtime Database, Storage, Messaging
   - Download `google-services.json` → place in `android/app/`
   - Download `GoogleService-Info.plist` → place in `ios/Runner/`

4. **Add API keys**
   - Open `lib/services/weather_service.dart` → replace `_apiKey` with your OpenWeatherMap key
   - Open `lib/services/claude_service.dart` → replace `_apiKey` with your Anthropic API key

5. **Firebase Database Rules**
   - Apply the rules from `DATABASE_RULES_FIX.json` in your Firebase console

6. **Run the app**
   ```bash
   flutter run
   ```

### ESP32 Firmware

1. **Prerequisites**
   - Arduino IDE 2.x
   - Libraries: `Firebase ESP32 Client`, `DHT sensor library`, `Adafruit SH110X` (OLED)

2. **Configure firmware**
   - Open `esp32_smartfarm_optimized.ino`
   - Set your WiFi credentials:
     ```cpp
     #define WIFI_SSID "your_wifi_ssid"
     #define WIFI_PASSWORD "your_wifi_password"
     ```
   - Set your Firebase project URL and API key

3. **Hardware wiring**

   | Component | GPIO Pin |
   |-----------|---------|
   | DHT11 (Temp/Humidity) | GPIO 17 |
   | Soil Moisture ADC | GPIO 36 |
   | pH Sensor ADC | GPIO 39 |
   | Water Level ADC | GPIO 32 |
   | Pump Motor A | GPIO 14 |
   | Pump Motor B | GPIO 27 |
   | OLED SDA | GPIO 21 |
   | OLED SCL | GPIO 22 |

4. **Flash to ESP32**
   - Select board: `ESP32 Dev Module`
   - Upload the sketch
   - The device ID `ESP32_001` will appear in the app under **Crop Management → Claim Device**

---

## AI Features & Disclosure

### Claude AI Crop Advisor
The AI Assistant screen uses **Claude API (claude-haiku-4-5-20251001)** to provide real-time, context-aware crop advice. The AI receives:
- Current crop type
- Live sensor readings (soil moisture, pH, temperature, humidity, water level)
- User's natural language question

This enables responses like: *"Your tomato soil moisture at 42% is below the optimal 60–80% range. Consider activating irrigation now, especially given the current 34°C temperature."*

### AI Tools Used (PutraHack 2026 Disclosure)

| Tool | Purpose |
|------|---------|
| Claude API (claude-haiku-4-5) | In-app AI crop advisory chatbot |
| Claude Code | Development assistance and code generation |
| ChatGPT | Research and content drafting |

---

## Future Roadmap

- [ ] **ML-based irrigation scheduling** — Train model on historical sensor data to predict optimal irrigation windows
- [ ] **Multi-device / multi-field management** — Manage multiple ESP32 nodes across different farm plots
- [ ] **Crop disease detection** — Camera module on ESP32 + image classification for early pest/disease alerts
- [ ] **Offline mode** — Local sensor data cache when connectivity is lost
- [ ] **Web dashboard** — Browser-based monitoring panel for farm managers
- [ ] **Community benchmarking** — Anonymized crop performance data shared across farms in the same region
- [ ] **Voice control** — Activate pump or set thresholds via voice commands
- [ ] **Satellite data integration** — NDVI crop health index from remote sensing

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

*Built for PutraHack 2026 — Theme: Food Security*  
*Developed with Claude Code + Lovable*
