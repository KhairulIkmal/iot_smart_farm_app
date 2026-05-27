import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

import '../../core/theme.dart';
import '../../core/app_localizations.dart';

/// ------------------------------------------------------------
/// SENSOR GRAPH SCREEN
///
/// PURPOSE:
/// Visualize historical sensor data for the active ESP32 device
/// using Firebase Realtime Database.
///
/// SENSORS COVERED:
/// - Soil moisture (soil)
/// - Temperature (temp)
/// - Humidity (humidity)
/// - pH Level (ph)
/// - Water Level (waterLevel) ✅
///
/// RTDB STRUCTURE:
/// /sensors/{deviceId}/
///   live/
///     soil, temp, humidity, ph, waterLevel, lastSeen
///   history/
///     soil/{timestamp}: value
///     temp/{timestamp}: value
///     humidity/{timestamp}: value
///     ph/{timestamp}: value
///     waterLevel/{timestamp}: value  ← ✅
///   sensorHealth/
///     soil: "ok", ph: "ok", waterLevel: "error"
///
/// WATER LEVEL = FIRST-CLASS SENSOR
/// - Same graph screen
/// - Same logic
/// - Same time-range selector
/// - Same RTDB path
/// ------------------------------------------------------------
class SensorGraphScreen extends StatefulWidget {
  final String deviceId;
  final String sensorType;

  const SensorGraphScreen({
    super.key,
    required this.deviceId,
    required this.sensorType,
  });

  @override
  State<SensorGraphScreen> createState() => _SensorGraphScreenState();
}

