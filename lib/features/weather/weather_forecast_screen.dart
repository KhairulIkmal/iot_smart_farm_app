import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/weather_service.dart';

/// Weather Forecast Screen
/// Shows detailed weather information including:
/// - Current weather with temperature
/// - Humidity, Wind, Rain Chance, UV Index
/// - Hourly forecast
/// - Weekly forecast
class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final weather = await _weatherService.getCurrentWeather();
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Weather Unavailable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your location settings',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
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
          // Header with back button
          _buildHeader(),
          const SizedBox(height: 16),

          // Main weather card
          _buildMainWeatherCard(weather),
          const SizedBox(height: 16),

          // Farming tip
          _buildFarmingTip(weather),
          const SizedBox(height: 24),

          // Weather details grid
          _buildWeatherDetailsGrid(weather),
          const SizedBox(height: 24),

          // Hourly forecast
          _buildHourlyForecast(weather),
          const SizedBox(height: 24),

          // Weekly forecast
          _buildWeeklyForecast(weather),
          const SizedBox(height: 24),
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
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Weather Forecast',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainWeatherCard(WeatherData weather) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            _getWeatherIcon(weather.main),
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            '${weather.temperature.round()}°C',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weather.description.isNotEmpty
                ? weather.description[0].toUpperCase() +
                    weather.description.substring(1)
                : weather.main,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                weather.cityName,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFarmingTip(WeatherData weather) {
    String tip = '';
    IconData icon = Icons.eco;

    // Generate farming tip based on weather
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
      tip =
          'Good for irrigation. Moderate evaporation expected today. Ensure soil moisture stays above 40%.';
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
          Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsGrid(WeatherData weather) {
    // Calculate simulated values (in a real app, these would come from API)
    final rainChance = weather.main.toLowerCase() == 'rain' ? 80 : 15;
    final uvIndex = weather.main.toLowerCase() == 'clear' ? 6 : 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildWeatherDetailCard(
                  icon: Icons.water_drop_outlined,
                  label: 'Humidity',
                  value: '${weather.humidity.round()}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWeatherDetailCard(
                  icon: Icons.air,
                  label: 'Wind',
                  value: '${weather.windSpeed.round()} km/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWeatherDetailCard(
                  icon: Icons.grain,
                  label: 'Rain Chance',
                  value: '$rainChance%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWeatherDetailCard(
                  icon: Icons.wb_sunny,
                  label: 'UV Index',
                  value: uvIndex > 5 ? 'High ($uvIndex)' : 'Moderate ($uvIndex)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(WeatherData weather) {
    // Simulate different weather conditions for hourly forecast
    final hourlyConditions = [
      weather.main, // Now - use current weather
      weather.main,
      weather.main.toLowerCase() == 'clear' ? 'Clouds' : weather.main,
      'Clouds',
      weather.main.toLowerCase() == 'rain' ? 'Rain' : 'Clouds',
      weather.main,
      weather.main.toLowerCase() == 'clear' ? 'Clear' : weather.main,
      'Clouds',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Hourly',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 8,
            itemBuilder: (context, index) {
              final hour = DateTime.now().add(Duration(hours: index));
              final temp = weather.temperature + (index % 3 - 1);
              final isNow = index == 0;
              final condition = hourlyConditions[index];

              return _buildHourlyItem(
                time: isNow ? 'Now' : DateFormat('h a').format(hour),
                icon: _getWeatherIcon(condition),
                iconColor: _getWeatherIconColorFromCondition(condition),
                temperature: '${temp.round()}°',
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
    required IconData icon,
    required Color iconColor,
    required String temperature,
    bool isNow = false,
  }) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isNow
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNow
              ? AppColors.primary
              : AppColors.borderDark,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            icon,
            size: 28,
            color: isNow ? AppColors.primary : iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            temperature,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecast(WeatherData weather) {
    final days = ['Tomorrow', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon'];
    final conditions = ['rain', 'clouds', 'clear', 'clouds', 'clear', 'rain', 'clear'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'This Week',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final high = weather.temperature + (index % 5);
            final low = weather.temperature - (5 - index % 5);

            return _buildWeeklyItem(
              day: days[index],
              condition: conditions[index],
              highTemp: '${high.round()}°',
              lowTemp: '${low.round()}°',
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyItem({
    required String day,
    required String condition,
    required String highTemp,
    required String lowTemp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            _getWeatherIconFromCondition(condition),
            size: 24,
            color: _getWeatherColorFromCondition(condition),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getWeatherLabel(condition),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            '$highTemp / $lowTemp',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.water_drop;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }

  IconData _getWeatherIconFromCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.water_drop;
      default:
        return Icons.wb_cloudy;
    }
  }

  Color _getWeatherColorFromCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Colors.amber;
      case 'clouds':
        return Colors.grey;
      case 'rain':
        return AppColors.soilMoisture;
      default:
        return Colors.grey;
    }
  }

  Color _getWeatherIconColorFromCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Colors.amber;
      case 'clouds':
        return Colors.grey.shade400;
      case 'rain':
      case 'drizzle':
        return AppColors.soilMoisture;
      case 'thunderstorm':
        return Colors.purple;
      case 'snow':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }

  String _getWeatherLabel(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Sunny';
      case 'clouds':
        return 'Cloudy';
      case 'rain':
        return 'Rain likely';
      default:
        return 'Partly Cloudy';
    }
  }
}
