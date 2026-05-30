import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/user_counter_service.dart';
import '../../services/weather_service.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  final WeatherService _weatherService = WeatherService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WeatherData? _weatherData;
  WeatherForecast? _forecastData;
  bool _isLoading = true;
  String? _error;
  String _farmName = '';

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await UserCounterService().getUserByAuthUid(user.uid);
        if (userDoc != null && userDoc.exists) {
          final detailsDoc = await _firestore
              .collection('users').doc(userDoc.id).collection('farm').doc('details').get();
          _farmName = detailsDoc.data()?['name'] as String? ?? '';
        }
      }

      final weather = await _weatherService.getCurrentWeather();
      final forecast = await _weatherService.getWeatherForecast();
      setState(() {
        _weatherData = weather;
        _forecastData = forecast;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _error != null || _weatherData == null
                ? _buildErrorView()
                : _buildWeatherContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: ThemeColors.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Weather Unavailable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your location settings',
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadWeather,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    final weather = _weatherData!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildMainWeatherCard(weather),
          const SizedBox(height: 16),
          _buildFarmingTip(weather),
          const SizedBox(height: 24),
          _buildWeatherDetailsGrid(weather),
          const SizedBox(height: 24),
          _buildHourlyForecast(weather),
          const SizedBox(height: 24),
          _buildWeeklyForecast(weather),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(Icons.arrow_back, color: ThemeColors.icon(context), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Farm Weather',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              if (_farmName.isNotEmpty)
                Text(
                  _farmName,
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.55),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  LinearGradient _weatherGradient(WeatherData weather) {
    final main = weather.main.toLowerCase();
    final isNight = weather.iconUrl.contains('n@');

    if (main.contains('thunder')) {
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2D1B69), Color(0xFF0D0D0D)],
      );
    }
    if (main.contains('snow')) {
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFB0C4DE), Color(0xFF4682B4)],
      );
    }
    if (main.contains('rain')) {
      // differentiate light vs heavy by description
      final desc = weather.description.toLowerCase();
      if (desc.contains('heavy') || desc.contains('extreme')) {
        return const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF0A0A1A)],
        );
      }
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
      );
    }
    if (main.contains('drizzle')) {
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4682B4), Color(0xFF2C5282)],
      );
    }
    if (main.contains('mist') || main.contains('fog') || main.contains('haze') || main.contains('smoke') || main.contains('dust')) {
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF78909C), Color(0xFF546E7A)],
      );
    }
    if (main.contains('cloud')) {
      final desc = weather.description.toLowerCase();
      if (desc.contains('overcast') || desc.contains('broken')) {
        return const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF607D8B), Color(0xFF37474F)],
        );
      }
      // Few/scattered clouds
      return isNight
          ? const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF283593)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
            );
    }
    // Clear
    return isNight
        ? const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B4B), Color(0xFF1A237E)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFB300), Color(0xFFE65100)],
          );
  }

  String _weatherBgUrl(WeatherData weather) {
    final main = weather.main.toLowerCase();
    final desc = weather.description.toLowerCase();
    final isNight = weather.iconUrl.contains('n@');

    if (main.contains('thunder')) {
      return 'https://images.unsplash.com/photo-1605727216801-e27ce1d0cc28?w=800&q=80';
    }
    if (main.contains('snow')) {
      return 'https://images.unsplash.com/photo-1491002052546-bf38f186af56?w=800&q=80';
    }
    if (main.contains('rain')) {
      if (desc.contains('heavy') || desc.contains('extreme')) {
        return 'https://images.unsplash.com/photo-1519692933481-e162a57d6721?w=800&q=80';
      }
      return 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800&q=80';
    }
    if (main.contains('drizzle')) {
      return 'https://images.unsplash.com/photo-1541919329513-35f7af297129?w=800&q=80';
    }
    if (main.contains('mist') || main.contains('fog') || main.contains('haze') || main.contains('smoke')) {
      return 'https://images.unsplash.com/photo-1543968996-ee822b8176ba?w=800&q=80';
    }
    if (main.contains('cloud')) {
      if (desc.contains('overcast') || desc.contains('broken')) {
        return 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=800&q=80';
      }
      return 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=800&q=80';
    }
    // Clear
    if (isNight) {
      return 'https://images.unsplash.com/photo-1507400492013-162706c8c05e?w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1601297183305-6df142704ea2?w=800&q=80';
  }

  Widget _buildMainWeatherCard(WeatherData weather) {
    final bgUrl = _weatherBgUrl(weather);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
        children: [
          // Background photo
          Positioned.fill(
            child: Image.network(
              bgUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(gradient: _weatherGradient(weather)),
              ),
            ),
          ),
          // Dark overlay for text readability
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x88000000)],
                ),
              ),
            ),
          ),
          // Content
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Image.network(
                  weather.iconUrl,
                  width: 100,
                  height: 100,
                  errorBuilder: (_, __, ___) => const FaIcon(
                    FontAwesomeIcons.cloudSun,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${weather.temperature.round()}°C',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  weather.description.isNotEmpty
                      ? weather.description[0].toUpperCase() + weather.description.substring(1)
                      : weather.main,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(FontAwesomeIcons.locationDot, size: 13, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      weather.cityName,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(FontAwesomeIcons.temperatureArrowDown, size: 13, color: Colors.lightBlueAccent),
                    const SizedBox(width: 4),
                    Text('${weather.tempMin.round()}°', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 20),
                    const FaIcon(FontAwesomeIcons.temperatureArrowUp, size: 13, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text('${weather.tempMax.round()}°', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFarmingTip(WeatherData weather) {
    String tip = '';
    IconData icon = Icons.eco;

    if (weather.main.toLowerCase() == 'rain') {
      tip = 'Good for natural irrigation. Avoid fertilizing today.';
      icon = Icons.water_drop;
    } else if (weather.temperature > 30) {
      tip = 'High temperature. Ensure adequate irrigation for crops.';
      icon = Icons.thermostat;
    } else if (weather.humidity > 80) {
      tip = 'High humidity. Monitor crops for fungal diseases.';
      icon = Icons.cloud;
    } else {
      tip = 'Good for irrigation. Moderate evaporation expected today. Ensure soil moisture stays above 40%.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: ThemeColors.textPrimary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsGrid(WeatherData weather) {
    final rainChance = weather.main.toLowerCase().contains('rain') ? 80 : 15;
    final uvIndex = weather.main.toLowerCase().contains('clear') ? 6 : 3;
    final uvLabel = uvIndex > 5 ? 'High' : 'Moderate';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.droplet,
                iconColor: Colors.lightBlueAccent,
                label: 'Humidity',
                value: '${weather.humidity}%',
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.wind,
                iconColor: Colors.tealAccent,
                label: 'Wind Speed',
                value: '${weather.windSpeed.toStringAsFixed(1)} m/s',
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.umbrellaBeach,
                iconColor: Colors.blueAccent,
                label: 'Rain Chance',
                value: '$rainChance%',
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.sun,
                iconColor: Colors.amber,
                label: 'UV Index',
                value: '$uvLabel ($uvIndex)',
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.eye,
                iconColor: Colors.purpleAccent,
                label: 'Visibility',
                value: '${(weather.visibility / 1000).toStringAsFixed(1)} km',
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildWeatherDetailCard(
                faIcon: FontAwesomeIcons.gaugeHigh,
                iconColor: Colors.orangeAccent,
                label: 'Pressure',
                value: '${weather.pressure} hPa',
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailCard({
    required FaIconData faIcon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(faIcon, size: 14, color: iconColor),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textSecondary(context).withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(WeatherData weather) {
    // Use real forecast data if available
    final hourlyData = _forecastData?.list.take(8).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Hourly',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: hourlyData.isEmpty
              ? Center(
                  child: Text(
                    'Hourly forecast unavailable',
                    style: TextStyle(
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hourlyData.length,
                  itemBuilder: (context, index) {
                    final item = hourlyData[index];
                    final isNow = index == 0;
                    final iconCode = item.weather.isNotEmpty ? item.weather.first.icon : '01d';
                    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';
                    final localTime = _forecastData!.toLocalTime(item.dateTime);

                    return _buildHourlyItem(
                      time: isNow ? 'Now' : DateFormat('h a').format(localTime),
                      iconUrl: iconUrl,
                      temperature: '${item.temperature.round()}°',
                      isNow: isNow,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHourlyItem({
    required String time,
    required String iconUrl,
    required String temperature,
    bool isNow = false,
  }) {
    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isNow ? AppColors.primary.withOpacity(0.2) : ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNow ? AppColors.primary : ThemeColors.border(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isNow ? FontWeight.w600 : FontWeight.normal,
              color: isNow ? AppColors.primary : ThemeColors.textSecondary(context).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Image.network(
            iconUrl,
            width: 44,
            height: 44,
            errorBuilder: (_, __, ___) => const FaIcon(FontAwesomeIcons.cloudSun, size: 28, color: Colors.grey),
          ),
          Text(
            temperature,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecast(WeatherData weather) {
    // Use real daily summaries from forecast data
    final dailySummaries = _forecastData?.getDailySummaries() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'This Week',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        dailySummaries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Weekly forecast unavailable',
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dailySummaries.length,
                itemBuilder: (context, index) {
                  final summary = dailySummaries[index];
                  final dayName = index == 0
                      ? 'Tomorrow'
                      : DateFormat('EEEE').format(summary.date);
                  final iconUrl = 'https://openweathermap.org/img/wn/${summary.icon}@2x.png';

                  return _buildWeeklyItem(
                    day: dayName,
                    iconUrl: iconUrl,
                    description: summary.description.isNotEmpty
                        ? summary.description[0].toUpperCase() + summary.description.substring(1)
                        : 'Clear',
                    highTemp: '${summary.tempMax.round()}°',
                    lowTemp: '${summary.tempMin.round()}°',
                    hasRain: summary.hasRain,
                    rainProbability: summary.rainProbability,
                  );
                },
              ),
      ],
    );
  }

  Widget _buildWeeklyItem({
    required String day,
    required String iconUrl,
    required String description,
    required String highTemp,
    required String lowTemp,
    required bool hasRain,
    required int rainProbability,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textPrimary(context),
              ),
            ),
          ),
          Image.network(
            iconUrl,
            width: 40,
            height: 40,
            errorBuilder: (_, __, ___) => const FaIcon(FontAwesomeIcons.cloudSun, size: 22, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasRain && rainProbability > 0)
                  Row(children: [
                    const FaIcon(FontAwesomeIcons.umbrella, size: 10, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text('$rainProbability%', style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                  ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                const FaIcon(FontAwesomeIcons.temperatureArrowUp, size: 10, color: Colors.orangeAccent),
                const SizedBox(width: 3),
                Text(highTemp, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ThemeColors.textPrimary(context))),
              ]),
              Row(children: [
                const FaIcon(FontAwesomeIcons.temperatureArrowDown, size: 10, color: Colors.lightBlueAccent),
                const SizedBox(width: 3),
                Text(lowTemp, style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.6))),
              ]),
            ],
          ),
        ],
      ),
    );
  }

}
