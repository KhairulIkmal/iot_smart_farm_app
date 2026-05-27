import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import '../../services/live_sensor_service.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/selected_crop_service.dart';
import '../more/notifications/notifications_screen.dart';

/// ------------------------------------------------------------
/// IRRIGATION CONTROL SCREEN
///
/// Firebase RTDB Structure:
/// sensors/
///   ESP32_001/
///     soil: 45
///     ph: 6.3
///     waterLevel: 80
///     sensorHealth/waterLevel: "error"
///
/// commands/
///   ESP32_001/
///     pump: "on" | "off"
///     timestamp: 1700000000
///     lastPumpOn: 1700000000  // Last time pump was turned ON
///
/// Firestore Structure:
/// irrigation_rules/{ruleId}
///   crop_id: "abc123"
///   device_id: "ESP32_001"
///   mode: "auto"
///   soil_min: 30
///   soil_max: 60
///   ph_min: 6.0
///   ph_max: 7.5
///   updatedAt: Timestamp
///
/// Shows:
/// - Manual/Auto Toggle
/// - System Status (live from RTDB)
/// - Manual: Start/Stop Pump
/// - Auto: Automation Rules (thresholds)
/// ------------------------------------------------------------
class IrrigationScreen extends StatefulWidget {
  final int initialTabIndex;

  const IrrigationScreen({super.key, this.initialTabIndex = 0});

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SelectedCropService _selectedCropService = SelectedCropService();

  String? _selectedDeviceId;
  String? _selectedCropId;
  bool _isPumpActive = false;
  bool _isLoading = false;
  bool _isSaving = false;

  // Auto mode settings
  double _soilMin = 30;
  double _soilMax = 60;
  double _phMin = 6.0;
  double _phMax = 7.5;

  StreamSubscription<SelectedCropData?>? _cropSelectionSubscription;
  StreamSubscription<LiveSensorData>? _sensorDataSubscription;
  StreamSubscription<DatabaseEvent>? _commandsSubscription;

  // Live state fed by subscriptions
  bool _isConnected = false;
  int _waterLevel = 0;
  int _currentSoil = 0;
  double _currentPh = 7.0;
  String _lastPumpOn = 'Never';

  // Optimistic command tracking — prevents hardware listener from reverting
  // the UI before ESP32 catches up
  bool _commandPending = false;
  bool _expectedPumpState = false;
  Timer? _commandTimeoutTimer;

