import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../services/live_sensor_service.dart';
import '../../services/selected_crop_service.dart';
import '../analytics/sensor_graph_screen.dart';

/// ------------------------------------------------------------
/// SENSORS SCREEN
/// ------------------------------------------------------------
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SelectedCropService _selectedCropService = SelectedCropService();

  String? _selectedDeviceId;
  String? _selectedCropId;
  bool _isRefreshing = false;
  bool _isConnected = false;
  DateTime _lastUpdated = DateTime.now();

  // Live sensor values
  int _soil = 0;
  double _ph = 0.0;
  int _temp = 0;
  int _humidity = 0;
  int _waterLevel = 0;
  String _soilHealth = 'ok';
  String _phHealth = 'ok';
  String _waterHealth = 'ok';

  // Trend history
  List<double> _soilHistory = [];
  List<double> _tempHistory = [];
  List<double> _humidityHistory = [];
  List<double> _waterHistory = [];

  StreamSubscription<LiveSensorData>? _sensorSubscription;
  StreamSubscription<SelectedCropData?>? _cropSelectionSubscription;
  StreamSubscription<DocumentSnapshot>? _cropNameSubscription;

  String _cropDisplayName = '';

  // Live dot pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _cropSelectionSubscription =
        _selectedCropService.selectedCropStream.listen((cropData) {
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
          _isConnected = false;
        });
        _cropNameSubscription?.cancel();
      }
    });

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
    _pulseCtrl.dispose();
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
            '${data['crop_type'] ?? 'Unknown'} — ${data['field_name'] ?? 'Field A'}';
      });
    });
  }

  void _loadHistoricalData() {
    if (_selectedDeviceId == null) return;
    LiveSensorService().setDevice(_selectedDeviceId);
    _sensorSubscription?.cancel();
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
      _isConnected = true;
    });
  }

  List<double> _generateHistory(double currentValue, int points) {
    final history = <double>[];
    for (int i = 0; i < points; i++) {
      final variation = (i - points / 2) * 2;
      history.add((currentValue + variation).clamp(0, 100));
    }
    return history;
  }

  List<double> _generateWaterHistory(double currentValue, int points) {
    final history = <double>[];
    for (int i = 0; i < points; i++) {
      final decrease = (points - i - 1) * 3;
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

  String _getTimeAgo(AppLocalizations l10n) {
    final diff = DateTime.now().difference(_lastUpdated);
    if (diff.inSeconds < 60) return l10n.t('Updated just now');
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          backgroundColor: ThemeColors.surface(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 24),
                if (_selectedDeviceId != null) ...[
                  // Order: soil sensors first, then air, then water tank
                  _buildSoilMoistureCard(l10n),
                  const SizedBox(height: 16),
                  _buildSoilPhCard(l10n),
                  const SizedBox(height: 16),
                  _buildAirConditionsCard(l10n),
                  const SizedBox(height: 16),
                  _buildWaterTankCard(l10n),
                  const SizedBox(height: 24),
                ] else
                  _buildNoDeviceCard(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('Sensors'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Live indicator dot
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _isConnected ? _pulseAnim.value : 0.35,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected
                                ? AppColors.primary
                                : ThemeColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected
                          ? l10n.t('Live · Real-time monitoring')
                          : l10n.t('Real-time monitoring'),
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Refresh button
            GestureDetector(
              onTap: _isRefreshing ? null : _refreshData,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeColors.border(context)),
                ),
                child: _isRefreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColors.primary, size: 22),
              ),
            ),
          ],
        ),
        if (_selectedDeviceId != null && _cropDisplayName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco_rounded,
                        color: AppColors.primary, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      _cropDisplayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getTimeAgo(l10n),
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textSecondary(context).withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SOIL MOISTURE CARD
  // ─────────────────────────────────────────────
  Widget _buildSoilMoistureCard(AppLocalizations l10n) {
    final soilMoisture = _soil;
    final hasError = _soilHealth == 'error';
    final status = _getSoilStatus(soilMoisture, l10n);
    final statusColor = _getSoilStatusColor(soilMoisture);
    final subtitle = _cropDisplayName.isNotEmpty ? _cropDisplayName : 'Soil Sensor';

    return _SensorCard(
      onTap: () => _openGraph('soil'),
      hasError: hasError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.water_drop_rounded,
            iconColor: hasError ? AppColors.error : AppColors.soilMoisture,
            title: l10n.t('Soil Moisture'),
            subtitle: subtitle,
            value: hasError ? '--%' : '$soilMoisture%',
            valueColor: hasError
                ? AppColors.error
                : ThemeColors.textPrimary(context),
            status: hasError ? 'Error' : status,
            statusColor: hasError ? AppColors.error : statusColor,
          ),
          const SizedBox(height: 20),
          _trendLabel(l10n),
          const SizedBox(height: 10),
          _buildBarChart(_soilHistory, AppColors.soilMoisture),
          const SizedBox(height: 16),
          _cardFooter(l10n, actionLabel: l10n.t('Details')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SOIL PH CARD
  // ─────────────────────────────────────────────
  Widget _buildSoilPhCard(AppLocalizations l10n) {
    final ph = _ph;
    final hasError = _phHealth == 'error';
    final status = _getPhStatus(ph, l10n);
    final statusColor = _getPhStatusColor(ph);
    final subtitle = _cropDisplayName.isNotEmpty ? _cropDisplayName : 'Soil Sensor';

    return _SensorCard(
      onTap: () => _openGraph('ph'),
      hasError: hasError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.science_rounded,
            iconColor: hasError ? AppColors.error : AppColors.phLevel,
            title: l10n.t('Soil pH'),
            subtitle: subtitle,
            value: hasError ? '--' : ph.toStringAsFixed(1),
            valueColor: hasError
                ? AppColors.error
                : ThemeColors.textPrimary(context),
            status: hasError ? 'Error' : status,
            statusColor: hasError ? AppColors.error : statusColor,
          ),
          const SizedBox(height: 20),
          _buildPhScale(ph),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('Acidic'),
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
              ),
              Text(
                'Neutral',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
              ),
              Text(
                l10n.t('Alkaline'),
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _cardFooter(l10n, actionLabel: l10n.t('Analyze')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AIR CONDITIONS CARD
  // ─────────────────────────────────────────────
  Widget _buildAirConditionsCard(AppLocalizations l10n) {
    final temp = _temp;
    final humidity = _humidity;
    final tempStatus = _getTempStatus(temp, l10n);
    final tempStatusColor = _getTempStatusColor(temp);
    final humidityStatus = _getHumidityStatus(humidity, l10n);
    final humidityStatusColor = _getHumidityStatusColor(humidity);
    final subtitle = _cropDisplayName.isNotEmpty ? _cropDisplayName : 'Ambient Sensor';

    return _SensorCard(
      onTap: () => _openGraph('temp'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title row — no big value, tiles are the primary display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.temperature.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.device_thermostat_rounded,
                  color: AppColors.temperature,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('Air Conditions'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 16),

          // Temperature + Humidity tiles — each shows value AND status badge
          Row(
            children: [
              Expanded(
                child: _buildAirTile(
                  icon: Icons.thermostat_rounded,
                  iconColor: AppColors.temperature,
                  label: l10n.t('Temperature'),
                  value: '$temp°C',
                  status: tempStatus,
                  statusColor: tempStatusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAirTile(
                  icon: Icons.water_rounded,
                  iconColor: AppColors.humidity,
                  label: l10n.t('Humidity'),
                  value: '$humidity%',
                  status: humidityStatus,
                  statusColor: humidityStatusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _trendLabel(l10n),
          const SizedBox(height: 10),
          _buildBarChart(_tempHistory, AppColors.temperature),
          const SizedBox(height: 16),
          _cardFooter(l10n, actionLabel: l10n.t('History')),
        ],
      ),
    );
  }

  Widget _buildAirTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColors.bg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textSecondary(context).withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WATER TANK CARD
  // ─────────────────────────────────────────────
  Widget _buildWaterTankCard(AppLocalizations l10n) {
    final waterLevel = _waterLevel;
    final hasError = _waterHealth == 'error';
    final isLow = waterLevel < 30 && !hasError;

    return _SensorCard(
      onTap: () => _openGraph('waterLevel'),
      hasError: hasError || isLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: hasError ? Icons.error_outline_rounded : Icons.water_rounded,
            iconColor: hasError || isLow ? AppColors.error : AppColors.soilMoisture,
            title: l10n.t('Main Tank'),
            subtitle: 'Irrigation System',
            value: hasError ? '--%' : '$waterLevel%',
            valueColor: hasError || isLow
                ? AppColors.error
                : ThemeColors.textPrimary(context),
            status: hasError
                ? l10n.t('Sensor Error')
                : isLow
                    ? l10n.t('Low Level')
                    : l10n.t('Normal'),
            statusColor:
                hasError || isLow ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.t('Usage Trend'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildUsageTrendBars(_waterHistory),
          const SizedBox(height: 16),
          _cardFooter(
            l10n,
            actionLabel: l10n.t('History'),
            leadingText: isLow ? l10n.t('Requires Refill') : l10n.t('Level OK'),
            leadingColor: isLow ? AppColors.error : AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED CARD COMPONENTS
  // ─────────────────────────────────────────────

  /// Standard card header: icon + title/subtitle + big value + status badge
  Widget _cardHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeColors.textSecondary(context).withOpacity(0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// "Trend" label — replaces the old misleading "Last 6 Hours"
  Widget _trendLabel(AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          Icons.show_chart_rounded,
          size: 13,
          color: ThemeColors.textSecondary(context).withOpacity(0.4),
        ),
        const SizedBox(width: 5),
        Text(
          'Trend',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textSecondary(context).withOpacity(0.5),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Card footer row: timestamp left, action link right
  Widget _cardFooter(
    AppLocalizations l10n, {
    required String actionLabel,
    String? leadingText,
    Color? leadingColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          leadingText ?? _getTimeAgo(l10n),
          style: TextStyle(
            fontSize: 13,
            fontWeight: leadingText != null ? FontWeight.w600 : FontWeight.normal,
            color: leadingColor ??
                ThemeColors.textSecondary(context).withOpacity(0.5),
          ),
        ),
        Row(
          children: [
            Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
          ],
        ),
      ],
    );
  }

  void _openGraph(String sensorType) {
    if (_selectedDeviceId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SensorGraphScreen(
          deviceId: _selectedDeviceId!,
          sensorType: sensorType,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CHART WIDGETS
  // ─────────────────────────────────────────────
  Widget _buildBarChart(List<double> data, Color color) {
    if (data.isEmpty) data = List.generate(7, (_) => 50.0);
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 50,
                  decoration: BoxDecoration(
                    color: ThemeColors.border(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: (value / 100) * 50,
                  decoration: BoxDecoration(
                    color: isLast
                        ? color
                        : color.withOpacity(0.35 + (index * 0.08)),
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

  Widget _buildUsageTrendBars(List<double> data) {
    if (data.isEmpty) data = List.generate(7, (i) => 70.0 - (i * 5));
    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          final isLast = index == data.length - 1;
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 50,
                  decoration: BoxDecoration(
                    color: ThemeColors.border(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: (value / 100) * 50,
                  decoration: BoxDecoration(
                    color: isLast
                        ? barColor
                        : barColor.withOpacity(0.4 + (index * 0.07)),
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

  Widget _buildPhScale(double ph) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final indicatorPosition = (ph / 14) * width;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient bar
            Container(
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE53935),
                    Color(0xFFFF9800),
                    Color(0xFFFFEB3B),
                    Color(0xFF4CAF50),
                    Color(0xFF00BCD4),
                    Color(0xFF2196F3),
                    Color(0xFF9C27B0),
                  ],
                ),
              ),
            ),
            // Indicator line
            Positioned(
              left: indicatorPosition.clamp(2.0, width - 6),
              top: -3,
              child: Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: ThemeColors.textPrimary(context),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: ThemeColors.bg(context),
                    width: 1.5,
                  ),
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

  Widget _buildNoDeviceCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sensors_off_rounded,
            size: 48,
            color: ThemeColors.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('No Device Connected'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('Claim a device to view sensor data'),
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATUS HELPERS
  // ─────────────────────────────────────────────
  String _getSoilStatus(int value, AppLocalizations l10n) {
    if (value < 30) return l10n.t('Low');
    if (value > 80) return l10n.t('High');
    if (value >= 50 && value <= 70) return l10n.t('Optimal');
    return l10n.t('Normal');
  }

  Color _getSoilStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 80) return AppColors.warning;
    if (value >= 50 && value <= 70) return AppColors.primary;
    return AppColors.info;
  }

  String _getTempStatus(int value, AppLocalizations l10n) {
    if (value < 15) return l10n.t('Cold');
    if (value > 35) return l10n.t('Hot');
    if (value > 28) return l10n.t('Warm');   // was incorrectly "Normal"
    return l10n.t('Normal');
  }

  Color _getTempStatusColor(int value) {
    if (value < 15) return AppColors.info;
    if (value > 35) return AppColors.error;
    if (value > 28) return AppColors.warning;
    return AppColors.primary;
  }

  String _getHumidityStatus(int value, AppLocalizations l10n) {
    if (value < 40) return l10n.t('Low');
    if (value > 90) return l10n.t('High');
    if (value >= 60 && value <= 80) return l10n.t('Optimal');
    return l10n.t('Normal');
  }

  Color _getHumidityStatusColor(int value) {
    if (value < 40) return AppColors.warning;
    if (value > 90) return AppColors.warning;
    if (value >= 60 && value <= 80) return AppColors.primary;
    return AppColors.info;
  }

  String _getPhStatus(double value, AppLocalizations l10n) {
    if (value < 5.5) return l10n.t('Acidic');
    if (value > 7.5) return l10n.t('Alkaline');
    return l10n.t('Neutral');
  }

  Color _getPhStatusColor(double value) {
    if (value < 5.5) return AppColors.warning;
    if (value > 7.5) return AppColors.info;
    return AppColors.primary;
  }
}

// ─────────────────────────────────────────────
// SENSOR CARD WRAPPER
// ─────────────────────────────────────────────
class _SensorCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool hasError;

  const _SensorCard({
    required this.child,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasError
                ? AppColors.error.withOpacity(0.45)
                : ThemeColors.border(context),
          ),
        ),
        child: child,
      ),
    );
  }
}