class _SensorGraphScreenState extends State<SensorGraphScreen> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // Time range selection
  String _selectedRange = '24h';
  final List<String> _timeRanges = ['24 Hours', '7 Days'];

  // Data
  List<_SensorDataPoint> _historyData = [];
  double? _currentValue;
  bool _isLoading = true;
  String? _error;

  // Touch interaction for tooltip
  double? _touchX;

  // Sensor configuration
  late _SensorConfig _config;

  @override
  void initState() {
    super.initState();
    _config = _getSensorConfig(widget.sensorType);
    _loadData();
  }

  /// Get sensor configuration based on type
  _SensorConfig _getSensorConfig(String sensorType) {
    switch (sensorType) {
      case 'soil':
        return _SensorConfig(
          name: 'Soil Moisture',
          unit: '%',
          color: AppColors.soilMoisture,
          icon: Icons.water_drop,
          minValue: 0,
          maxValue: 100,
          getStatus: (v) {
            if (v < 30) return 'Low';
            if (v > 70) return 'High';
            if (v >= 50 && v <= 70) return 'Good';
            return 'Normal';
          },
          getStatusColor: (v) {
            if (v < 30) return AppColors.error;
            if (v > 70) return AppColors.warning;
            if (v >= 50 && v <= 70) return AppColors.primary;
            return Colors.grey;
          },
        );
      case 'temp':
        return _SensorConfig(
          name: 'Temperature',
          unit: '°C',
          color: AppColors.temperature,
          icon: Icons.thermostat,
          minValue: 0,
          maxValue: 50,
          getStatus: (v) {
            if (v < 15) return 'Cold';
            if (v > 35) return 'Hot';
            if (v >= 20 && v <= 30) return 'Ideal';
            return 'Normal';
          },
          getStatusColor: (v) {
            if (v < 15) return AppColors.info;
            if (v > 35) return AppColors.error;
            if (v >= 20 && v <= 30) return AppColors.primary;
            return Colors.grey;
          },
        );
      case 'humidity':
        return _SensorConfig(
          name: 'Humidity',
          unit: '%',
          color: AppColors.humidity,
          icon: Icons.water,
          minValue: 0,
          maxValue: 100,
          getStatus: (v) {
            if (v < 30) return 'Dry';
            if (v > 80) return 'Humid';
            if (v >= 50 && v <= 70) return 'Ideal';
            return 'Normal';
          },
          getStatusColor: (v) {
            if (v < 30) return AppColors.warning;
            if (v > 80) return AppColors.info;
            if (v >= 50 && v <= 70) return AppColors.primary;
            return Colors.grey;
          },
        );
      case 'ph':
        return _SensorConfig(
          name: 'pH Level',
          unit: 'pH',
          color: AppColors.phLevel,
          icon: Icons.science,
          minValue: 0,
          maxValue: 14,
          getStatus: (v) {
            if (v < 5.5) return 'Acidic';
            if (v > 7.5) return 'Alkaline';
            if (v >= 6.0 && v <= 7.0) return 'Ideal';
            return 'Neutral';
          },
          getStatusColor: (v) {
            if (v < 5.5) return AppColors.error;
            if (v > 7.5) return AppColors.info;
            if (v >= 6.0 && v <= 7.0) return AppColors.primary;
            return Colors.grey;
          },
        );
      case 'waterLevel':
        return _SensorConfig(
          name: 'Water Level',
          unit: '%',
          color: AppColors.info,
          icon: Icons.water_damage,
          minValue: 0,
          maxValue: 100,
          getStatus: (v) {
            if (v < 20) return 'Critical';
            if (v < 40) return 'Low';
            if (v > 80) return 'Full';
            return 'Normal';
          },
          getStatusColor: (v) {
            if (v < 20) return AppColors.error;
            if (v < 40) return AppColors.warning;
            if (v > 80) return AppColors.primary;
            return Colors.grey;
          },
        );
      default:
        return _SensorConfig(
          name: 'Unknown',
          unit: '',
          color: Colors.grey,
          icon: Icons.sensors,
          minValue: 0,
          maxValue: 100,
          getStatus: (_) => 'Unknown',
          getStatusColor: (_) => Colors.grey,
        );
    }
  }

  /// Load sensor data from RTDB
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load current/live value
      final liveSnapshot = await _rtdb
          .ref('sensors/${widget.deviceId}/live/${widget.sensorType}')
          .get();

      if (liveSnapshot.exists) {
        _currentValue = (liveSnapshot.value as num).toDouble();
      }

      // Load history data
      final historyRef = _rtdb.ref(
        'sensors/${widget.deviceId}/history/${widget.sensorType}',
      );

      // Calculate time range
      final now = DateTime.now();
      final startTime = _selectedRange == '24h'
          ? now.subtract(const Duration(hours: 24))
          : now.subtract(const Duration(days: 7));

      final startTimestamp = startTime.millisecondsSinceEpoch ~/ 1000;

      // Query with ordering and filtering
      final historySnapshot = await historyRef
          .orderByKey()
          .startAt(startTimestamp.toString())
          .get();

      final List<_SensorDataPoint> dataPoints = [];

      if (historySnapshot.exists && historySnapshot.value != null) {
        final historyMap = Map<String, dynamic>.from(
          historySnapshot.value as Map,
        );

        historyMap.forEach((timestamp, value) {
          final ts = int.tryParse(timestamp);
          if (ts != null) {
            dataPoints.add(
              _SensorDataPoint(
                timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
                value: (value as num).toDouble(),
              ),
            );
          }
        });

        // Sort by timestamp
        dataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      // If no history data, generate sample data for demo
      if (dataPoints.isEmpty && _currentValue != null) {
        _historyData = _generateSampleData(_currentValue!);
      } else {
        _historyData = dataPoints;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load sensor data';
      });
      debugPrint('Error loading sensor data: $e');
    }
  }

  /// Generate sample data when no history exists (for demo)
  List<_SensorDataPoint> _generateSampleData(double baseValue) {
    final List<_SensorDataPoint> data = [];
    final now = DateTime.now();
    final random = math.Random();

    final pointCount = _selectedRange == '24h' ? 24 : 168; // hourly points
    final interval = _selectedRange == '24h'
        ? const Duration(hours: 1)
        : const Duration(hours: 1);

    for (int i = pointCount; i >= 0; i--) {
      final timestamp = now.subtract(interval * i);

      // Add some variation
      final variation = (random.nextDouble() - 0.5) * 20;
      double value = baseValue + variation;

      // Clamp to valid range
      value = value.clamp(_config.minValue, _config.maxValue);

      data.add(_SensorDataPoint(timestamp: timestamp, value: value));
    }

    return data;
  }

  /// Calculate trend percentage
  double _calculateTrend() {
    if (_historyData.length < 2) return 0;

    final recentData = _historyData.length > 4
        ? _historyData.sublist(_historyData.length - 4)
        : _historyData;

    if (recentData.length < 2) return 0;

    final oldValue = recentData.first.value;
    final newValue = recentData.last.value;

    if (oldValue == 0) return 0;

    return ((newValue - oldValue) / oldValue) * 100;
  }

  /// Get analysis insight based on trend
  _AnalysisInsight _getAnalysisInsight() {
    final trend = _calculateTrend();
    final current = _currentValue ?? 0;

    switch (widget.sensorType) {
      case 'soil':
        if (trend < -5) {
          return _AnalysisInsight(
            title: 'Moisture dropping fast',
            message:
                'Levels decreased by ${trend.abs().toStringAsFixed(0)}% in the last 4 hours. Irrigation recommended soon to maintain optimal levels.',
            icon: Icons.trending_down,
            color: AppColors.warning,
          );
        } else if (current < 30) {
          return _AnalysisInsight(
            title: 'Low moisture detected',
            message:
                'Current soil moisture is below optimal. Consider starting irrigation to prevent crop stress.',
            icon: Icons.warning_amber,
            color: AppColors.error,
          );
        }
        return _AnalysisInsight(
          title: 'Moisture levels stable',
          message:
              'Soil moisture is within optimal range. Continue monitoring for best results.',
          icon: Icons.check_circle,
          color: AppColors.primary,
        );

      case 'temp':
        if (current > 35) {
          return _AnalysisInsight(
            title: 'High temperature alert',
            message:
                'Temperature is above optimal. Consider shade protection or increased ventilation.',
            icon: Icons.thermostat,
            color: AppColors.error,
          );
        } else if (current < 15) {
          return _AnalysisInsight(
            title: 'Low temperature warning',
            message:
                'Temperature is below optimal for most crops. Consider protection measures.',
            icon: Icons.ac_unit,
            color: AppColors.info,
          );
        }
        return _AnalysisInsight(
          title: 'Temperature optimal',
          message: 'Current temperature is within ideal range for crop growth.',
          icon: Icons.check_circle,
          color: AppColors.primary,
        );

      case 'humidity':
        if (current > 80) {
          return _AnalysisInsight(
            title: 'High humidity detected',
            message:
                'Humidity levels are high. Monitor for fungal diseases and ensure proper ventilation.',
            icon: Icons.water,
            color: AppColors.info,
          );
        } else if (current < 30) {
          return _AnalysisInsight(
            title: 'Low humidity alert',
            message:
                'Air is dry. Consider misting or increasing irrigation frequency.',
            icon: Icons.warning_amber,
            color: AppColors.warning,
          );
        }
        return _AnalysisInsight(
          title: 'Humidity levels normal',
          message: 'Air humidity is within acceptable range for plant health.',
          icon: Icons.check_circle,
          color: AppColors.primary,
        );

      case 'ph':
        if (current < 5.5) {
          return _AnalysisInsight(
            title: 'Soil too acidic',
            message:
                'pH is below optimal. Consider adding lime to raise pH levels.',
            icon: Icons.science,
            color: AppColors.error,
          );
        } else if (current > 7.5) {
          return _AnalysisInsight(
            title: 'Soil too alkaline',
            message:
                'pH is above optimal. Consider adding sulfur or organic matter.',
            icon: Icons.science,
            color: AppColors.info,
          );
        }
        return _AnalysisInsight(
          title: 'pH level optimal',
          message: 'Soil pH is within ideal range for nutrient absorption.',
          icon: Icons.check_circle,
          color: AppColors.primary,
        );

      case 'waterLevel':
        if (trend < -10) {
          return _AnalysisInsight(
            title: 'Rapid water depletion',
            message:
                'Tank level dropped by ${trend.abs().toStringAsFixed(0)}%. Check for leaks or increased consumption.',
            icon: Icons.trending_down,
            color: AppColors.warning,
          );
        } else if (current < 20) {
          return _AnalysisInsight(
            title: 'Critical water level',
            message:
                'Tank is nearly empty. Refill immediately to prevent irrigation interruption.',
            icon: Icons.warning_amber,
            color: AppColors.error,
          );
        } else if (current < 40) {
          return _AnalysisInsight(
            title: 'Low water level',
            message:
                'Tank level is low. Schedule refill soon to ensure continuous operation.',
            icon: Icons.water_damage,
            color: AppColors.warning,
          );
        }
        return _AnalysisInsight(
          title: 'Water supply adequate',
          message: 'Tank level is sufficient for normal irrigation operations.',
          icon: Icons.check_circle,
          color: AppColors.primary,
        );

      default:
        return _AnalysisInsight(
          title: 'Data available',
          message: 'Sensor readings are being monitored.',
          icon: Icons.info,
          color: AppColors.info,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: ThemeColors.icon(context),
                size: 24,
              ),
            ),
          ),
        ),
        title: Text(
          l10n.t('Sensor Analytics'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: ThemeColors.icon(context)),
            onPressed: () {
              // Settings action
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Range Selector
                    _buildTimeRangeSelector(),
                    const SizedBox(height: 20),

                    // Current Values Cards
                    _buildCurrentValuesRow(),
                    const SizedBox(height: 24),

                    // Trend Analysis Section
                    _buildTrendAnalysis(),
                    const SizedBox(height: 24),

                    // Analysis Insight Card
                    _buildAnalysisInsight(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  /// ------------------------------------------------
  /// TIME RANGE SELECTOR
  /// ------------------------------------------------
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _timeRanges.map((range) {
          final isSelected =
              (_selectedRange == '24h' && range == '24 Hours') ||
              (_selectedRange == '7d' && range == '7 Days');

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRange = range == '24 Hours' ? '24h' : '7d';
                });
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  AppLocalizations.of(context).t(range),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? ThemeColors.textPrimary(context)
                        : ThemeColors.textSecondary(context).withOpacity(0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ------------------------------------------------
  /// CURRENT VALUES ROW
  /// ------------------------------------------------
  Widget _buildCurrentValuesRow() {
    final status = _config.getStatus(_currentValue ?? 0);
    final statusColor = _config.getStatusColor(_currentValue ?? 0);

    // Get secondary sensor for display
    final secondarySensor = _getSecondarySensor();

    return Row(
      children: [
        // Primary Sensor Card (with color)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _config.color.withOpacity(0.3),
                  _config.color.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _config.color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currentValue?.toStringAsFixed(widget.sensorType == 'ph' ? 1 : 0) ?? '--'}${_config.unit == 'pH' ? '' : _config.unit}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    Icon(
                      _config.icon,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _config.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(fontSize: 13, color: statusColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Secondary Sensor Card (neutral)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  secondarySensor.value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  secondarySensor.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ThemeColors.textSecondary(context).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${secondarySensor.status}',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _SecondarySensorInfo _getSecondarySensor() {
    // Return a complementary sensor based on current type
    switch (widget.sensorType) {
      case 'soil':
        return _SecondarySensorInfo(
          name: 'pH Level',
          value: '6.5',
          status: 'Ideal',
        );
      case 'temp':
        return _SecondarySensorInfo(
          name: 'Humidity',
          value: '65%',
          status: 'Normal',
        );
      case 'humidity':
        return _SecondarySensorInfo(
          name: 'Temperature',
          value: '28°C',
          status: 'Normal',
        );
      case 'ph':
        return _SecondarySensorInfo(
          name: 'Soil Moisture',
          value: '45%',
          status: 'Good',
        );
      case 'waterLevel':
        return _SecondarySensorInfo(
          name: 'Daily Usage',
          value: '120L',
          status: 'Normal',
        );
      default:
        return _SecondarySensorInfo(
          name: 'N/A',
          value: '--',
          status: 'Unknown',
        );
    }
  }

  /// ------------------------------------------------
  /// TREND ANALYSIS WITH CHART
  /// ------------------------------------------------
  Widget _buildTrendAnalysis() {
    final trend = _calculateTrend();
    final isPositive = trend >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).t('TREND ANALYSIS'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_config.name} Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.primary : AppColors.error)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? AppColors.primary : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${trend.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? AppColors.primary : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Line Chart
          SizedBox(height: 200, child: _buildLineChart()),

          // X-Axis Labels
          const SizedBox(height: 8),
          _buildXAxisLabels(),
        ],
      ),
    );
  }

  /// Custom Line Chart Widget
  Widget _buildLineChart() {
    if (_historyData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
        ),
      );
    }

    return GestureDetector(
      onPanStart: (details) {
        setState(() => _touchX = details.localPosition.dx);
      },
      onPanUpdate: (details) {
        setState(() => _touchX = details.localPosition.dx);
      },
      onPanEnd: (_) {
        setState(() => _touchX = null);
      },
      onTapDown: (details) {
        setState(() => _touchX = details.localPosition.dx);
      },
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _touchX = null);
        });
      },
      child: CustomPaint(
        size: const Size(double.infinity, 200),
        painter: _LineChartPainter(
          data: _historyData,
          color: _config.color,
          surfaceColor: ThemeColors.surface(context),
          indicatorColor: ThemeColors.textSecondary(context),
          minValue: _config.minValue,
          maxValue: _config.maxValue,
          touchX: _touchX,
          unit: _config.unit,
          sensorType: widget.sensorType,
        ),
      ),
    );
  }

  Widget _buildXAxisLabels() {
    final labels = _selectedRange == '24h'
        ? ['12 AM', '6 AM', '12 PM', '6 PM']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
              ),
            ),
          )
          .toList(),
    );
  }

  /// ------------------------------------------------
  /// ANALYSIS INSIGHT CARD
  /// ------------------------------------------------
  Widget _buildAnalysisInsight() {
    final insight = _getAnalysisInsight();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(insight.icon, color: insight.color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'ANALYSIS INSIGHT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.message,
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// ERROR STATE
  /// ------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: ThemeColors.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: TextStyle(
              fontSize: 16,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(AppLocalizations.of(context).t('Retry')),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------
/// CUSTOM LINE CHART PAINTER
/// ------------------------------------------------
class _LineChartPainter extends CustomPainter {
  final List<_SensorDataPoint> data;
  final Color color;
  final Color surfaceColor;
  final Color indicatorColor;
  final double minValue;
  final double maxValue;
  final double? touchX;
  final String unit;
  final String sensorType;

  _LineChartPainter({
    required this.data,
    required this.color,
    required this.surfaceColor,
    required this.indicatorColor,
    required this.minValue,
    required this.maxValue,
    required this.unit,
    required this.sensorType,
    this.touchX,
  });

  String _formatLabel(double value) {
    if (sensorType == 'ph') return '${value.toStringAsFixed(1)} pH';
    if (sensorType == 'temp') return '${value.toStringAsFixed(0)}°C';
    return '${value.toStringAsFixed(0)}%';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final range = maxValue - minValue;
    final xStep = size.width / (data.length - 1);

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final normalizedValue = (data[i].value - minValue) / range;
      final y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y.clamp(0, size.height)));
    }

    // Create smooth curve path
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      fillPath.moveTo(points[0].dx, size.height);
      fillPath.lineTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw highlighted point (latest) — only when not touching
    if (points.isNotEmpty && touchX == null) {
      _drawDot(canvas, points.last, color);
      _drawTooltip(canvas, size, points.last, data.last.value, color);
    }

    // Draw interactive tooltip on touch
    if (touchX != null && points.isNotEmpty) {
      // Find nearest data point index
      final clampedX = touchX!.clamp(0.0, size.width);
      final approxIndex = (clampedX / xStep).round().clamp(0, points.length - 1);
      final touchedPoint = points[approxIndex];
      final touchedValue = data[approxIndex].value;

      // Vertical indicator line
      final linePaint = Paint()
        ..color = indicatorColor.withOpacity(0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(touchedPoint.dx, 0),
        Offset(touchedPoint.dx, size.height),
        linePaint,
      );

      _drawDot(canvas, touchedPoint, color);
      _drawTooltip(canvas, size, touchedPoint, touchedValue, color);
    }
  }

  void _drawDot(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 8, Paint()..color = color.withOpacity(0.3));
    canvas.drawCircle(point, 5, Paint()..color = color);
    canvas.drawCircle(point, 2, Paint()..color = surfaceColor);
  }

  void _drawTooltip(Canvas canvas, Size size, Offset point, double value, Color color) {
    final label = _formatLabel(value);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const hPad = 8.0;
    const vPad = 5.0;
    final tooltipW = textPainter.width + hPad * 2;
    final tooltipH = textPainter.height + vPad * 2;

    // Keep tooltip within horizontal bounds
    double tooltipLeft = point.dx - tooltipW / 2;
    tooltipLeft = tooltipLeft.clamp(0.0, size.width - tooltipW);

    // Place above the dot; flip below if too close to top
    double tooltipTop = point.dy - tooltipH - 12;
    if (tooltipTop < 0) tooltipTop = point.dy + 12;

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipLeft, tooltipTop, tooltipW, tooltipH),
      const Radius.circular(6),
    );
    canvas.drawRRect(labelRect, Paint()..color = color);

    textPainter.paint(canvas, Offset(tooltipLeft + hPad, tooltipTop + vPad));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.touchX != touchX || old.data != data;
}

/// ------------------------------------------------
/// DATA MODELS
/// ------------------------------------------------
class _SensorDataPoint {
  final DateTime timestamp;
  final double value;

  _SensorDataPoint({required this.timestamp, required this.value});
}

class _SensorConfig {
  final String name;
  final String unit;
  final Color color;
  final IconData icon;
  final double minValue;
  final double maxValue;
  final String Function(double) getStatus;
  final Color Function(double) getStatusColor;

  _SensorConfig({
    required this.name,
    required this.unit,
    required this.color,
    required this.icon,
    required this.minValue,
    required this.maxValue,
    required this.getStatus,
    required this.getStatusColor,
  });
}

class _SecondarySensorInfo {
  final String name;
  final String value;
  final String status;

  _SecondarySensorInfo({
    required this.name,
    required this.value,
    required this.status,
  });
}

class _AnalysisInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  _AnalysisInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}
