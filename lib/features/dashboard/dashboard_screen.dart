import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/theme.dart';
import '../../services/weather_service.dart';

/// ------------------------------------------------------------
/// DASHBOARD SCREEN (HOME TAB)
///
/// Firebase Structure (RTDB):
/// sensors/
///   ESP32_001/
///     humidity: 70
///     lastSeen: 1700000000
///     ph: 6.3
///     sensorHealth/
///       ph: "ok"
///       soil: "ok"
///       waterLevel: "error"
///     soil: 45
///     temp: 30
///     waterLevel: 80
///
/// Shows:
/// - Active Field Selector + Online Status
/// - Weather Card (from OpenWeather API)
/// - Sensor Grid (Soil Moisture, pH, Temp, Humidity)
/// - Water Tank Level
/// ------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WeatherService _weatherService = WeatherService();

  String? _selectedCropId;
  String? _selectedDeviceId;
  String? _selectedCropType;

  // Weather data
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final weather = await _weatherService.getCurrentWeather();
      setState(() {
        _weatherData = weather;
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _weatherError = e.toString();
        _isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Field Selector
                _buildHeader(),
                const SizedBox(height: 20),

                // Overview Section
                _buildOverviewHeader(),
                const SizedBox(height: 16),

                // Weather Card (Live from OpenWeather API)
                _buildWeatherCard(),
                const SizedBox(height: 16),

                // Sensor Grid (Live from RTDB)
                _buildSensorGrid(),
                const SizedBox(height: 16),

                // Water Tank Card
                _buildWaterTankCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// HEADER WITH FIELD SELECTOR
  /// ------------------------------------------------
  Widget _buildHeader() {
    final user = _auth.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final crops = snapshot.data?.docs ?? [];

        // Auto-select first crop if none selected
        if (crops.isNotEmpty && _selectedCropId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final firstCrop = crops.first;
            final data = firstCrop.data() as Map<String, dynamic>;
            setState(() {
              _selectedCropId = firstCrop.id;
              _selectedDeviceId = data['device_id'];
              _selectedCropType = data['crop_type'];
            });
          });
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE FIELD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCropId,
                            isDense: true,
                            dropdownColor: AppColors.surfaceDark,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                            ),
                            hint: const Text(
                              'Select Field',
                              style: TextStyle(color: Colors.white),
                            ),
                            items: crops.map((crop) {
                              final data = crop.data() as Map<String, dynamic>;
                              final cropType = data['crop_type'] ?? 'Unknown';
                              return DropdownMenuItem<String>(
                                value: crop.id,
                                child: Text(
                                  '$cropType Field A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final crop = crops.firstWhere(
                                  (c) => c.id == value,
                                );
                                final data =
                                    crop.data() as Map<String, dynamic>;
                                setState(() {
                                  _selectedCropId = value;
                                  _selectedDeviceId = data['device_id'];
                                  _selectedCropType = data['crop_type'];
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Online Status Badge (from RTDB lastSeen)
            _buildOnlineStatusBadge(),
          ],
        );
      },
    );
  }

  /// Online status based on lastSeen timestamp from RTDB
  Widget _buildOnlineStatusBadge() {
    if (_selectedDeviceId == null) {
      return _buildStatusBadge(false);
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$_selectedDeviceId/lastSeen').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        bool isOnline = false;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final lastSeen = snapshot.data!.snapshot.value as int;
          final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(
            lastSeen * 1000,
          );
          final diff = DateTime.now().difference(lastSeenDate);
          // Consider online if last seen within 5 minutes
          isOnline = diff.inMinutes < 5;
        }

        return _buildStatusBadge(isOnline);
      },
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.primary : AppColors.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isOnline
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.error.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOnline ? AppColors.primary : AppColors.error,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// OVERVIEW HEADER
  /// ------------------------------------------------
  Widget _buildOverviewHeader() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Today, ${months[now.month - 1]} ${now.day}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        // Notification Button
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 22,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// WEATHER CARD (Live from OpenWeather API)
  /// ------------------------------------------------
  Widget _buildWeatherCard() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_weatherError != null || _weatherData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: Colors.white.withOpacity(0.5),
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weather Unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set farm location in settings',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _loadWeather,
            ),
          ],
        ),
      );
    }

    final weather = _weatherData!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getWeatherIcon(weather.main),
                      color: _getWeatherIconColor(weather.main),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      weather.description.isNotEmpty
                          ? weather.description[0].toUpperCase() +
                                weather.description.substring(1)
                          : weather.main,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${weather.temperature.toInt()}°C',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.water_drop,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${weather.humidity}% Humidity',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.air,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${weather.windSpeed.toInt()} km/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Weather Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getWeatherIconColor(weather.main).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getWeatherIcon(weather.main),
              size: 48,
              color: _getWeatherIconColor(weather.main),
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
      case 'mist':
      case 'fog':
      case 'haze':
        return Icons.blur_on;
      default:
        return Icons.wb_cloudy;
    }
  }

  Color _getWeatherIconColor(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Colors.amber;
      case 'clouds':
        return Colors.grey;
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

  /// ------------------------------------------------
  /// SENSOR GRID (Live from RTDB)
  /// RTDB Structure:
  /// sensors/ESP32_001/
  ///   soil: 45
  ///   ph: 6.3
  ///   temp: 30
  ///   humidity: 70
  ///   sensorHealth/soil: "ok"
  ///   sensorHealth/ph: "ok"
  /// ------------------------------------------------
  Widget _buildSensorGrid() {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard();
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$_selectedDeviceId').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        // Default values
        int soil = 0;
        double ph = 0.0;
        int temp = 0;
        int humidity = 0;
        Map<String, String> sensorHealth = {};

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rootData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          // Read from live node
          if (rootData['live'] != null) {
            final data = Map<String, dynamic>.from(rootData['live']);

            soil = data['soil'] != null
                ? (data['soil'] is int ? data['soil'] : (data['soil'] as num).toInt())
                : 0;
            ph = data['ph'] != null
                ? (data['ph'] is double ? data['ph'] : (data['ph'] as num).toDouble())
                : 0.0;
            temp = data['temp'] != null
                ? (data['temp'] is int ? data['temp'] : (data['temp'] as num).toInt())
                : 0;
            humidity = data['humidity'] != null
                ? (data['humidity'] is int ? data['humidity'] : (data['humidity'] as num).toInt())
                : 0;
          }

          // Parse sensorHealth from sensorHealth node
          if (rootData['sensorHealth'] != null) {
            final healthData = Map<String, dynamic>.from(rootData['sensorHealth']);
            sensorHealth = healthData.map((k, v) => MapEntry(k, v.toString()));
          }
        }

        return Column(
          children: [
            // Row 1: Soil Moisture & pH Level
            Row(
              children: [
                Expanded(
                  child: _buildSensorCard(
                    icon: Icons.water_drop,
                    iconColor: AppColors.soilMoisture,
                    iconBgColor: AppColors.soilMoistureBackground,
                    label: 'SOIL MOISTURE',
                    value: '$soil',
                    unit: '%',
                    status: _getSoilStatus(soil),
                    statusColor: _getSoilStatusColor(soil),
                    progressColor: AppColors.soilMoisture,
                    progressValue: soil / 100,
                    sensorHealth: sensorHealth['soil'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSensorCard(
                    icon: Icons.science,
                    iconColor: AppColors.phLevel,
                    iconBgColor: AppColors.phLevelBackground,
                    label: 'PH LEVEL',
                    value: ph.toStringAsFixed(1),
                    unit: '',
                    status: _getPhStatus(ph),
                    statusColor: _getPhStatusColor(ph),
                    progressColor: AppColors.phLevel,
                    progressValue: ph / 14,
                    sensorHealth: sensorHealth['ph'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Temperature & Humidity
            Row(
              children: [
                Expanded(
                  child: _buildSensorCard(
                    icon: Icons.thermostat,
                    iconColor: AppColors.temperature,
                    iconBgColor: AppColors.temperatureBackground,
                    label: 'TEMPERATURE',
                    value: '$temp',
                    unit: '°C',
                    status: _getTempStatus(temp),
                    statusColor: _getTempStatusColor(temp),
                    progressColor: AppColors.temperature,
                    progressValue: temp / 50,
                    isWarning: temp > 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSensorCard(
                    icon: Icons.cloud,
                    iconColor: AppColors.humidity,
                    iconBgColor: AppColors.humidityBackground,
                    label: 'HUMIDITY',
                    value: '$humidity',
                    unit: '%',
                    status: _getHumidityStatus(humidity),
                    statusColor: _getHumidityStatusColor(humidity),
                    progressColor: AppColors.humidity,
                    progressValue: humidity / 100,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required Color progressColor,
    required double progressValue,
    bool isWarning = false,
    String? sensorHealth,
  }) {
    // Check if sensor has error
    final hasError = sensorHealth == 'error';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.error.withOpacity(0.5)
              : isWarning
              ? AppColors.warning.withOpacity(0.5)
              : AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasError
                      ? AppColors.error.withOpacity(0.1)
                      : iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: hasError ? AppColors.error : iconColor,
                  size: 22,
                ),
              ),
              Icon(
                hasError
                    ? Icons.error
                    : isWarning
                    ? Icons.warning
                    : Icons.check_circle,
                color: hasError
                    ? AppColors.error
                    : isWarning
                    ? AppColors.warning
                    : AppColors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasError ? '--' : value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: hasError ? AppColors.error : Colors.white,
                ),
              ),
              if (unit.isNotEmpty && !hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Status
          Text(
            hasError ? 'Sensor Error' : status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError ? AppColors.error : statusColor,
            ),
          ),
          const SizedBox(height: 12),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: hasError ? 0 : progressValue.clamp(0.0, 1.0),
              backgroundColor: AppColors.backgroundDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasError ? AppColors.error : progressColor,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sensors_off,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Device Selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a field to view sensor data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// WATER TANK CARD
  /// RTDB: sensors/ESP32_001/waterLevel: 80
  /// RTDB: sensors/ESP32_001/sensorHealth/waterLevel: "error"
  /// ------------------------------------------------
  Widget _buildWaterTankCard() {
    if (_selectedDeviceId == null) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$_selectedDeviceId').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        int waterLevel = 0;
        String? healthStatus;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rootData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          // Read waterLevel from live node
          if (rootData['live'] != null) {
            final data = Map<String, dynamic>.from(rootData['live']);
            waterLevel = data['waterLevel'] != null
                ? (data['waterLevel'] is int ? data['waterLevel'] : (data['waterLevel'] as num).toInt())
                : 0;
          }

          // Read health status from sensorHealth node
          if (rootData['sensorHealth'] != null) {
            final health = Map<String, dynamic>.from(rootData['sensorHealth']);
            healthStatus = health['waterLevel']?.toString();
          }
        }

        final hasError = healthStatus == 'error';
        final isCritical = waterLevel < 20 && !hasError;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AppColors.error.withOpacity(0.5)
                  : isCritical
                  ? AppColors.error.withOpacity(0.5)
                  : AppColors.borderDark,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasError || isCritical
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.soilMoistureBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasError ? Icons.error_outline : Icons.water,
                      color: hasError || isCritical
                          ? AppColors.error
                          : AppColors.soilMoisture,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Water Tank Level',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasError
                              ? 'SENSOR ERROR'
                              : isCritical
                              ? 'CRITICAL LOW'
                              : 'Normal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasError || isCritical
                                ? AppColors.error
                                : AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    hasError ? '--%' : '$waterLevel%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hasError ? AppColors.error : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hasError ? 0 : waterLevel / 100,
                  backgroundColor: AppColors.backgroundDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasError || isCritical
                        ? AppColors.error
                        : AppColors.soilMoisture,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ------------------------------------------------
  /// STATUS HELPER METHODS
  /// ------------------------------------------------
  String _getSoilStatus(int value) {
    if (value < 30) return 'Low';
    if (value > 80) return 'High';
    return 'Normal';
  }

  Color _getSoilStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 80) return AppColors.warning;
    return AppColors.primary;
  }

  String _getPhStatus(double value) {
    if (value < 5.5) return 'Acidic';
    if (value > 7.5) return 'Alkaline';
    return 'Optimal';
  }

  Color _getPhStatusColor(double value) {
    if (value < 5.5) return AppColors.warning;
    if (value > 7.5) return AppColors.warning;
    return AppColors.primary;
  }

  String _getTempStatus(int value) {
    if (value < 15) return 'Low';
    if (value > 30) return 'High Warning';
    return 'Normal';
  }

  Color _getTempStatusColor(int value) {
    if (value < 15) return AppColors.info;
    if (value > 30) return AppColors.warning;
    return AppColors.primary;
  }

  String _getHumidityStatus(int value) {
    if (value < 30) return 'Low';
    if (value > 70) return 'High';
    return 'Normal';
  }

  Color _getHumidityStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 70) return AppColors.warning;
    return AppColors.primary;
  }
}