  // Header state — kept as subscriptions to avoid recreating Firestore listeners on every rebuild
  int _unreadCount = 0;
  String _cropDisplayName = '';
  StreamSubscription<int>? _unreadCountSubscription;
  StreamSubscription<DocumentSnapshot>? _cropNameSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_onTabChanged);

    // Unread notification count — single subscription, never recreated on rebuild
    _unreadCountSubscription = NotificationService().getUnreadCountStream()?.listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });

    // Listen to crop selection changes from dashboard
    _cropSelectionSubscription = _selectedCropService.selectedCropStream.listen((cropData) {
      if (cropData != null) {
        setState(() {
          _selectedCropId = cropData.cropId;
          _selectedDeviceId = cropData.deviceId;
        });
        _loadIrrigationRules();
        _loadPumpStatus();
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
      _loadIrrigationRules();
      _loadPumpStatus();
      _subscribeToCropName(currentSelection.cropId);
    }
  }

  void _onTabChanged() {
    // Don't automatically change mode when switching tabs
    // Manual mode is set when user clicks pump start/stop button
    // Auto mode is set when user clicks "Apply to Auto-Irrigation" button
  }

  /// Subscribe to the selected crop document for display name in header.
  /// Single subscription — not recreated on every rebuild.
  void _subscribeToCropName(String cropId) {
    _cropNameSubscription?.cancel();
    _cropNameSubscription = _firestore
        .collection('crops')
        .doc(cropId)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final cropType = data['crop_type'] ?? 'Unknown';
      final fieldName = data['field_name'] ?? 'Field A';
      setState(() => _cropDisplayName = '$cropType - $fieldName');
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _audioPlayer.dispose();
    _cropSelectionSubscription?.cancel();
    _sensorDataSubscription?.cancel();
    _commandsSubscription?.cancel();
    _commandTimeoutTimer?.cancel();
    _unreadCountSubscription?.cancel();
    _cropNameSubscription?.cancel();
    super.dispose();
  }

  /// Play sound effect and haptic feedback for button press
  void _playSound(bool isStarting) {
    print('🔊 Playing haptic feedback: ${isStarting ? "START (heavy)" : "STOP (medium)"}');

    // Multiple vibrations to make it very noticeable
    if (isStarting) {
      // Strong triple vibration for START
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.heavyImpact();
      });
    } else {
      // Double vibration for STOP
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.mediumImpact();
      });
    }
  }

  /// Load irrigation rules from Firestore
  Future<void> _loadIrrigationRules() async {
    if (_selectedCropId == null) return;

    final rules = await _firestore
        .collection('irrigation_rules')
        .where('crop_id', isEqualTo: _selectedCropId)
        .limit(1)
        .get();

    if (rules.docs.isNotEmpty) {
      final data = rules.docs.first.data();
      setState(() {
        _soilMin = (data['soil_min'] ?? 30).toDouble();
        _soilMax = (data['soil_max'] ?? 60).toDouble();
        _phMin = (data['ph_min'] ?? 6.0).toDouble();
        _phMax = (data['ph_max'] ?? 7.5).toDouble();
      });
    }
  }

  /// Start sensor + command listeners
  void _loadPumpStatus() {
    if (_selectedDeviceId == null) return;

    _sensorDataSubscription?.cancel();
    _commandsSubscription?.cancel();

    // Tell shared service which device to watch (no-op if already set)
    LiveSensorService().setDevice(_selectedDeviceId);

    // Seed from cache immediately
    final cached = LiveSensorService().currentData;
    if (cached != null) _applySensorData(cached);

    // Subscribe to shared service — no separate RTDB listener opened here
    _sensorDataSubscription = LiveSensorService().stream.listen((data) {
      if (!mounted) return;
      _applySensorData(data);
    });

    // Commands path: only for "Last Active" display — kept separate since it's
    // a different RTDB path not covered by the sensor service
    _commandsSubscription = _rtdb
        .ref('commands/$_selectedDeviceId')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lastPumpOn = data['lastPumpOn'] as int?;
      if (lastPumpOn != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(lastPumpOn);
        final h = date.hour.toString().padLeft(2, '0');
        final m = date.minute.toString().padLeft(2, '0');
        setState(() => _lastPumpOn = '$h:$m');
      }
    });
  }

  void _applySensorData(LiveSensorData data) {
    // Sensor fields — always update
    setState(() {
      _isConnected = data.isOnline;
      _waterLevel = data.waterLevel;
      _currentSoil = data.soil;
      _currentPh = data.ph;
    });

    // Pump state — respect command pending to preserve optimistic UI
    if (_commandPending) {
      if (data.pumpOn == _expectedPumpState) {
        _commandTimeoutTimer?.cancel();
        setState(() {
          _commandPending = false;
          _isPumpActive = data.pumpOn;
        });
      }
      // else: hardware hasn't caught up yet — don't override optimistic state
    } else {
      if (_isPumpActive != data.pumpOn) {
        setState(() => _isPumpActive = data.pumpOn);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(l10n),
            const SizedBox(height: 16),

            // Tab Bar
            _buildTabBar(l10n),
            const SizedBox(height: 20),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildManualTab(l10n), _buildAutoTab(l10n)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// HEADER
  /// ------------------------------------------------
  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('Irrigation Control'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
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
                    color: ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeColors.border(context)),
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: ThemeColors.icon(context),
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
          ),
          if (_selectedDeviceId != null && _cropDisplayName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.t('CONTROLLING'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _cropDisplayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// TAB BAR
  /// ------------------------------------------------
  Widget _buildTabBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: ThemeColors.bg(context),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: ThemeColors.textPrimary(context),
          unselectedLabelColor: ThemeColors.textSecondary(context).withOpacity(0.4),
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(text: l10n.t('Manual')),
            Tab(text: l10n.t('Auto')),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// MANUAL TAB
  /// ------------------------------------------------
  Widget _buildManualTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // System Status Card (Live from RTDB)
          _buildSystemStatusCard(l10n),
          const SizedBox(height: 24),

          // Pump Control
          _buildPumpControl(l10n),
          const SizedBox(height: 24),

          // Last Run & Tank Level (Live from RTDB)
          _buildQuickStats(l10n),
          const SizedBox(height: 24),

          // Warning Card
          _buildWarningCard(),
        ],
      ),
    );
  }

  /// System Status with live connection from RTDB
  Widget _buildSystemStatusCard(AppLocalizations l10n) {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard(l10n);
    }

    final isConnected = _isConnected;

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThemeColors.border(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppColors.primary
                                : AppColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isConnected
                                            ? AppColors.primary
                                            : AppColors.error)
                                        .withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected ? 'CONNECTED' : 'DISCONNECTED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isConnected
                                ? AppColors.primary
                                : AppColors.error,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('System Status'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPumpActive
                          ? 'Pump Active • Flow: 12 L/min'
                          : isConnected
                          ? l10n.t('System Ready')
                          : l10n.t('Device Offline'),
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _isPumpActive
                      ? AppColors.primary.withOpacity(0.1)
                      : ThemeColors.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPumpActive
                        ? AppColors.primary.withOpacity(0.3)
                        : ThemeColors.border(context),
                  ),
                ),
                child: Icon(
                  _isPumpActive ? Icons.water_drop : Icons.water_drop_outlined,
                  color: _isPumpActive
                      ? AppColors.primary
                      : ThemeColors.textSecondary(context).withOpacity(0.5),
                  size: 36,
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildPumpControl(AppLocalizations l10n) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(
          children: [
          Text(
            _isPumpActive ? l10n.t('Pump Running') : l10n.t('System Ready'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textSecondary(context).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          // Power Button
          GestureDetector(
            onTap: _isLoading ? null : _togglePump,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPumpActive
                    ? AppColors.primary.withOpacity(0.2)
                    : ThemeColors.bg(context),
                border: Border.all(
                  color: _isPumpActive
                      ? AppColors.primary
                      : ThemeColors.border(context),
                  width: 3,
                ),
                boxShadow: _isPumpActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              // Always show the icon — state flips immediately on tap
              // _isLoading only blocks re-tapping, not the visual
              child: Icon(
                Icons.power_settings_new,
                size: 48,
                color: _isPumpActive
                    ? AppColors.primary
                    : ThemeColors.textSecondary(context).withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPumpActive ? l10n.t('STOP') : l10n.t('START'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isPumpActive ? AppColors.primary : ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to ${_isPumpActive ? 'stop' : 'activate'} main pump',
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Quick Stats with live data from RTDB
  Widget _buildQuickStats(AppLocalizations l10n) {
    if (_selectedDeviceId == null) return const SizedBox.shrink();

    return Row(
      children: [
        // Last Active (Pump Turn On History)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('Last Active'),
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: ThemeColors.textSecondary(context).withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _lastPumpOn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Tank Level (Live from RTDB)
        Expanded(
          child: Builder(builder: (context) {
            final isLow = _waterLevel < 30;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLow
                      ? AppColors.warning.withOpacity(0.5)
                      : ThemeColors.border(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('Tank Level'),
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.water,
                        size: 18,
                        color: isLow ? AppColors.warning : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_waterLevel%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isLow ? AppColors.warning : ThemeColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Manual mode overrides scheduled settings. Pump will run until stopped manually or safety timeout (45m).',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// AUTO TAB
  /// ------------------------------------------------
  Widget _buildAutoTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Status with live sensor values
          _buildAutoSystemStatus(l10n),
          const SizedBox(height: 24),

          // Automation Rules Title
          Text(
            l10n.t('Automation Rules'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('Configure thresholds for auto-irrigation'),
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),

          // Soil Moisture Rule (with live value from RTDB)
          _buildSoilMoistureRule(l10n),
          const SizedBox(height: 16),

          // pH Level Rule (with live value from RTDB)
          _buildPhLevelRule(l10n),
          const SizedBox(height: 24),

          // Save Button
          _buildSaveButton(l10n),
          const SizedBox(height: 12),

          // Turn Off Auto Mode Button
          _buildTurnOffAutoButton(l10n),
        ],
      ),
    );
  }

  /// Auto mode system status with live sensor values
  Widget _buildAutoSystemStatus(AppLocalizations l10n) {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard(l10n);
    }

    final isConnected = _isConnected;
    final soil = _currentSoil;
    final ph = _currentPh;

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThemeColors.border(context)),
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
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.primary
                                    : AppColors.error,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isConnected
                                                ? AppColors.primary
                                                : AppColors.error)
                                            .withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConnected ? 'CONNECTED' : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isConnected
                                    ? AppColors.primary
                                    : AppColors.error,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('System Status'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ThemeColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isPumpActive
                              ? 'Pump Active • Flow: 12 L/min'
                              : 'Auto Mode Active',
                          style: TextStyle(
                            fontSize: 14,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Live sensor values
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThemeColors.bg(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.water_drop,
                            color: AppColors.soilMoisture,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Soil: $soil%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThemeColors.bg(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science,
                            color: AppColors.phLevel,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'pH: ${ph.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  /// Soil Moisture Rule with live current value
  Widget _buildSoilMoistureRule(AppLocalizations l10n) {
    final currentSoil = _currentSoil;
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.soilMoisture.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: AppColors.soilMoisture,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('Soil Moisture'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ThemeColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.t('Target Range'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currentSoil%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.t('Current'),
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.textSecondary(context).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Min Threshold
              _buildSliderRow(
                label: l10n.t('Min Threshold'),
                value: _soilMin,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _soilMin = v),
                color: AppColors.soilMoisture,
              ),
              const SizedBox(height: 16),
              // Max Threshold
              _buildSliderRow(
                label: l10n.t('Max Threshold'),
                value: _soilMax,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _soilMax = v),
                color: AppColors.soilMoisture,
              ),
            ],
          ),
        );
  }

  /// pH Level Rule with live current value
  Widget _buildPhLevelRule(AppLocalizations l10n) {
    final currentPh = _currentPh;

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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.phLevel.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.science,
                      color: AppColors.phLevel,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('pH Level'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ThemeColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.t('Acidity Tolerance'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${currentPh.toStringAsFixed(1)} pH',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.t('Current'),
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.textSecondary(context).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // pH Inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('MIN PH'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColors.bg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ThemeColors.border(context)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _phMin.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColors.textPrimary(context),
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_phMin > 0) {
                                        setState(() => _phMin -= 0.1);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surface(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: ThemeColors.icon(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      if (_phMin < 14) {
                                        setState(() => _phMin += 0.1);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surface(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: ThemeColors.icon(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('MAX PH'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColors.bg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ThemeColors.border(context)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _phMax.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColors.textPrimary(context),
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_phMax > 0) {
                                        setState(() => _phMax -= 0.1);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surface(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: ThemeColors.icon(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      if (_phMax < 14) {
                                        setState(() => _phMax += 0.1);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surface(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: ThemeColors.icon(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: ThemeColors.textSecondary(context).withOpacity(0.7),
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: ThemeColors.border(context),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveIrrigationRules,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: ThemeColors.bg(context),
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ThemeColors.bg(context),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('Apply to Auto-Irrigation'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTurnOffAutoButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isSaving ? null : _turnOffAutoMode,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.power_settings_new, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('Turn Off Auto-Irrigation'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _turnOffAutoMode() async {
    if (_selectedDeviceId == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isSaving = true);

    try {
      // Switch mode to manual in RTDB
      await _rtdb.ref('commands/$_selectedDeviceId/mode').set('manual');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.power_settings_new, color: ThemeColors.icon(context)),
                const SizedBox(width: 12),
                Text(l10n.t('Auto-irrigation turned off')),
              ],
            ),
            backgroundColor: ThemeColors.surface(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('Failed to turn off auto mode')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
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
            Icons.sensors_off,
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
            l10n.t('Claim a device to control irrigation'),
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// ACTIONS
  /// ------------------------------------------------

  /// Toggle pump via RTDB command
  Future<void> _togglePump() async {
    if (_selectedDeviceId == null) return;

    final newPumpState = !_isPumpActive;
    final newStateStr = newPumpState ? 'on' : 'off';

    // Optimistic update — UI flips immediately, no waiting for ESP32 round-trip
    // _commandPending blocks the hardware listener from reverting this until ESP32 confirms
    _commandTimeoutTimer?.cancel();
    setState(() {
      _isPumpActive = newPumpState;
      _isLoading = true;
      _commandPending = true;
      _expectedPumpState = newPumpState;
    });

    // Safety timeout: if ESP32 doesn't confirm within 6s, resume normal tracking
    _commandTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _commandPending = false);
    });

    _playSound(newPumpState);

    try {
      final commandUpdate = <String, dynamic>{
        'pump': newStateStr,
        'mode': 'manual',
        'timestamp': ServerValue.timestamp,
        'source': 'app',
      };

      if (newPumpState) {
        commandUpdate['lastPumpOn'] = ServerValue.timestamp;
      }

      await _rtdb.ref('commands/$_selectedDeviceId').update(commandUpdate);

      // RTDB listener on sensors/.../live/pumpOn will confirm when ESP32 responds.
      // If ESP32 disagrees (e.g. safety cutoff), the listener will correct the state.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newPumpState ? Icons.check_circle : Icons.stop_circle,
                  color: newPumpState ? Colors.white : ThemeColors.icon(context),
                ),
                const SizedBox(width: 12),
                Text(newPumpState ? 'Pump activated' : 'Pump stopped'),
              ],
            ),
            backgroundColor: newPumpState
                ? AppColors.primary
                : ThemeColors.surface(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update — command failed to reach Firebase
      if (mounted) {
        setState(() => _isPumpActive = !newPumpState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to control pump'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Save irrigation rules to Firestore and update mode in RTDB
  Future<void> _saveIrrigationRules() async {
    if (_selectedCropId == null || _selectedDeviceId == null) return;

    setState(() => _isSaving = true);

    try {
      // Check if rule exists
      final existing = await _firestore
          .collection('irrigation_rules')
          .where('crop_id', isEqualTo: _selectedCropId)
          .limit(1)
          .get();

      final ruleData = {
        'crop_id': _selectedCropId,
        'device_id': _selectedDeviceId,
        'mode': 'auto',
        'soil_min': _soilMin,
        'soil_max': _soilMax,
        'ph_min': _phMin,
        'ph_max': _phMax,
        'schedule': 'morning',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save rules to Firestore
      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(ruleData);
      } else {
        await _firestore.collection('irrigation_rules').add(ruleData);
      }

      // Update mode AND thresholds in commands path so ESP32 receives them
      await _rtdb.ref('commands/$_selectedDeviceId').update({
        'mode': 'auto',
        'soilThreshLow': _soilMin.toInt(),    // ESP32 reads this for auto control
        'soilThreshHigh': _soilMax.toInt(),   // ESP32 reads this for auto control
        'minWaterLevel': 15,                   // Minimum tank level to allow pump
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Auto-irrigation activated'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save rules'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
