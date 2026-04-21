import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/live_sensor_service.dart';
import '../../services/weather_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/selected_crop_service.dart';
import '../weather/weather_forecast_screen.dart';
import '../analytics/sensor_graph_screen.dart';
import '../more/notifications/notifications_screen.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WeatherService _weatherService = WeatherService();
  final SelectedCropService _selectedCropService = SelectedCropService();

  String? _selectedCropId;
  String? _selectedDeviceId;
  String? _selectedCropType;

  // Weather data
  WeatherData? _weatherData;
  WeatherForecast? _weatherForecast;
  bool _isLoadingWeather = true;
  String? _weatherError;

  // Stream subscription for crop selection
  StreamSubscription<SelectedCropData?>? _cropSelectionSubscription;

  // Crops list and unread count — subscriptions, never recreated on rebuild
  List<QueryDocumentSnapshot> _crops = [];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _cropsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  // Live sensor state — fed by LiveSensorService (one shared RTDB listener for the whole app)
  StreamSubscription<LiveSensorData>? _sensorSubscription;
  int _soil = 0;
  double _ph = 0.0;
  int _temp = 0;
  int _humidity = 0;
  int _waterLevel = 0;
  Map<String, String> _sensorHealth = {};
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();

    // Initialize with currently selected crop if any
    final currentSelection = _selectedCropService.selectedCrop;
    if (currentSelection != null) {
      _selectedCropId = currentSelection.cropId;
      _selectedDeviceId = currentSelection.deviceId;
      _selectedCropType = currentSelection.cropType;
    }

    _loadWeather();

    // Start shared RTDB listener if device already selected
    if (_selectedDeviceId != null) _startSensorListener();

    // Unread count — single subscription, not recreated on every rebuild
    _unreadCountSubscription = NotificationService().getUnreadCountStream()?.listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });

    // Crops list — single subscription drives the field selector and auto-selection logic
    final user = _auth.currentUser;
    if (user != null) {
      _cropsSubscription = _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final crops = snapshot.docs;
        setState(() => _crops = crops);

        // Reset selection if selected crop no longer exists
        if (_selectedCropId != null && !crops.any((c) => c.id == _selectedCropId)) {
          setState(() {
            _selectedCropId = null;
            _selectedDeviceId = null;
            _selectedCropType = null;
          });
          _selectedCropService.clearSelectedCrop();
        }

        // Auto-select first crop if none selected
        if (crops.isNotEmpty && _selectedCropId == null) {
          final firstCrop = crops.first;
          final data = firstCrop.data() as Map<String, dynamic>;
          setState(() {
            _selectedCropId = firstCrop.id;
            _selectedDeviceId = data['device_id'];
            _selectedCropType = data['crop_type'];
          });
          _selectedCropService.updateSelectedCrop(
            cropId: firstCrop.id,
            deviceId: data['device_id'],
            cropType: data['crop_type'],
          );
          _startSensorListener();
        }
      });
    }

    // Listen to selected crop changes from other screens
    _cropSelectionSubscription = _selectedCropService.selectedCropStream.listen((selectedCrop) {
      if (mounted && selectedCrop != null) {
        setState(() {
          _selectedCropId = selectedCrop.cropId;
          _selectedDeviceId = selectedCrop.deviceId;
          _selectedCropType = selectedCrop.cropType;
        });
        _startSensorListener();
      }
    });
  }

  void _startSensorListener() {
    _sensorSubscription?.cancel();
    if (_selectedDeviceId == null) return;

    // Tell the shared service which device to watch.
    // If sensors/irrigation already called this for the same device, it's a no-op.
    LiveSensorService().setDevice(_selectedDeviceId);

    // Seed from cached value so display is instant on tab switch
    final cached = LiveSensorService().currentData;
    if (cached != null) _applySensorData(cached);

    _sensorSubscription = LiveSensorService().stream.listen((data) {
      if (!mounted) return;
      _applySensorData(data);
    });
  }

  void _applySensorData(LiveSensorData data) {
    setState(() {
      _soil = data.soil;
      _ph = data.ph;
      _temp = data.temp;
      _humidity = data.humidity;
      _waterLevel = data.waterLevel;
      _sensorHealth = {
        'soil': data.soilHealth,
        'ph': data.phHealth,
        'waterLevel': data.waterHealth,
      };
      _isOnline = data.isOnline;
    });
  }

  @override
  void dispose() {
    _cropSelectionSubscription?.cancel();
    _sensorSubscription?.cancel();
    _cropsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final weather = await _weatherService.getCurrentWeather();
      final forecast = await _weatherService.getWeatherForecast();
      setState(() {
        _weatherData = weather;
        _weatherForecast = forecast;
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
    final selectedCrop = _selectedCropId != null
        ? _crops.where((c) => c.id == _selectedCropId).firstOrNull
        : null;
    final selectedData = selectedCrop?.data() as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildOnlineStatusBadge(),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showCropSelectorBottomSheet(_crops),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.agriculture, color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: selectedData != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${selectedData['crop_type'] ?? 'Unknown'} - ${selectedData['field_name'] ?? 'Field A'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedData['device_id'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const Text(
                          'Select Field',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Show crop selector bottom sheet
  void _showCropSelectorBottomSheet(List<QueryDocumentSnapshot> crops) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Select Field',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${crops.length} ${crops.length == 1 ? 'field' : 'fields'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderDark, height: 1),
            // Crop list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: crops.length,
                itemBuilder: (context, index) {
                  final crop = crops[index];
                  final data = crop.data() as Map<String, dynamic>;
                  final cropType = data['crop_type'] ?? 'Unknown';
                  final fieldName = data['field_name'] ?? 'Field A';
                  final deviceId = data['device_id'] ?? '';
                  final isSelected = crop.id == _selectedCropId;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCropId = crop.id;
                        _selectedDeviceId = deviceId;
                        _selectedCropType = cropType;
                      });
                      // Broadcast the selection to other screens
                      _selectedCropService.updateSelectedCrop(
                        cropId: crop.id,
                        deviceId: deviceId,
                        cropType: cropType,
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderDark,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Crop icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.agriculture,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Crop info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$cropType - $fieldName',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.developer_board,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      deviceId,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Selected indicator
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Online status based on lastSeen timestamp from RTDB (driven by _rtdbSubscription)
  Widget _buildOnlineStatusBadge() {
    return _buildStatusBadge(_selectedDeviceId != null && _isOnline);
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
    // Use weather location's date if available, otherwise use device local time
    final now = _weatherData?.localTime ?? DateTime.now();
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
        // Notification Button with dynamic badge (uses _unreadCount state, not StreamBuilder)
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
          child: Container(
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
                if (_unreadCount > 0)
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

    // Get next hour forecast
    String? nextHourCondition;
    String? nextHourDescription;
    if (_weatherForecast != null && _weatherForecast!.list.isNotEmpty) {
      final nextHour = _weatherForecast!.list.first;
      if (nextHour.weather.isNotEmpty) {
        nextHourCondition = nextHour.weather.first.main;
        nextHourDescription = nextHour.weather.first.description;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeatherForecastScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getWeatherIconFromDescription(
                              weather.description.isNotEmpty
                                  ? weather.description
                                  : weather.main,
                            ),
                            color: _getWeatherIconColorFromDescription(
                              weather.description.isNotEmpty
                                  ? weather.description
                                  : weather.main,
                            ),
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
                        DateFormat('h:mm a').format(weather.localTime),
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
                            Icons.location_on,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              weather.cityName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.air,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weather.windSpeed.toStringAsFixed(1)} km/h',
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
                // Time of Day Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getTimeOfDayColor(weather.localTime).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getTimeOfDayIcon(weather.localTime),
                    size: 48,
                    color: _getTimeOfDayColor(weather.localTime),
                  ),
                ),
              ],
            ),
            // Next Hour Forecast
            if (nextHourCondition != null && nextHourDescription != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Next hour:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _getWeatherIcon(nextHourCondition),
                          color: _getWeatherIconColor(nextHourCondition),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            nextHourDescription.isNotEmpty
                                ? nextHourDescription[0].toUpperCase() +
                                    nextHourDescription.substring(1)
                                : nextHourCondition,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
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

  /// Get detailed weather icon from description (supports rain intensity)
  IconData _getWeatherIconFromDescription(String condition) {
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
    if (conditionLower.contains('drizzle') || conditionLower.contains('light')) {
      return Icons.water_drop; // single droplet for light rain
    }

    // Clear sky
    if (conditionLower.contains('clear')) {
      return Icons.wb_sunny;
    }

    // Clouds
    if (conditionLower.contains('cloud')) {
      return Icons.cloud;
    }

    // Snow
    if (conditionLower.contains('snow')) {
      return Icons.ac_unit;
    }

    // Mist/Fog/Haze
    if (conditionLower.contains('mist') ||
        conditionLower.contains('fog') ||
        conditionLower.contains('haze')) {
      return Icons.blur_on;
    }

    // Default fallback
    return Icons.wb_cloudy;
  }

  /// Get detailed weather icon color from description
  Color _getWeatherIconColorFromDescription(String condition) {
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

    // Clear sky - amber/yellow
    if (conditionLower.contains('clear')) {
      return Colors.amber;
    }

    // Clouds - grey
    if (conditionLower.contains('cloud')) {
      return Colors.grey;
    }

    // Snow - light blue
    if (conditionLower.contains('snow')) {
      return Colors.lightBlue;
    }

    // Mist/Fog - grey
    if (conditionLower.contains('mist') ||
        conditionLower.contains('fog') ||
        conditionLower.contains('haze')) {
      return Colors.grey.shade400;
    }

    // Default
    return Colors.grey;
  }

  /// Get icon based on time of day
  IconData _getTimeOfDayIcon(DateTime time) {
    final hour = time.hour;

    if (hour >= 5 && hour < 12) {
      // Morning (5 AM - 12 PM)
      return Icons.wb_sunny;
    } else if (hour >= 12 && hour < 17) {
      // Noon/Afternoon (12 PM - 5 PM)
      return Icons.wb_sunny;
    } else if (hour >= 17 && hour < 20) {
      // Evening (5 PM - 8 PM)
      return Icons.wb_twilight;
    } else {
      // Night (8 PM - 5 AM)
      return Icons.nights_stay;
    }
  }

  /// Get color based on time of day
  Color _getTimeOfDayColor(DateTime time) {
    final hour = time.hour;

    if (hour >= 5 && hour < 12) {
      // Morning - Light orange/yellow
      return Colors.orange.shade300;
    } else if (hour >= 12 && hour < 17) {
      // Noon/Afternoon - Bright yellow
      return Colors.amber;
    } else if (hour >= 17 && hour < 20) {
      // Evening - Orange/sunset
      return Colors.deepOrange;
    } else {
      // Night - Blue/purple
      return Colors.indigo.shade300;
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

    return Column(
      children: [
        // Row 1: Soil Moisture & pH Level
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorGraphScreen(
                        deviceId: _selectedDeviceId!,
                        sensorType: 'soil',
                      ),
                    ),
                  );
                },
                child: _buildSensorCard(
                  icon: Icons.water_drop,
                  iconColor: AppColors.soilMoisture,
                  iconBgColor: AppColors.soilMoistureBackground,
                  label: 'SOIL MOISTURE',
                  value: '$_soil',
                  unit: '%',
                  status: _getSoilStatus(_soil),
                  statusColor: _getSoilStatusColor(_soil),
                  progressColor: AppColors.soilMoisture,
                  progressValue: _soil / 100,
                  sensorHealth: _sensorHealth['soil'],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorGraphScreen(
                        deviceId: _selectedDeviceId!,
                        sensorType: 'ph',
                      ),
                    ),
                  );
                },
                child: _buildSensorCard(
                  icon: Icons.science,
                  iconColor: AppColors.phLevel,
                  iconBgColor: AppColors.phLevelBackground,
                  label: 'PH LEVEL',
                  value: _ph.toStringAsFixed(1),
                  unit: '',
                  status: _getPhStatus(_ph),
                  statusColor: _getPhStatusColor(_ph),
                  progressColor: AppColors.phLevel,
                  progressValue: _ph / 14,
                  sensorHealth: _sensorHealth['ph'],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Temperature & Humidity
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorGraphScreen(
                        deviceId: _selectedDeviceId!,
                        sensorType: 'temp',
                      ),
                    ),
                  );
                },
                child: _buildSensorCard(
                  icon: Icons.thermostat,
                  iconColor: AppColors.temperature,
                  iconBgColor: AppColors.temperatureBackground,
                  label: 'TEMPERATURE',
                  value: '$_temp',
                  unit: '°C',
                  status: _getTempStatus(_temp),
                  statusColor: _getTempStatusColor(_temp),
                  progressColor: AppColors.temperature,
                  progressValue: _temp / 50,
                  isWarning: _temp > 30,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorGraphScreen(
                        deviceId: _selectedDeviceId!,
                        sensorType: 'humidity',
                      ),
                    ),
                  );
                },
                child: _buildSensorCard(
                  icon: Icons.cloud,
                  iconColor: AppColors.humidity,
                  iconBgColor: AppColors.humidityBackground,
                  label: 'HUMIDITY',
                  value: '$_humidity',
                  unit: '%',
                  status: _getHumidityStatus(_humidity),
                  statusColor: _getHumidityStatusColor(_humidity),
                  progressColor: AppColors.humidity,
                  progressValue: _humidity / 100,
                ),
              ),
            ),
          ],
        ),
      ],
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

    final waterLevel = _waterLevel;
    final hasError = _sensorHealth['waterLevel'] == 'error';
    final isCritical = waterLevel < 20 && !hasError;

    return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SensorGraphScreen(
                  deviceId: _selectedDeviceId!,
                  sensorType: 'waterLevel',
                ),
              ),
            );
          },
          child: Container(
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
          ),
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
