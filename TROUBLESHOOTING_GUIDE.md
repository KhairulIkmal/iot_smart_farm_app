# IoT Smart Farm Troubleshooting Guide
## Problem: ESP32 connects to WiFi but doesn't upload sensor readings

### Step 1: Check Serial Monitor Output
1. Connect ESP32 to computer via USB
2. Open Arduino IDE → Tools → Serial Monitor (115200 baud)
3. Press ESP32 reset button
4. **Look for these messages:**

**✅ Good Messages:**
```
[WiFi] Connected! IP: 192.168.x.x
[NTP] Time synced: xxxxxxxxxx
[FB] Ready!
[FB] Heartbeat sent
[FB] Sensor data pushed
```

**❌ Error Messages:**
```
[FB] NOT READY!           → Firebase auth failed
[FB] Heartbeat failed     → Connection issue
[FB] Sensor push failed   → Upload blocked
[NTP] Sync failed         → Time issue
```

### Step 2: Verify Firebase Authentication User Exists
1. Go to https://console.firebase.google.com
2. Select project: **iot-smartfarm-system**
3. Go to **Authentication** → **Users** tab
4. **Check if this user exists:**
   - Email: `esp32_device@smartfarm.com`
   - Password: `esp32_pass`

**If user doesn't exist:**
1. Click **Add User**
2. Email: `esp32_device@smartfarm.com`
3. Password: `esp32_pass`
4. Click **Add User**
5. Reset ESP32 and test again

### Step 3: Check WiFi Credentials
**Current code settings:**
- SSID: `AMAT_2.4@unifi`
- Password: `AMAT631008`

**If using phone hotspot:**
- Open `esp32_smartfarm_optimized.ino` (line 24-25)
- Update WiFi credentials to match your hotspot:
```cpp
#define WIFI_SSID "YourHotspotName"
#define WIFI_PASSWORD "YourHotspotPassword"
```
- Re-upload the code to ESP32

### Step 4: Check Firebase Realtime Database Rules
1. Go to Firebase Console
2. **Realtime Database** → **Rules** tab
3. **Current rules should allow authenticated writes:**

```json
{
  "rules": {
    "sensors": {
      "$deviceId": {
        ".write": "auth != null",
        ".read": "auth != null"
      }
    },
    "commands": {
      "$deviceId": {
        ".write": "auth != null",
        ".read": "auth != null"
      }
    }
  }
}
```

**If rules are different, update them and click Publish**

### Step 5: Check Firebase Database Data Structure
1. Go to Firebase Console → **Realtime Database** → **Data** tab
2. Navigate to: `sensors/ESP32_001/`
3. **You should see:**
```
sensors/
  ESP32_001/
    live/
      soil: 45
      temp: 28
      humidity: 65
      ph: 6.8
      waterLevel: 75
      pumpOn: false
      lastSeen: 1234567890
    sensorHealth/
      soil: "ok"
      temp: "ok"
      humidity: "ok"
      ph: "ok"
      waterLevel: "ok"
```

**If this path doesn't exist or is empty:**
- The ESP32 is not successfully uploading data
- Check steps 1-4 above

### Step 6: Verify Firebase Project Configuration
**In esp32_smartfarm_optimized.ino (lines 26-27):**
```cpp
#define FIREBASE_API_KEY "AIzaSyDKEGXzw8kX7k4YvjjxQF4_4AzZYyH_xmQ"
#define FIREBASE_DB_URL "https://iot-smartfarm-system-default-rtdb.asia-southeast1.firebasedatabase.app"
```

**Verify in Firebase Console:**
1. Go to **Project Settings** (gear icon)
2. Check **Web API Key** matches `FIREBASE_API_KEY`
3. Go to **Realtime Database**
4. Check database URL matches `FIREBASE_DB_URL`

### Step 7: Test Mobile App Connection
1. Open your Flutter app
2. Go to **Sensors** screen
3. Check if you see:
   - "No Device Connected" → ESP32 not uploading
   - Sensor data showing → ESP32 working!

### Step 8: Force Reset and Reconnect
If all above steps check out:
1. Unplug ESP32 from power
2. Wait 10 seconds
3. Plug back in
4. Wait 30 seconds for WiFi + Firebase connection
5. Check Serial Monitor output
6. Check Firebase Database Data tab
7. Check mobile app

---

## Common Issues and Solutions

### Issue: "Firebase not ready" after WiFi connects
**Cause:** Firebase authentication failed
**Solution:**
- Create user `esp32_device@smartfarm.com` in Firebase Authentication
- Verify API key and database URL are correct

### Issue: ESP32 connects to wrong WiFi network
**Cause:** WiFi credentials in code don't match your hotspot
**Solution:**
- Update `WIFI_SSID` and `WIFI_PASSWORD` in lines 24-25
- Re-upload code to ESP32

### Issue: Sensor readings show as "--" in app
**Cause:** Sensors disconnected or faulty
**Solution:**
- Check sensor wiring
- Check Serial Monitor for sensor health errors
- Verify sensor readings in Serial Monitor

### Issue: "lastSeen" is old/not updating
**Cause:** ESP32 not uploading or offline
**Solution:**
- Check WiFi connection
- Check Firebase authentication
- Check database rules

### Issue: App shows "Sensor Error"
**Cause:** Sensor health status = "error" in Firebase
**Solution:**
- Check physical sensor connections
- Replace faulty sensors
- Check Serial Monitor for ADC readings

---

## Quick Fix Checklist

- [ ] ESP32 connects to WiFi (check Serial Monitor)
- [ ] Firebase user `esp32_device@smartfarm.com` exists
- [ ] WiFi credentials match your hotspot
- [ ] Firebase database rules allow authenticated writes
- [ ] Time synchronized (NTP)
- [ ] Firebase API key and database URL are correct
- [ ] Sensors physically connected
- [ ] Firebase database shows recent data
- [ ] Mobile app can read data

---

## Need More Help?

If problem persists after following all steps:
1. Copy the **full Serial Monitor output**
2. Take a screenshot of **Firebase Database Data tab**
3. Take a screenshot of **Firebase Authentication Users tab**
4. Share these for further diagnosis
