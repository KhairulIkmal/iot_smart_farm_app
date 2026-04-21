import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../core/theme.dart';
import '../../services/live_sensor_service.dart';
import '../../services/selected_crop_service.dart';
import '../analytics/sensor_graph_screen.dart';

/// ------------------------------------------------------------
/// SENSORS SCREEN
///
/// Firebase RTDB Structure:
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
/// - Real-time sensor data with live updates
/// - Historical graphs (last 6 hours)
/// - Sensor health status
/// - Water tank with usage trend
/// - Soil pH with scale
/// ------------------------------------------------------------
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SelectedCropService _selectedCropService = SelectedCropService();

  String? _selectedDeviceId;
  String? _selectedCropId;
  bool _isRefreshing = false;
  DateTime _lastUpdated = DateTime.now();

  // Live sensor values (updated by single stream subscription)
  int _soil = 0;
  double _ph = 0.0;
  int _temp = 0;
  int _humidity = 0;
  int _waterLevel = 0;
  String _soilHealth = 'ok';
  String _phHealth = 'ok';
  String _waterHealth = 'ok';

  // Historical data for charts (simulated time-series)
  List<double> _soilHistory = [];
  List<double> _tempHistory = [];
  List<double> _humidityHistory = [];
  List<double> _waterHistory = [];

  StreamSubscription<LiveSensorData>? _sensorSubscription;
  StreamSubscription<SelectedCropData?>? _cropSelectionSubscription;
  StreamSubscription<DocumentSnapshot>? _cropNameSubscription;

  // Header display name — subscription-based, not rebuilt on every RTDB event
  String _cropDisplayName = '';

  @override
  void initState() {
    super.initState();
    // Listen to crop selection changes from dashboard
    _cropSelectionSubscription = _selectedCropService.selectedCropStream.listen((cropData) {
      if (cropData != null) {
        setState(() {
          _selectedCropId = cropData.cropId;
          _selectedDeviceId = cropData.deviceId;
        });
        _loadHistoricalData();
        _subscribeToCropName(cropData.cropId);
      } else {
        setState(() {
          _selectedCropId = null;
          _selectedDeviceId = null;
          _cropDisplayName = '';
        });
        _cropNameSubscription?.cancel();
      }
    });

    // Load initial selection if available
    final currentSelection = _selectedCropService.selectedCrop;
    if (currentSelection != null) {
      setState(() {
        _selectedCropId = currentSelection.cropId;
        _selectedDeviceId = currentSelection.deviceId;
      });
      _loadHistoricalData();
      _subscribeToCropName(currentSelection.cropId);
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _cropSelectionSubscription?.cancel();
    _cropNameSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToCropName(String cropId) {
    _cropNameSubscription?.cancel();
    _cropNameSubscription = _firestore
        .collection('crops')
        .doc(cropId)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _cropDisplayName =
            '${data['crop_type'] ?? 'Unknown'} - ${data['field_name'] ?? 'Field A'}';
      });
    });
  }

  /// Load historical data from RTDB
  /// In production, you would have a time-series structure like:
  /// sensors/{deviceId}/history/{timestamp}
  /// For now, we generate sample history based on current values
  void _loadHistoricalData() {
    if (_selectedDeviceId == null) return;

    LiveSensorService().setDevice(_selectedDeviceId);

    _sensorSubscription?.cancel();

    // Seed from cache immediately — no blank screen while waiting for first event
    final cached = LiveSensorService().currentData;
    if (cached != null) _applySensorData(cached);

    _sensorSubscription = LiveSensorService().stream.listen((data) {
      if (!mounted) return;
      _applySensorData(data);
    });
  }

  void _applySensorData(LiveSensorData data) {
    final soil = data.soil.toDouble();
    final temp = data.temp.toDouble();
    final humidity = data.humidity.toDouble();
    final water = data.waterLevel.toDouble();
    setState(() {
      _soil = data.soil;
      _ph = data.ph;
      _temp = data.temp;
      _humidity = data.humidity;
      _waterLevel = data.waterLevel;
      _soilHealth = data.soilHealth;
      _phHealth = data.phHealth;
      _waterHealth = data.waterHealth;
      _soilHistory = _generateHistory(soil, 7);
      _tempHistory = _generateHistory(temp, 7);
      _humidityHistory = _generateHistory(humidity, 7);
      _waterHistory = _generateWaterHistory(water, 7);
      _lastUpdated = DateTime.now();
    });
  }

  List<double> _generateHistory(double currentValue, int points) {
    final history = <double>[];
    for (int i = 0; i < points; i++) {
      final variation = (i - points / 2) * 2; // Create some variation
      history.add((currentValue + variation).clamp(0, 100));
    }
    return history;
  }

  List<double> _generateWaterHistory(double currentValue, int points) {
    // Water level decreases over time (usage)
    final history = <double>[];
    for (int i = 0; i < points; i++) {
      final decrease = (points - i - 1) * 3; // Gradual decrease
      history.add((currentValue + decrease).clamp(0, 100));
    }
    return history;
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    _loadHistoricalData();
    setState(() => _isRefreshing = false);
  }

  String _getTimeAgo() {
    final diff = DateTime.now().difference(_lastUpdated);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),

                // Sensor Cards
                if (_selectedDeviceId != null) ...[
                  _buildSoilMoistureCard(),
                  const SizedBox(height: 16),
                  _buildAirConditionsCard(),
                  const SizedBox(height: 16),
                  _buildWaterTankCard(),
                  const SizedBox(height: 16),
                  _buildSoilPhCard(),
                  const SizedBox(height: 24),
                ] else
                  _buildNoDeviceCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// HEADER
  /// ------------------------------------------------
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensors',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time monitoring',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            // Refresh Button
            GestureDetector(
              onTap: _isRefreshing ? null : _refreshData,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: _isRefreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColors.primary, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedDeviceId != null && _cropDisplayName.isNotEmpty) ...[
          Text(
            'MONITORING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _cropDisplayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  /// ------------------------------------------------
  /// SOIL MOISTURE CARD WITH GRAPH
  /// RTDB: sensors/{deviceId}/soil
  /// RTDB: sensors/{deviceId}/sensorHealth/soil
  /// ------------------------------------------------
  Widget _buildSoilMoistureCard() {
    final soilMoisture = _soil;
    final hasError = _soilHealth == 'error';
    final status = _getSoilStatus(soilMoisture);
    final statusColor = _getSoilStatusColor(soilMoisture);

    return GestureDetector(
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
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasError
                    ? AppColors.error.withOpacity(0.5)
                    : AppColors.borderDark,
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasError
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: hasError ? AppColors.error : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Soil Moisture',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Sensor ID: ${_selectedDeviceId ?? "N/A"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasError ? '--%' : '$soilMoisture%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: hasError ? AppColors.error : Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (hasError ? AppColors.error : statusColor)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasError ? 'Error' : status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasError ? AppColors.error : statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Last 6 Hours Label
              Text(
                'Last 6 Hours',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),

              // Bar Chart
              _buildBarChart(_soilHistory, AppColors.soilMoisture),
              const SizedBox(height: 12),

              // Time labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '6h ago',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  Text(
                    'Now',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeAgo(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  /// ------------------------------------------------
  /// AIR CONDITIONS CARD
  /// RTDB: sensors/{deviceId}/temp
  /// RTDB: sensors/{deviceId}/humidity
  /// ------------------------------------------------
  Widget _buildAirConditionsCard() {
    final temp = _temp;
    final humidity = _humidity;
    final tempStatus = _getTempStatus(temp);
    final tempStatusColor = _getTempStatusColor(temp);

    return GestureDetector(
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
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.temperature.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.thermostat,
                      color: AppColors.temperature,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Air Conditions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Greenhouse 1',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$temp°C',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tempStatusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tempStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tempStatusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sub-values
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temperature',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$temp°C',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Humidity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$humidity%',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeAgo(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  /// ------------------------------------------------
  /// WATER TANK CARD WITH USAGE TREND
  /// RTDB: sensors/{deviceId}/waterLevel
  /// RTDB: sensors/{deviceId}/sensorHealth/waterLevel
  /// ------------------------------------------------
  Widget _buildWaterTankCard() {
    final waterLevel = _waterLevel;
    final hasError = _waterHealth == 'error';
    final isLow = waterLevel < 30 && !hasError;

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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasError || isLow
                    ? AppColors.error.withOpacity(0.5)
                    : AppColors.borderDark,
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasError || isLow
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.soilMoisture.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasError ? Icons.error_outline : Icons.water,
                      color: hasError || isLow
                          ? AppColors.error
                          : AppColors.soilMoisture,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Main Tank',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Capacity: 5000L',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasError ? '--%' : '$waterLevel%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: hasError || isLow
                              ? AppColors.error
                              : Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hasError || isLow
                                      ? AppColors.error
                                      : AppColors.primary)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasError
                              ? 'Sensor Error'
                              : isLow
                              ? 'Low Level'
                              : 'Normal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasError || isLow
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Usage Trend
              Text(
                'Usage Trend',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),

              // Usage Trend Bars (color changes as level drops)
              _buildUsageTrendBars(_waterHistory),
              const SizedBox(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLow ? 'Requires Refill' : 'Level OK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLow ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  /// ------------------------------------------------
  /// SOIL PH CARD WITH SCALE
  /// RTDB: sensors/{deviceId}/ph
  /// RTDB: sensors/{deviceId}/sensorHealth/ph
  /// ------------------------------------------------
  Widget _buildSoilPhCard() {
    final ph = _ph;
    final hasError = _phHealth == 'error';
    final status = _getPhStatus(ph);
    final statusColor = _getPhStatusColor(ph);

    return GestureDetector(
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
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasError
                    ? AppColors.error.withOpacity(0.5)
                    : AppColors.borderDark,
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasError
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.phLevel.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.science,
                      color: hasError ? AppColors.error : AppColors.phLevel,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Soil pH',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Zone A',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasError ? '--' : ph.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: hasError ? AppColors.error : Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (hasError ? AppColors.error : statusColor)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasError ? 'Error' : status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasError ? AppColors.error : statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // pH Scale
              _buildPhScale(ph),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Acidic',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  Text(
                    'Alkaline',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeAgo(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'Analyze',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  /// ------------------------------------------------
  /// HELPER WIDGETS
  /// ------------------------------------------------

  /// Bar chart for historical data with level indicator
  Widget _buildBarChart(List<double> data, Color color) {
    if (data.isEmpty) {
      data = List.generate(7, (i) => 50.0);
    }

    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          final isLast = index == data.length - 1;

          return Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background bar (full height, faded)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Value bar (actual level)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: (value / 100) * 50,
                  decoration: BoxDecoration(
                    color: isLast
                        ? color
                        : color.withOpacity(0.5 + (index * 0.05)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Usage trend bars with level indicator
  Widget _buildUsageTrendBars(List<double> data) {
    if (data.isEmpty) {
      data = List.generate(7, (i) => 70.0 - (i * 5));
    }

    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          final isLast = index == data.length - 1;

          // Color based on water level
          Color barColor;
          if (value > 50) {
            barColor = AppColors.soilMoisture;
          } else if (value > 30) {
            barColor = AppColors.warning;
          } else {
            barColor = AppColors.error;
          }

          return Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background bar (full height, faded)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Value bar (actual level with color based on value)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: (value / 100) * 50,
                  decoration: BoxDecoration(
                    color: isLast
                        ? barColor
                        : barColor.withOpacity(0.6 + (index * 0.04)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// pH Scale with indicator
  Widget _buildPhScale(double ph) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final indicatorPosition = (ph / 14) * width;

        return Stack(
          children: [
            // Gradient Scale
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE53935), // Red (acidic)
                    Color(0xFFFF9800), // Orange
                    Color(0xFFFFEB3B), // Yellow
                    Color(0xFF4CAF50), // Green (neutral)
                    Color(0xFF00BCD4), // Cyan
                    Color(0xFF2196F3), // Blue
                    Color(0xFF9C27B0), // Purple (alkaline)
                  ],
                ),
              ),
            ),
            // Indicator
            Positioned(
              left: indicatorPosition.clamp(0, width - 4),
              top: 0,
              child: Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.backgroundDark, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
            'No Device Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Claim a device to view sensor data',
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
  /// STATUS HELPERS
  /// ------------------------------------------------
  String _getSoilStatus(int value) {
    if (value < 30) return 'Low';
    if (value > 80) return 'High';
    if (value >= 50 && value <= 70) return 'Optimal';
    return 'Normal';
  }

  Color _getSoilStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 80) return AppColors.warning;
    if (value >= 50 && value <= 70) return AppColors.primary;
    return AppColors.primary;
  }

  String _getTempStatus(int value) {
    if (value < 15) return 'Cold';
    if (value > 35) return 'Hot';
    if (value > 28) return 'Warm';
    return 'Normal';
  }

  Color _getTempStatusColor(int value) {
    if (value < 15) return AppColors.info;
    if (value > 35) return AppColors.error;
    if (value > 28) return AppColors.warning;
    return AppColors.primary;
  }

  String _getPhStatus(double value) {
    if (value < 5.5) return 'Acidic';
    if (value > 7.5) return 'Alkaline';
    return 'Neutral';
  }

  Color _getPhStatusColor(double value) {
    if (value < 5.5) return AppColors.warning;
    if (value > 7.5) return AppColors.info;
    return AppColors.primary;
  }
}
