import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_service.dart';
import '../models/notification_model.dart';

/// Weather Alert Service
/// Monitors weather conditions and creates notifications for alerts
class WeatherAlertService {
  static final WeatherAlertService _instance = WeatherAlertService._internal();
  factory WeatherAlertService() => _instance;
  WeatherAlertService._internal();

  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _checkTimer;
  bool _hasNotifiedRainToday = false;
  bool _hasNotifiedRainSoon = false;
  bool _hasNotifiedCurrentRain = false;
  bool _hasNotifiedExtremeTemp = false;
  bool _hasNotifiedHumidity = false;
  String? _lastCheckDate;
  String? _lastCheckHour;

  // OpenWeather API configuration (same as WeatherService)
  static const String _apiKey = 'ca6f5f0810167431d32955c435826e53';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Start monitoring weather (checks every 15 minutes for more frequent updates)
  void startMonitoring() {
    stopMonitoring();

    // Check immediately, then every 15 minutes for better rain detection
    _checkWeatherAlerts();
    _checkTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkWeatherAlerts();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Get user's farm location from Firestore (same as WeatherService)
  Future<Map<String, double>?> _getFarmLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('farm')
          .doc('location')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final lat = data['latitude']?.toDouble();
      final lng = data['longitude']?.toDouble();

      if (lat == null || lng == null) return null;

      return {'lat': lat, 'lng': lng};
    } catch (e) {
      return null;
    }
  }

  /// Check weather alerts based on user's farm location
  Future<void> _checkWeatherAlerts() async {
    try {
      final now = DateTime.now();
      final today = now.toString().split(' ')[0];
      final currentHour = '${now.year}-${now.month}-${now.day}-${now.hour}';

      // Reset daily flags if new day
      if (_lastCheckDate != today) {
        _lastCheckDate = today;
        _hasNotifiedRainToday = false;
        _hasNotifiedExtremeTemp = false;
        _hasNotifiedHumidity = false;
      }

      // Reset hourly flags for rain updates (allows re-notification every hour)
      if (_lastCheckHour != currentHour) {
        _lastCheckHour = currentHour;
        _hasNotifiedRainSoon = false;
        _hasNotifiedCurrentRain = false;
      }

      // Get user's farm location from Firestore
      final location = await _getFarmLocation();
      if (location == null) {
        return; // No location set, skip weather alerts
      }

      final latitude = location['lat']!;
      final longitude = location['lng']!;

      // Fetch current weather
      await _checkCurrentWeather(latitude, longitude);

      // Fetch forecast for rain prediction
      await _checkWeatherForecast(latitude, longitude);
    } catch (e) {
      // Error handling - use logger in production
    }
  }

  /// Check current weather conditions
  Future<void> _checkCurrentWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['main']['temp'] as double;
        final humidity = data['main']['humidity'] as int;
        final weather = data['weather'] as List;

        // Check if it's currently raining
        if (!_hasNotifiedCurrentRain && weather.isNotEmpty) {
          final weatherMain = (weather[0]['main'] as String).toLowerCase();
          final weatherDesc = (weather[0]['description'] as String);

          if (weatherMain.contains('rain') || weatherMain.contains('drizzle')) {
            String rainMessage = '';
            NotificationSeverity severity = NotificationSeverity.info;

            if (weatherMain.contains('thunderstorm')) {
              rainMessage =
                  'Thunderstorm detected in your area. Heavy rain and lightning expected. Keep equipment protected and avoid outdoor work.';
              severity = NotificationSeverity.warning;
            } else if (weatherDesc.toLowerCase().contains('heavy')) {
              rainMessage =
                  'Heavy rain is currently falling in your area. Consider postponing irrigation and protect sensitive crops.';
              severity = NotificationSeverity.warning;
            } else if (weatherDesc.toLowerCase().contains('light')) {
              rainMessage =
                  'Light rain is currently falling. This is good for your crops and you can skip irrigation for now.';
            } else {
              rainMessage =
                  'Rain detected in your area. You may want to skip irrigation and let nature water your crops.';
            }

            await _notificationService.createNotification(
              severity: severity,
              category: NotificationCategory.weather,
              title: weatherMain.contains('thunderstorm')
                  ? 'Thunderstorm Alert'
                  : 'Rain Detected',
              message: rainMessage,
              data: {
                'weatherType': weatherMain,
                'description': weatherDesc,
                'type': 'current_rain',
              },
            );
            _hasNotifiedCurrentRain = true;
          }
        }

        // Check for extreme temperature
        if (!_hasNotifiedExtremeTemp) {
          if (temp > 38) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.critical,
              category: NotificationCategory.weather,
              title: 'Extreme Heat Alert',
              message:
                  'Dangerously hot at ${temp.toStringAsFixed(1)}°C! Increase irrigation frequency, provide shade, and monitor crops for heat stress. Avoid working during peak heat hours.',
              data: {
                'temperature': temp,
                'type': 'extreme_heat',
              },
            );
            _hasNotifiedExtremeTemp = true;
          } else if (temp > 35) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.warning,
              category: NotificationCategory.weather,
              title: 'High Temperature Warning',
              message:
                  'Very hot at ${temp.toStringAsFixed(1)}°C. Your crops may need extra water today. Consider irrigating in the early morning or evening to reduce water loss.',
              data: {
                'temperature': temp,
                'type': 'high_heat',
              },
            );
            _hasNotifiedExtremeTemp = true;
          } else if (temp < 2) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.critical,
              category: NotificationCategory.weather,
              title: 'Frost Alert',
              message:
                  'Freezing temperature at ${temp.toStringAsFixed(1)}°C! Urgent: Cover sensitive crops immediately and protect irrigation systems from freezing.',
              data: {
                'temperature': temp,
                'type': 'frost',
              },
            );
            _hasNotifiedExtremeTemp = true;
          } else if (temp < 5) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.warning,
              category: NotificationCategory.weather,
              title: 'Cold Weather Warning',
              message:
                  'Cold at ${temp.toStringAsFixed(1)}°C. Protect sensitive crops with row covers and watch for signs of cold stress. Frost may occur overnight.',
              data: {
                'temperature': temp,
                'type': 'cold',
              },
            );
            _hasNotifiedExtremeTemp = true;
          }
        }

        // Check for extreme humidity
        if (!_hasNotifiedHumidity) {
          if (humidity > 90) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.warning,
              category: NotificationCategory.weather,
              title: 'Very High Humidity',
              message:
                  'Humidity is extremely high at ${humidity}%. High risk of fungal diseases and mold. Ensure good air circulation and inspect crops for signs of disease.',
              data: {
                'humidity': humidity,
                'type': 'very_high_humidity',
              },
            );
            _hasNotifiedHumidity = true;
          } else if (humidity > 85) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.info,
              category: NotificationCategory.weather,
              title: 'High Humidity Notice',
              message:
                  'Humidity is high at ${humidity}%. Watch for fungal issues and consider reducing irrigation if soil is already moist.',
              data: {
                'humidity': humidity,
                'type': 'high_humidity',
              },
            );
            _hasNotifiedHumidity = true;
          } else if (humidity < 25) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.warning,
              category: NotificationCategory.weather,
              title: 'Very Low Humidity',
              message:
                  'Humidity is very low at ${humidity}%. Crops will lose water quickly. Increase irrigation and consider misting sensitive plants.',
              data: {
                'humidity': humidity,
                'type': 'very_low_humidity',
              },
            );
            _hasNotifiedHumidity = true;
          } else if (humidity < 30) {
            await _notificationService.createNotification(
              severity: NotificationSeverity.info,
              category: NotificationCategory.weather,
              title: 'Low Humidity Notice',
              message:
                  'Humidity is low at ${humidity}%. Your crops may need more frequent watering to compensate for faster evaporation.',
              data: {
                'humidity': humidity,
                'type': 'low_humidity',
              },
            );
            _hasNotifiedHumidity = true;
          }
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  /// Check weather forecast for rain prediction
  Future<void> _checkWeatherForecast(double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['list'] as List;

        final now = DateTime.now();

        // Check for rain coming in the next 3 hours
        if (!_hasNotifiedRainSoon) {
          bool rainComingSoon = false;
          double soonRainProb = 0;
          String rainType = '';
          int hoursUntilRain = 0;

          final next3Hours = now.add(const Duration(hours: 3));

          for (var forecast in list) {
            final forecastTime =
                DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);

            if (forecastTime.isBefore(next3Hours) &&
                forecastTime.isAfter(now)) {
              final weather = forecast['weather'] as List;
              if (weather.isNotEmpty) {
                final weatherMain =
                    (weather[0]['main'] as String).toLowerCase();
                final weatherDesc = weather[0]['description'] as String;
                final pop = (forecast['pop'] as num?)?.toDouble() ?? 0;

                if (weatherMain.contains('rain') ||
                    weatherMain.contains('thunderstorm') ||
                    pop > 0.6) {
                  rainComingSoon = true;
                  if (pop > soonRainProb) {
                    soonRainProb = pop;
                    rainType = weatherMain.contains('thunderstorm')
                        ? 'thunderstorm'
                        : weatherDesc;
                    hoursUntilRain =
                        forecastTime.difference(now).inHours.clamp(1, 3);
                  }
                }
              }
            }
          }

          if (rainComingSoon) {
            String message = '';
            String title = '';
            NotificationSeverity severity = NotificationSeverity.info;

            if (rainType.contains('thunderstorm')) {
              title = 'Thunderstorm Approaching';
              message =
                  'A thunderstorm is expected in approximately $hoursUntilRain ${hoursUntilRain == 1 ? 'hour' : 'hours'}. Secure equipment and postpone outdoor activities.';
              severity = NotificationSeverity.warning;
            } else if (rainType.contains('heavy')) {
              title = 'Heavy Rain Coming Soon';
              message =
                  'Heavy rain expected within the next $hoursUntilRain ${hoursUntilRain == 1 ? 'hour' : 'hours'} (${(soonRainProb * 100).toInt()}% chance). Consider adjusting irrigation schedule.';
              severity = NotificationSeverity.warning;
            } else {
              title = 'Rain Expected Soon';
              message =
                  'Rain forecasted within $hoursUntilRain ${hoursUntilRain == 1 ? 'hour' : 'hours'} (${(soonRainProb * 100).toInt()}% chance). You may want to skip irrigation.';
            }

            await _notificationService.createNotification(
              severity: severity,
              category: NotificationCategory.weather,
              title: title,
              message: message,
              data: {
                'rainProbability': soonRainProb,
                'hoursUntilRain': hoursUntilRain,
                'rainType': rainType,
                'type': 'rain_soon',
              },
            );
            _hasNotifiedRainSoon = true;
          }
        }

        // Check next 24 hours for rain today
        if (!_hasNotifiedRainToday) {
          bool rainExpectedToday = false;
          double maxRainProbability = 0;
          String rainDescription = '';
          int totalRainForecasts = 0;

          final next24Hours = now.add(const Duration(hours: 24));

          for (var forecast in list) {
            final forecastTime =
                DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);

            if (forecastTime.isBefore(next24Hours)) {
              final weather = forecast['weather'] as List;
              if (weather.isNotEmpty) {
                final weatherMain =
                    (weather[0]['main'] as String).toLowerCase();
                final weatherDesc = weather[0]['description'] as String;
                final pop = (forecast['pop'] as num?)?.toDouble() ?? 0;

                if (weatherMain.contains('rain') ||
                    weatherMain.contains('thunderstorm') ||
                    pop > 0.5) {
                  rainExpectedToday = true;
                  totalRainForecasts++;
                  if (pop > maxRainProbability) {
                    maxRainProbability = pop;
                    rainDescription = weatherDesc;
                  }
                }
              }
            }
          }

          if (rainExpectedToday) {
            String message = '';
            String title = 'Rain Forecast Today';

            if (totalRainForecasts >= 4) {
              // Multiple periods of rain
              message =
                  'Multiple rain periods expected today with up to ${(maxRainProbability * 100).toInt()}% chance. Plan to skip irrigation and let nature water your crops.';
            } else if (rainDescription.toLowerCase().contains('thunderstorm')) {
              title = 'Thunderstorms Expected Today';
              message =
                  'Thunderstorms are forecasted for today (${(maxRainProbability * 100).toInt()}% probability). Postpone irrigation and ensure farm equipment is secured.';
            } else if (rainDescription.toLowerCase().contains('heavy')) {
              message =
                  'Heavy rain is forecasted for later today (${(maxRainProbability * 100).toInt()}% chance). Skip irrigation and ensure proper drainage.';
            } else {
              message =
                  'Rain expected later today with ${(maxRainProbability * 100).toInt()}% probability. You can skip irrigation and save water.';
            }

            await _notificationService.createNotification(
              severity: NotificationSeverity.info,
              category: NotificationCategory.weather,
              title: title,
              message: message,
              data: {
                'rainProbability': maxRainProbability,
                'totalRainForecasts': totalRainForecasts,
                'description': rainDescription,
                'type': 'rain_forecast_today',
              },
            );
            _hasNotifiedRainToday = true;
          }
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  /// Manual notification for severe weather
  Future<void> notifySevereWeather({
    required String title,
    required String message,
    required Map<String, dynamic> weatherData,
  }) async {
    await _notificationService.createNotification(
      severity: NotificationSeverity.critical,
      category: NotificationCategory.weather,
      title: title,
      message: message,
      data: weatherData,
    );
  }
}
