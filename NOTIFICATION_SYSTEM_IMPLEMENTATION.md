# Notification System Implementation

## Overview
Comprehensive real-time notification system for IoT Smart Farm app that monitors devices, irrigation, weather, crops, and system events.

## ✅ What Was Implemented

### 1. **Notification Data Model** (`lib/services/notifications/models/notification_model.dart`)
- `NotificationSeverity`: critical (RED), warning (ORANGE/YELLOW), info (BLUE/GREEN)
- `NotificationCategory`: device, irrigation, weather, crop, system
- `NotificationModel`: Firestore-compatible data structure
- Conversion methods for Firestore (toFirestore/fromFirestore)

### 2. **NotificationService** (`lib/services/notifications/notification_service.dart`)
Central service for Firestore operations:
- ✅ Create notifications
- ✅ Stream all notifications (real-time)
- ✅ Stream unread count
- ✅ Mark as read (single/all)
- ✅ Delete notifications
- ✅ Filter by category/severity

### 3. **DeviceMonitorService** (`lib/services/notifications/monitors/device_monitor_service.dart`)
Monitors ESP32 devices every 10 seconds:
- ✅ **Device Offline Detection**: Checks `lastSeen` timestamp (alerts if > 2 minutes)
- ✅ **Sensor Health Monitoring**: Reads from `/sensors/{deviceId}/sensorHealth`
- ✅ **Water Level Critical**: Alerts when tank < 10% (critical) or < 30% (warning)
- ✅ **pH Level Critical**: Alerts when pH < 5.5 or > 8.0

**Notifications Created:**
- Device Offline (CRITICAL)
- Device Back Online (INFO)
- Sensor Failure (CRITICAL)
- Sensor Recovered (INFO)
- Water Level Critical (CRITICAL)
- Water Level Low (WARNING)
- Water Level Normal (INFO)
- pH Level Critical (CRITICAL)
- pH Level Normal (INFO)
- Extreme Heat Alert (CRITICAL) - temp > 35°C
- High Temperature Warning (WARNING) - temp > 30°C
- Frost Risk Alert (CRITICAL) - temp < 5°C
- Low Temperature Warning (WARNING) - temp < 10°C
- Temperature Normal (INFO)
- Soil Critically Dry (CRITICAL) - moisture < 20%
- Low Soil Moisture (WARNING) - moisture < 40%
- Soil Over-Saturated (WARNING) - moisture > 80%
- Soil Moisture Optimal (INFO)

### 4. **IrrigationMonitorService** (`lib/services/notifications/monitors/irrigation_monitor_service.dart`)
Monitors irrigation events via RTDB:
- ✅ Listens to `/commands/{deviceId}` for pump state changes
- ✅ Detects auto vs manual irrigation
- ✅ Tracks mode changes (auto/manual)

**Notifications Created:**
- Auto Irrigation Started (INFO)
- Auto Irrigation Stopped (INFO)
- Manual Pump Started (INFO)
- Manual Pump Stopped (INFO)
- Irrigation Mode Changed (INFO)

### 5. **WeatherAlertService** (`lib/services/notifications/monitors/weather_alert_service.dart`)
Monitors weather conditions every 30 minutes:
- ✅ Fetches current weather from OpenWeather API
- ✅ Checks forecast for rain (next 24 hours)
- ✅ Uses farm location from SharedPreferences
- ✅ Daily notification limits (no spam)

**Notifications Created:**
- Rain Expected Today (INFO)
- Extreme Heat Warning (WARNING) - when temp > 35°C
- Cold Temperature Alert (WARNING) - when temp < 5°C
- High Humidity Alert (WARNING) - when humidity > 85%
- Low Humidity Alert (WARNING) - when humidity < 30%

### 6. **MonitoringManager** (`lib/services/notifications/monitoring_manager.dart`)
Coordinates all monitoring services:
- ✅ Starts/stops all monitors based on auth state
- ✅ Per-device irrigation monitoring control
- ✅ Singleton pattern for global access

### 7. **Updated Notifications Screen** (`lib/features/more/notifications/notifications_screen.dart`)
Replaced dummy data with real Firestore integration:
- ✅ StreamBuilder for real-time notifications
- ✅ Filter by severity (Critical, Warnings, Archived)
- ✅ Date grouping (Today, Yesterday, specific dates)
- ✅ Mark as read on tap
- ✅ Mark all as read button
- ✅ Color-coded by severity (RED/ORANGE/GREEN/BLUE)
- ✅ Category-specific icons (sensors, water drop, weather, eco, settings)

### 8. **Main App Integration** (`lib/main.dart`)
- ✅ MonitoringManager starts when user logs in
- ✅ MonitoringManager stops when user logs out
- ✅ Automatic lifecycle management

## 📁 File Structure
```
lib/services/notifications/
├── models/
│   └── notification_model.dart           # Data model & enums
├── monitors/
│   ├── device_monitor_service.dart       # Device offline & sensor health
│   ├── irrigation_monitor_service.dart   # Pump control events
│   └── weather_alert_service.dart        # Weather API integration
├── notification_service.dart             # Firestore operations
└── monitoring_manager.dart               # Coordinator

lib/features/more/notifications/
└── notifications_screen.dart             # Updated UI with real data
```

## 🗄️ Firestore Structure
```
/notifications/{userId}/items/{notificationId}
{
  "userId": "firebase_uid",
  "severity": "critical|warning|info",
  "category": "device|irrigation|weather|crop|system",
  "title": "Device Offline",
  "message": "Device ESP32_001 has been offline for 5 minutes...",
  "timestamp": Timestamp,
  "isRead": false,
  "actionTaken": false,
  "data": {
    "deviceId": "ESP32_001",
    "lastSeen": 1234567890,
    ...
  }
}
```

