import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/theme.dart';
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
  const IrrigationScreen({super.key});

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserDevice();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDevice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final crops = await _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (crops.docs.isNotEmpty) {
      final cropData = crops.docs.first.data();
      setState(() {
        _selectedCropId = crops.docs.first.id;
        _selectedDeviceId = cropData['device_id'];
      });
      _loadIrrigationRules();
      _loadPumpStatus();
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

  /// Load pump status from RTDB commands
  void _loadPumpStatus() {
    if (_selectedDeviceId == null) return;

    _rtdb.ref('commands/$_selectedDeviceId/pump').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _isPumpActive = event.snapshot.value == 'on';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Tab Bar
            _buildTabBar(),
            const SizedBox(height: 20),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildManualTab(), _buildAutoTab()],
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
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Irrigation Control',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// TAB BAR
  /// ------------------------------------------------
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.4),
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Manual'),
            Tab(text: 'Auto'),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// MANUAL TAB
  /// ------------------------------------------------
  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // System Status Card (Live from RTDB)
          _buildSystemStatusCard(),
          const SizedBox(height: 24),

          // Pump Control
          _buildPumpControl(),
          const SizedBox(height: 24),

          // Last Run & Tank Level (Live from RTDB)
          _buildQuickStats(),
          const SizedBox(height: 24),

          // Warning Card
          _buildWarningCard(),
        ],
      ),
    );
  }

  /// System Status with live connection from RTDB
  Widget _buildSystemStatusCard() {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard();
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$_selectedDeviceId').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        bool isConnected = false;
        int waterLevel = 0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rootData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          // Read from live node
          if (rootData['live'] != null) {
            final data = Map<String, dynamic>.from(rootData['live']);

            // Check if device is online (lastSeen within 5 minutes)
            final lastSeen = data['lastSeen'] as int?;
            if (lastSeen != null) {
              final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(
                lastSeen * 1000,
              );
              isConnected = DateTime.now().difference(lastSeenDate).inMinutes < 5;
            }

            waterLevel = data['waterLevel'] != null
                ? (data['waterLevel'] is int ? data['waterLevel'] : (data['waterLevel'] as num).toInt())
                : 0;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
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
                    const Text(
                      'System Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPumpActive
                          ? 'Pump Active • Flow: 12 L/min'
                          : isConnected
                          ? 'System Ready'
                          : 'Device Offline',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
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
                      : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPumpActive
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.borderDark,
                  ),
                ),
                child: Icon(
                  _isPumpActive ? Icons.water_drop : Icons.water_drop_outlined,
                  color: _isPumpActive
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.5),
                  size: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPumpControl() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
          Text(
            _isPumpActive ? 'Pump Running' : 'System Ready',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
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
                    : AppColors.backgroundDark,
                border: Border.all(
                  color: _isPumpActive
                      ? AppColors.primary
                      : AppColors.borderDark,
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new,
                      size: 48,
                      color: _isPumpActive
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.5),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPumpActive ? 'STOP' : 'START',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isPumpActive ? AppColors.primary : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to ${_isPumpActive ? 'stop' : 'activate'} main pump',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Quick Stats with live data from RTDB
  Widget _buildQuickStats() {
    return Row(
      children: [
        // Last Run (from Firestore or local storage)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Run',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Today, 08:30',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
          child: StreamBuilder<DatabaseEvent>(
            stream: _selectedDeviceId != null
                ? _rtdb.ref('sensors/$_selectedDeviceId/waterLevel').onValue.asBroadcastStream()
                : null,
            builder: (context, snapshot) {
              int waterLevel = 0;
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                waterLevel = snapshot.data!.snapshot.value is int
                    ? snapshot.data!.snapshot.value as int
                    : (snapshot.data!.snapshot.value as num).toInt();
              }

              final isLow = waterLevel < 30;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLow
                        ? AppColors.warning.withOpacity(0.5)
                        : AppColors.borderDark,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tank Level',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
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
                          '$waterLevel%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isLow ? AppColors.warning : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
  Widget _buildAutoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Status with live sensor values
          _buildAutoSystemStatus(),
          const SizedBox(height: 24),

          // Automation Rules Title
          const Text(
            'Automation Rules',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure thresholds for auto-irrigation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),

          // Soil Moisture Rule (with live value from RTDB)
          _buildSoilMoistureRule(),
          const SizedBox(height: 16),

          // pH Level Rule (with live value from RTDB)
          _buildPhLevelRule(),
          const SizedBox(height: 24),

          // Save Button
          _buildSaveButton(),
        ],
      ),
    );
  }

  /// Auto mode system status with live sensor values
  Widget _buildAutoSystemStatus() {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard();
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$_selectedDeviceId').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        bool isConnected = false;
        int soil = 0;
        double ph = 0.0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rootData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          // Read from live node
          if (rootData['live'] != null) {
            final data = Map<String, dynamic>.from(rootData['live']);

            final lastSeen = data['lastSeen'] as int?;
            if (lastSeen != null) {
              final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(
                lastSeen * 1000,
              );
              isConnected = DateTime.now().difference(lastSeenDate).inMinutes < 5;
            }

            soil = data['soil'] != null
                ? (data['soil'] is int ? data['soil'] : (data['soil'] as num).toInt())
                : 0;
            ph = data['ph'] != null
                ? (data['ph'] is double ? data['ph'] : (data['ph'] as num).toDouble())
                : 0.0;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
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
                        const Text(
                          'System Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isPumpActive
                              ? 'Pump Active • Flow: 12 L/min'
                              : 'Auto Mode Active',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
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
                        color: AppColors.backgroundDark,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
      },
    );
  }

  /// Soil Moisture Rule with live current value
  Widget _buildSoilMoistureRule() {
    return StreamBuilder<DatabaseEvent>(
      stream: _selectedDeviceId != null
          ? _rtdb.ref('sensors/$_selectedDeviceId/soil').onValue.asBroadcastStream()
          : null,
      builder: (context, snapshot) {
        int currentSoil = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          currentSoil = snapshot.data!.snapshot.value is int
              ? snapshot.data!.snapshot.value as int
              : (snapshot.data!.snapshot.value as num).toInt();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soil Moisture',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Target Range',
                          style: TextStyle(
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Min Threshold
              _buildSliderRow(
                label: 'Min Threshold',
                value: _soilMin,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _soilMin = v),
                color: AppColors.soilMoisture,
              ),
              const SizedBox(height: 16),
              // Max Threshold
              _buildSliderRow(
                label: 'Max Threshold',
                value: _soilMax,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _soilMax = v),
                color: AppColors.soilMoisture,
              ),
            ],
          ),
        );
      },
    );
  }

  /// pH Level Rule with live current value
  Widget _buildPhLevelRule() {
    return StreamBuilder<DatabaseEvent>(
      stream: _selectedDeviceId != null
          ? _rtdb.ref('sensors/$_selectedDeviceId/ph').onValue.asBroadcastStream()
          : null,
      builder: (context, snapshot) {
        double currentPh = 7.0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          currentPh = snapshot.data!.snapshot.value is double
              ? snapshot.data!.snapshot.value as double
              : (snapshot.data!.snapshot.value as num).toDouble();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'pH Level',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Acidity Tolerance',
                          style: TextStyle(
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
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
                          'MIN PH',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _phMin.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
                                        color: AppColors.surfaceDark,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Colors.white,
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
                                        color: AppColors.surfaceDark,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Colors.white,
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
                          'MAX PH',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _phMax.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
                                        color: AppColors.surfaceDark,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Colors.white,
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
                                        color: AppColors.surfaceDark,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Colors.white,
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
      },
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
                color: Colors.white.withOpacity(0.7),
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
            inactiveTrackColor: AppColors.borderDark,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveIrrigationRules,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.backgroundDark,
                  ),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Apply to Auto-Irrigation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
            'No Device Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Claim a device to control irrigation',
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
  /// ACTIONS
  /// ------------------------------------------------

  /// Toggle pump via RTDB command
  Future<void> _togglePump() async {
    if (_selectedDeviceId == null) return;

    setState(() => _isLoading = true);

    try {
      final newState = _isPumpActive ? 'off' : 'on';

      // Send command to ESP32 via RTDB
      await _rtdb.ref('commands/$_selectedDeviceId').set({
        'pump': newState,
        'timestamp': ServerValue.timestamp,
        'source': 'app',
      });

      setState(() {
        _isPumpActive = !_isPumpActive;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isPumpActive ? Icons.check_circle : Icons.stop_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(_isPumpActive ? 'Pump started' : 'Pump stopped'),
              ],
            ),
            backgroundColor: _isPumpActive
                ? AppColors.primary
                : AppColors.surfaceDark,
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
      setState(() => _isLoading = false);
    }
  }

  /// Save irrigation rules to Firestore
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

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(ruleData);
      } else {
        await _firestore.collection('irrigation_rules').add(ruleData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Irrigation rules saved'),
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
