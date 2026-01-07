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
  WeatherForecast? _forecastData;
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
      final forecast = await _weatherService.getWeatherForecast();
      setState(() {
        _weatherData = weather;
        _forecastData = forecast;
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
            _getWeatherIconFromCondition(weather.description.isNotEmpty
                ? weather.description
                : weather.main),
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
    // Use real forecast data if available
    final hourlyData = _forecastData?.list.take(8).toList() ?? [];

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
          child: hourlyData.isEmpty
              ? Center(
                  child: Text(
                    'Hourly forecast unavailable',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
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
                    final condition = item.weather.isNotEmpty
                        ? item.weather.first.main
                        : 'Clear';

                    // Convert to local time using timezone offset
                    final localTime = _forecastData!.toLocalTime(item.dateTime);

                    return _buildHourlyItem(
                      time: isNow
                          ? 'Now'
                          : DateFormat('h a').format(localTime),
                      icon: _getWeatherIcon(condition),
                      iconColor: _getWeatherIconColorFromCondition(condition),
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
    // Use real daily summaries from forecast data
    final dailySummaries = _forecastData?.getDailySummaries() ?? [];

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
        dailySummaries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Weekly forecast unavailable',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
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
                      : DateFormat('EEE').format(summary.date);

                  // Extract main weather condition from description
                  String condition = 'clear';
                  if (summary.description.toLowerCase().contains('rain') ||
                      summary.description.toLowerCase().contains('drizzle')) {
                    condition = 'rain';
                  } else if (summary.description.toLowerCase().contains('cloud')) {
                    condition = 'clouds';
                  } else if (summary.description.toLowerCase().contains('clear') ||
                      summary.description.toLowerCase().contains('sun')) {
                    condition = 'clear';
                  }

                  return _buildWeeklyItem(
                    day: dayName,
                    condition: condition,
                    highTemp: '${summary.tempMax.round()}°',
                    lowTemp: '${summary.tempMin.round()}°',
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
        return Icons.wb_sunny; // bright sun for clear day
      case 'clouds':
        return Icons.cloud; // cloud icon
      case 'rain':
        return Icons.grain; // rain drops icon
      case 'drizzle':
        return Icons.water_drop; // single droplet
      case 'thunderstorm':
        return Icons.flash_on; // lightning bolt
      case 'snow':
        return Icons.ac_unit; // snowflake
      case 'mist':
      case 'fog':
      case 'haze':
        return Icons.cloud_queue; // foggy/hazy
      default:
        return Icons.wb_cloudy; // partly cloudy default
    }
  }

  IconData _getWeatherIconFromCondition(String condition) {
    final conditionLower = condition.toLowerCase();

    // Check for thunderstorm with rain (cloud + lightning)
    if (conditionLower.contains('thunder') || conditionLower.contains('storm')) {
      return Icons.flash_on; // lightning bolt for thunderstorms
    }

    // Heavy intensity rain (more dramatic icon)
    if (conditionLower.contains('heavy') || conditionLower.contains('extreme')) {
      return Icons.thunderstorm; // cloud with heavy rain
    }

    // Moderate rain
    if (conditionLower.contains('moderate rain') ||
        (conditionLower.contains('rain') &&
         !conditionLower.contains('light') &&
         !conditionLower.contains('drizzle'))) {
      return Icons.grain; // rain drops for moderate rain
    }

    // Light rain or drizzle (single droplet)
    if (conditionLower.contains('drizzle') ||
        conditionLower.contains('light')) {
      return Icons.water_drop; // single droplet for light rain
    }

    // Cloudy conditions
    if (conditionLower.contains('cloud') || conditionLower.contains('overcast')) {
      if (conditionLower.contains('partly') || conditionLower.contains('few')) {
        return Icons.wb_cloudy; // partly cloudy
      }
      return Icons.cloud; // fully cloudy
    }

    // Clear/sunny
    if (conditionLower.contains('clear') || conditionLower.contains('sunny')) {
      return Icons.wb_sunny;
    }

    // Mist/fog/haze
    if (conditionLower.contains('mist') || conditionLower.contains('fog') ||
        conditionLower.contains('haze')) {
      return Icons.cloud_queue;
    }

    // Snow
    if (conditionLower.contains('snow')) {
      return Icons.ac_unit;
    }

    // Default to partly cloudy
    return Icons.wb_cloudy;
  }

  Color _getWeatherColorFromCondition(String condition) {
    final conditionLower = condition.toLowerCase();

    if (conditionLower.contains('thunder') || conditionLower.contains('storm')) {
      return Colors.deepPurple; // purple for thunderstorms
    }
    if (conditionLower.contains('rain') || conditionLower.contains('drizzle')) {
      return Colors.blue; // blue for rain
    }
    if (conditionLower.contains('clear') || conditionLower.contains('sunny')) {
      return Colors.amber; // yellow/amber for sunny
    }
    if (conditionLower.contains('cloud')) {
      return Colors.grey; // grey for clouds
    }
    if (conditionLower.contains('snow')) {
      return Colors.lightBlue; // light blue for snow
    }

    return Colors.grey.shade400; // default grey
  }

  Color _getWeatherIconColorFromCondition(String condition) {
    final conditionLower = condition.toLowerCase();

    // Thunderstorm - purple/violet (most severe)
    if (conditionLower.contains('thunder') || conditionLower.contains('storm')) {
      return Colors.deepPurple.shade300;
    }

    // Heavy/extreme rain - dark blue (very intense)
    if (conditionLower.contains('heavy') || conditionLower.contains('extreme')) {
      return Colors.blue.shade700;
    }

    // Moderate rain - medium blue
    if (conditionLower.contains('moderate') ||
        (conditionLower.contains('rain') &&
         !conditionLower.contains('light') &&
         !conditionLower.contains('drizzle'))) {
      return Colors.blue.shade400;
    }

    // Light rain/drizzle - light blue (gentle)
    if (conditionLower.contains('drizzle') || conditionLower.contains('light')) {
      return Colors.lightBlue.shade300;
    }

    // Clear/sunny - yellow/amber
    if (conditionLower.contains('clear') || conditionLower.contains('sunny')) {
      return Colors.amber.shade400;
    }

    // Clouds - grey
    if (conditionLower.contains('cloud') || conditionLower.contains('overcast')) {
      return Colors.grey.shade400;
    }

    // Snow - light blue
    if (conditionLower.contains('snow')) {
      return Colors.lightBlue.shade200;
    }

    // Mist/fog - grey
    if (conditionLower.contains('mist') || conditionLower.contains('fog') ||
        conditionLower.contains('haze')) {
      return Colors.grey.shade300;
    }

    return Colors.grey.shade400; // default
  }

  String _getWeatherLabel(String condition) {
    final conditionLower = condition.toLowerCase();

    // Thunderstorm
    if (conditionLower.contains('thunder')) {
      return 'Thunderstorms';
    }

    // Rain variations
    if (conditionLower.contains('heavy rain') || conditionLower.contains('moderate rain')) {
      return 'Heavy rain';
    }
    if (conditionLower.contains('light rain')) {
      return 'Light rain';
    }
    if (conditionLower.contains('rain')) {
      return 'Rainy';
    }

    // Drizzle
    if (conditionLower.contains('drizzle')) {
      return 'Drizzle';
    }

    // Cloud variations
    if (conditionLower.contains('overcast')) {
      return 'Overcast';
    }
    if (conditionLower.contains('partly cloud') || conditionLower.contains('few cloud')) {
      return 'Partly cloudy';
    }
    if (conditionLower.contains('cloud')) {
      return 'Cloudy';
    }

    // Clear
    if (conditionLower.contains('clear')) {
      return 'Clear sky';
    }
    if (conditionLower.contains('sunny')) {
      return 'Sunny';
    }

    // Snow
    if (conditionLower.contains('snow')) {
      return 'Snowy';
    }

    // Mist/fog
    if (conditionLower.contains('mist') || conditionLower.contains('fog')) {
      return 'Misty';
    }
    if (conditionLower.contains('haze')) {
      return 'Hazy';
    }

    // Default - return the condition as-is with first letter capitalized
    return condition.isNotEmpty
        ? condition[0].toUpperCase() + condition.substring(1)
        : 'Unknown';
  }
}