## ✨ No RTDB Changes Required!
Your ESP32 code is perfect. The system monitors existing RTDB paths:
- ✅ `/sensors/{deviceId}/live/lastSeen` - for offline detection
- ✅ `/sensors/{deviceId}/sensorHealth` - for sensor failures
- ✅ `/commands/{deviceId}` - for irrigation events

## 🔧 Configuration Needed

### 1. **OpenWeather API Key**
Edit `lib/services/notifications/monitors/weather_alert_service.dart`:
```dart
static const String _apiKey = 'YOUR_API_KEY_HERE'; // Line 19
```
Get free API key from: https://openweathermap.org/api

### 2. **Farm Location** (Set via Farm Location Screen)
Weather alerts require:
- `farm_latitude` in SharedPreferences
- `farm_longitude` in SharedPreferences

## 🚀 How It Works

### When User Logs In:
1. `AuthWrapper` detects authentication
2. `MonitoringManager.startMonitoring()` is called
3. **DeviceMonitorService** starts checking every 10 seconds
4. **WeatherAlertService** starts checking every 30 minutes
5. **IrrigationMonitorService** waits for device selection

### When Device is Selected:
Call from your irrigation screen:
```dart
MonitoringManager().startIrrigationMonitoring('ESP32_001');
```

### When User Logs Out:
1. All monitoring services stop automatically
2. Cleans up listeners and timers

## 📱 Notification Categories & Colors

| Category   | Severity  | Color  | Icon        | Examples                          |
|------------|-----------|--------|-------------|-----------------------------------|
| Device     | Critical  | RED    | sensors     | Device offline, Sensor failure    |
| Device     | Info      | BLUE   | sensors     | Device back online, Sensor OK     |
| Irrigation | Critical  | RED    | water_drop  | Water tank critical               |
| Irrigation | Warning   | ORANGE | water_drop  | Water level low                   |
| Irrigation | Info      | BLUE   | water_drop  | Pump started/stopped              |
| Weather    | Warning   | YELLOW | wb_sunny    | Extreme heat/cold, Rain expected  |
| Crop       | Critical  | RED    | eco         | pH critical                       |
| Crop       | Info      | GREEN  | eco         | AI recommendations                |
| System     | Info      | BLUE   | settings    | Profile updated, Device claimed   |

## 🎯 Notification Examples

### Critical Alerts (RED)
```
Title: "Device Offline"
Message: "Device ESP32_001 has been offline for 5 minutes. Check power and internet connection."
Data: { deviceId: "ESP32_001", lastSeen: 1234567890, offlineDuration: 5 }
```

### Irrigation Alerts (BLUE/ORANGE)
```
Title: "Auto Irrigation Started"
Message: "Automatic irrigation has started on device ESP32_001 based on soil moisture levels."
Data: { deviceId: "ESP32_001", pumpOn: true, mode: "auto" }
```

### Weather Alerts (YELLOW)
```
Title: "Rain Expected Today"
Message: "Rain forecasted within next 24 hours (80% probability). You may skip irrigation."
Data: { rainProbability: 0.8, type: "rain_forecast" }
```

## 📊 Monitoring Intervals

- **Device Health**: Every 10 seconds
- **ESP32 Heartbeat**: Every 2 seconds (already in your ESP32 code)
- **Weather Alerts**: Every 30 minutes
- **Irrigation Events**: Real-time (RTDB listener)

## 🔍 Testing Checklist

- [ ] Log in → notifications monitoring starts
- [ ] Turn off ESP32 → "Device Offline" notification appears after 2 minutes
- [ ] Turn on ESP32 → "Device Back Online" notification appears
- [ ] Manual pump ON → "Manual Pump Started" notification
- [ ] Auto irrigation trigger → "Auto Irrigation Started" notification
- [ ] Low water level → "Water Level Low" notification
- [ ] Set farm location → weather alerts start working
- [ ] Log out → all monitoring stops

## 🎨 UI Features

### Notifications Screen
- ✅ Real-time updates (StreamBuilder)
- ✅ Filter tabs: All, Critical, Warnings, Archived
- ✅ Tap notification → marks as read
- ✅ "Mark All as Read" button
- ✅ Empty state with icon
- ✅ Date grouping (Today, Yesterday, MM/DD/YYYY)
- ✅ Unread notifications have colored border
- ✅ Category-specific icons

### More Screen Badge (Future Enhancement)
Add unread count badge to Notifications menu item:
```dart
StreamBuilder<int>(
  stream: NotificationService().getUnreadCountStream(),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    return MenuItem(badge: count > 0 ? '$count' : null);
  },
)
```

## 🔐 Security Rules (Add to Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Notifications - users can only read/write their own
    match /notifications/{userId}/items/{notificationId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 📝 Notes

1. **No RTDB Structure Changes**: Your ESP32 code doesn't need any modifications!
2. **Firestore Over RTDB**: Notifications use Firestore for better querying, pagination, and read/unread status
3. **ESP32 Never Sends Notifications**: App creates them based on ESP32 data
4. **Smart Deduplication**: Services track which notifications were sent to avoid spam
5. **Daily Resets**: Weather alerts reset daily to avoid notification fatigue

## 🚧 Future Enhancements

Potential additions:
- [ ] Push notifications (FCM)
- [ ] Notification settings (enable/disable categories)
- [ ] Custom alert thresholds per user
- [ ] Notification history export
- [ ] Crop-specific AI recommendations
- [ ] Fertilizer reminders
- [ ] Pest alerts based on weather patterns

---

**Implementation Complete!** ✅

All notification types from your specification are now implemented and integrated into the app.
