import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_counter_service.dart';

/// ------------------------------------------------------------
/// WEATHER SERVICE
/// Uses OpenWeather API for weather data
/// - Current weather
/// - Rain forecast
/// - Temperature & humidity
///
/// IMPORTANT: Weather data is fetched on demand, NOT persisted in Firebase
/// ------------------------------------------------------------
class WeatherService {
  // OpenWeather API Configuration
  static const String _apiKey = 'ca6f5f0810167431d32955c435826e53';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user's farm location from Firestore
  Future<Map<String, double>?> _getFarmLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) return null;

      final customUserId = userDoc.id;

      final doc = await _firestore
          .collection('users')
          .doc(customUserId)
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

  /// ------------------------------------------------
  /// GET CURRENT WEATHER
  /// Returns current weather conditions
  /// ------------------------------------------------
  Future<WeatherData?> getCurrentWeather({double? lat, double? lng}) async {
    try {
      // Use provided coordinates or fetch from Firestore
      double? latitude = lat;
      double? longitude = lng;

      if (latitude == null || longitude == null) {
        final location = await _getFarmLocation();
        if (location == null) {
          throw WeatherException('Farm location not set');
        }
        latitude = location['lat'];
        longitude = location['lng'];
      }

      final url = Uri.parse(
        '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch weather: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error: $e');
    }
  }

  /// ------------------------------------------------
  /// GET WEATHER FORECAST (5 days / 3 hours)
  /// Returns forecast data for rain prediction
  /// ------------------------------------------------
  Future<WeatherForecast?> getWeatherForecast({
    double? lat,
    double? lng,
  }) async {
    try {
      double? latitude = lat;
      double? longitude = lng;

      if (latitude == null || longitude == null) {
        final location = await _getFarmLocation();
        if (location == null) {
          throw WeatherException('Farm location not set');
        }
        latitude = location['lat'];
        longitude = location['lng'];
      }

      final url = Uri.parse(
        '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherForecast.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch forecast: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error: $e');
    }
  }

  /// ------------------------------------------------
  /// GET RAIN PREDICTION
  /// Checks if rain is expected in the next 24 hours
  /// ------------------------------------------------
  Future<RainPrediction> getRainPrediction({double? lat, double? lng}) async {
    try {
      final forecast = await getWeatherForecast(lat: lat, lng: lng);

      if (forecast == null) {
        return RainPrediction(
          willRain: false,
          probability: 0,
          expectedTime: null,
          message: 'Unable to fetch forecast',
        );
      }

      // Check next 24 hours (8 x 3-hour intervals)
      final next24Hours = forecast.list.take(8).toList();

      for (final item in next24Hours) {
        // Check if rain is in weather conditions
        final hasRain = item.weather.any(
          (w) =>
              w.main.toLowerCase().contains('rain') ||
              w.main.toLowerCase().contains('drizzle') ||
              w.main.toLowerCase().contains('thunderstorm'),
        );

        if (hasRain) {
          final rainAmount = item.rain?.threeHour ?? 0;
          return RainPrediction(
            willRain: true,
            probability: (item.pop * 100).toInt(),
            expectedTime: item.dateTime,
            rainAmount: rainAmount,
            message: 'Rain expected at ${_formatTime(item.dateTime)}',
          );
        }

        // Check probability of precipitation
        if (item.pop > 0.5) {
          return RainPrediction(
            willRain: true,
            probability: (item.pop * 100).toInt(),
            expectedTime: item.dateTime,
            message:
                '${(item.pop * 100).toInt()}% chance of rain at ${_formatTime(item.dateTime)}',
          );
        }
      }

      return RainPrediction(
        willRain: false,
        probability: 0,
        expectedTime: null,
        message: 'No rain expected in the next 24 hours',
      );
    } catch (e) {
      return RainPrediction(
        willRain: false,
        probability: 0,
        expectedTime: null,
        message: 'Unable to predict rain: $e',
      );
    }
  }

  /// ------------------------------------------------
  /// GET IRRIGATION ADVICE BASED ON WEATHER
  /// Returns advice for irrigation based on weather conditions
  /// ------------------------------------------------
  Future<IrrigationAdvice> getIrrigationAdvice({
    double? lat,
    double? lng,
    required int currentSoilMoisture,
  }) async {
    try {
      final weather = await getCurrentWeather(lat: lat, lng: lng);
      final rainPrediction = await getRainPrediction(lat: lat, lng: lng);

      if (weather == null) {
        return IrrigationAdvice(
          shouldIrrigate: currentSoilMoisture < 40,
          reason: 'Unable to fetch weather data',
          confidence: 'low',
        );
      }

      // High temperature - more irrigation needed
      if (weather.temperature > 35 && currentSoilMoisture < 50) {
        return IrrigationAdvice(
          shouldIrrigate: true,
          reason:
              'High temperature (${weather.temperature.toInt()}°C) causing rapid moisture loss',
          confidence: 'high',
          suggestedAmount: 'heavy',
        );
      }

      // Rain expected - skip irrigation
      if (rainPrediction.willRain && rainPrediction.probability > 60) {
        return IrrigationAdvice(
          shouldIrrigate: false,
          reason:
              '${rainPrediction.probability}% chance of rain. Consider delaying irrigation.',
          confidence: 'high',
          suggestedAmount: 'none',
        );
      }

      // Low humidity - increase irrigation
      if (weather.humidity < 30 && currentSoilMoisture < 50) {
        return IrrigationAdvice(
          shouldIrrigate: true,
          reason:
              'Low humidity (${weather.humidity}%) accelerating evaporation',
          confidence: 'medium',
          suggestedAmount: 'moderate',
        );
      }

      // Normal conditions
      if (currentSoilMoisture < 40) {
        return IrrigationAdvice(
          shouldIrrigate: true,
          reason: 'Soil moisture below optimal level',
          confidence: 'high',
          suggestedAmount: 'moderate',
        );
      }

      return IrrigationAdvice(
        shouldIrrigate: false,
        reason:
            'Soil moisture at healthy level. No immediate irrigation needed.',
        confidence: 'high',
        suggestedAmount: 'none',
      );
    } catch (e) {
      return IrrigationAdvice(
        shouldIrrigate: currentSoilMoisture < 40,
        reason: 'Weather data unavailable. Based on soil moisture only.',
        confidence: 'low',
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// ------------------------------------------------
/// DATA MODELS
/// ------------------------------------------------

class WeatherData {
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final int windDeg;
  final int cloudiness;
  final int visibility;
  final String description;
  final String icon;
  final String main;
  final DateTime sunrise;
  final DateTime sunset;
  final String cityName;
  final int timezoneOffset; // Offset from UTC in seconds

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDeg,
    required this.cloudiness,
    required this.visibility,
    required this.description,
    required this.icon,
    required this.main,
    required this.sunrise,
    required this.sunset,
    required this.cityName,
    required this.timezoneOffset,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'];
    final weather = json['weather'][0];
    final wind = json['wind'];
    final clouds = json['clouds'];
    final sys = json['sys'];

    return WeatherData(
      temperature: main['temp'].toDouble(),
      feelsLike: main['feels_like'].toDouble(),
      tempMin: main['temp_min'].toDouble(),
      tempMax: main['temp_max'].toDouble(),
      humidity: main['humidity'],
      pressure: main['pressure'],
      windSpeed: wind['speed'].toDouble(),
      windDeg: wind['deg'] ?? 0,
      cloudiness: clouds['all'],
      visibility: json['visibility'] ?? 10000,
      description: weather['description'],
      icon: weather['icon'],
      main: weather['main'],
      sunrise: DateTime.fromMillisecondsSinceEpoch(sys['sunrise'] * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch(sys['sunset'] * 1000),
      cityName: json['name'] ?? '',
      timezoneOffset: json['timezone'] ?? 0, // Offset from UTC in seconds
    );
  }

  /// Get weather icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  /// Get current time in the weather location's timezone
  DateTime get localTime {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(Duration(seconds: timezoneOffset));
  }

  /// Check if it's currently raining
  bool get isRaining => main.toLowerCase().contains('rain');

  /// Get UV recommendation (simplified)
  String get uvAdvice {
    if (cloudiness > 80) return 'Low UV - Cloudy conditions';
    if (temperature > 30) return 'High UV - Protect crops from direct sunlight';
    return 'Moderate UV - Normal conditions';
  }
}

class WeatherForecast {
  final List<ForecastItem> list;
  final String cityName;
  final int timezoneOffset; // Offset from UTC in seconds

  WeatherForecast({
    required this.list,
    required this.cityName,
    required this.timezoneOffset,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final List<dynamic> listData = json['list'];
    final cityData = json['city'];
    return WeatherForecast(
      list: listData.map((item) => ForecastItem.fromJson(item)).toList(),
      cityName: cityData['name'] ?? '',
      timezoneOffset: cityData['timezone'] ?? 0, // Timezone offset in seconds
    );
  }

  /// Convert UTC time to local time based on timezone offset
  DateTime toLocalTime(DateTime utcTime) {
    return utcTime.add(Duration(seconds: timezoneOffset));
  }

  /// Get current time in this forecast location's timezone
  DateTime get localNow {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(Duration(seconds: timezoneOffset));
  }

  /// Get forecast for specific day
  List<ForecastItem> getForecastForDay(int daysFromNow) {
    final targetDate = localNow.add(Duration(days: daysFromNow));
    return list.where((item) {
      final localTime = toLocalTime(item.dateTime);
      return localTime.day == targetDate.day &&
          localTime.month == targetDate.month;
    }).toList();
  }

  /// Get daily summary
  List<DailySummary> getDailySummaries() {
    final Map<String, List<ForecastItem>> dailyData = {};

    for (final item in list) {
      final localTime = toLocalTime(item.dateTime);
      final key = '${localTime.year}-${localTime.month}-${localTime.day}';
      dailyData.putIfAbsent(key, () => []);
      dailyData[key]!.add(item);
    }

    return dailyData.entries.map((entry) {
      final items = entry.value;
      final temps = items.map((i) => i.temperature).toList();
      final hasRain = items.any(
        (i) => i.weather.any((w) => w.main.toLowerCase().contains('rain')),
      );
      final maxPop = items.map((i) => i.pop).reduce((a, b) => a > b ? a : b);

      return DailySummary(
        date: toLocalTime(items.first.dateTime),
        tempMin: temps.reduce((a, b) => a < b ? a : b),
        tempMax: temps.reduce((a, b) => a > b ? a : b),
        hasRain: hasRain,
        rainProbability: (maxPop * 100).toInt(),
        description: items[items.length ~/ 2].weather.first.description,
        icon: items[items.length ~/ 2].weather.first.icon,
      );
    }).toList();
  }
}

class ForecastItem {
  final DateTime dateTime;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final List<WeatherCondition> weather;
  final double windSpeed;
  final double pop; // Probability of precipitation
  final RainData? rain;

  ForecastItem({
    required this.dateTime,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.weather,
    required this.windSpeed,
    required this.pop,
    this.rain,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    final main = json['main'];
    final List<dynamic> weatherList = json['weather'];

    return ForecastItem(
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      temperature: main['temp'].toDouble(),
      feelsLike: main['feels_like'].toDouble(),
      humidity: main['humidity'],
      weather: weatherList.map((w) => WeatherCondition.fromJson(w)).toList(),
      windSpeed: json['wind']['speed'].toDouble(),
      pop: (json['pop'] ?? 0).toDouble(),
      rain: json['rain'] != null ? RainData.fromJson(json['rain']) : null,
    );
  }
}

class WeatherCondition {
  final int id;
  final String main;
  final String description;
  final String icon;

  WeatherCondition({
    required this.id,
    required this.main,
    required this.description,
    required this.icon,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      id: json['id'],
      main: json['main'],
      description: json['description'],
      icon: json['icon'],
    );
  }
}

class RainData {
  final double threeHour;

  RainData({required this.threeHour});

  factory RainData.fromJson(Map<String, dynamic> json) {
    return RainData(threeHour: (json['3h'] ?? 0).toDouble());
  }
}

class DailySummary {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final bool hasRain;
  final int rainProbability;
  final String description;
  final String icon;

  DailySummary({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.hasRain,
    required this.rainProbability,
    required this.description,
    required this.icon,
  });

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

class RainPrediction {
  final bool willRain;
  final int probability;
  final DateTime? expectedTime;
  final double rainAmount;
  final String message;

  RainPrediction({
    required this.willRain,
    required this.probability,
    required this.expectedTime,
    this.rainAmount = 0,
    required this.message,
  });
}

class IrrigationAdvice {
  final bool shouldIrrigate;
  final String reason;
  final String confidence; // 'high', 'medium', 'low'
  final String? suggestedAmount; // 'none', 'light', 'moderate', 'heavy'

  IrrigationAdvice({
    required this.shouldIrrigate,
    required this.reason,
    required this.confidence,
    this.suggestedAmount,
  });
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}
