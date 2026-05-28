import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../services/live_sensor_service.dart';
import '../../services/weather_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/selected_crop_service.dart';
import '../../services/user_counter_service.dart';
import '../weather/weather_forecast_screen.dart';
import '../analytics/sensor_graph_screen.dart';
import '../more/notifications/notifications_screen.dart';
import '../crop_management/crop_list_screen.dart';

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
/// Counts up from previous value to new value whenever [value] changes.
class _AnimatedSensorValue extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle style;

  const _AnimatedSensorValue({
    required this.value,
    required this.formatter,
    required this.style,
  });

  @override
  State<_AnimatedSensorValue> createState() => _AnimatedSensorValueState();
}

class _AnimatedSensorValueState extends State<_AnimatedSensorValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedSensorValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _anim.value;
      _anim = Tween<double>(begin: _from, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(widget.formatter(_anim.value), style: widget.style),
    );
  }
}

/// Slides up from bottom with a slight fade — feels like drilling into detail
class _SlideUpRoute extends PageRouteBuilder {
  final Widget page;
  _SlideUpRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return child;
          },
        );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
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
  String _farmLocationName = '';

  // Stream subscription for crop selection
  StreamSubscription<SelectedCropData?>? _cropSelectionSubscription;

  // Device code cache: Firestore doc ID → unique_code (AGR-XXXX-XXXX)
  final Map<String, String> _deviceCodeCache = {};

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

  // Pulse animation for online/offline badge
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

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

        // Prefetch unique_code for any unseen device IDs
        final ids = crops
            .map((c) => (c.data() as Map<String, dynamic>)['device_id'] as String? ?? '')
            .where((id) => id.isNotEmpty && !_deviceCodeCache.containsKey(id))
            .toList();
        for (final id in ids) {
          _firestore.collection('devices').doc(id).get().then((doc) {
            final code = doc.data()?['unique_code'] as String?;
            if (code != null && mounted) setState(() => _deviceCodeCache[id] = code);
          }).catchError((_) {});
        }

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
    _pulseController?.dispose();
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
      // Load saved farm location address from Firestore
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await UserCounterService().getUserByAuthUid(user.uid);
        if (userDoc != null && userDoc.exists) {
          final locationDoc = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('farm')
              .doc('location')
              .get();
          if (locationDoc.exists) {
            final addr = locationDoc.data()?['address'] as String? ?? '';
            if (addr.isNotEmpty) {
              _farmLocationName = addr.split(',').first.trim();
            }
          }
        }
      }

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          color: AppColors.primary,
          backgroundColor: ThemeColors.surface(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Field Selector
                _buildHeader(l10n),
                const SizedBox(height: 20),

                // Overview Section
                _buildOverviewHeader(l10n),
                const SizedBox(height: 16),

                // Crop Health Score
                _buildFarmHealthCard(l10n),
                const SizedBox(height: 16),

                // Weather Card (Live from OpenWeather API)
                _buildWeatherCard(l10n),
                const SizedBox(height: 16),

                // Sensor Grid (Live from RTDB)
                _buildSensorGrid(l10n),
                const SizedBox(height: 16),

                // Water Tank Card
                _buildWaterTankCard(l10n),
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
  Widget _buildHeader(AppLocalizations l10n) {
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
                    l10n.t('ACTIVE FIELD'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildOnlineStatusBadge(l10n),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showCropSelectorBottomSheet(_crops, l10n),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
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
                  child: const FaIcon(FontAwesomeIcons.tractor, color: AppColors.primary, size: 28),
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ThemeColors.textPrimary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _deviceCodeCache[selectedData['device_id']] ?? selectedData['device_id'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          l10n.t('Select Field'),
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const FaIcon(FontAwesomeIcons.chevronDown, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Show crop selector bottom sheet
  void _showCropSelectorBottomSheet(List<QueryDocumentSnapshot> crops, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: ThemeColors.bg(context),
          borderRadius: const BorderRadius.only(
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
                color: ThemeColors.textSecondary(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    l10n.t('Select Field'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${crops.length} ${crops.length == 1 ? 'field' : 'fields'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: ThemeColors.border(context), height: 1),
            // Crop list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                            : ThemeColors.surface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : ThemeColors.border(context),
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
                            child: const FaIcon(
                              FontAwesomeIcons.tractor,
                              color: AppColors.primary,
                              size: 20,
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.microchip,
                                      size: 12,
                                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _deviceCodeCache[deviceId] ?? deviceId,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Selected indicator
                          if (isSelected)
                            const FaIcon(
                              FontAwesomeIcons.circleCheck,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Add New Crop button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CropListScreen(showBackButton: true),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.t('Add New Crop'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  /// Online status based on lastSeen timestamp from RTDB (driven by _rtdbSubscription)
  Widget _buildOnlineStatusBadge(AppLocalizations l10n) {
    return _buildStatusBadge(_selectedDeviceId != null && _isOnline, l10n);
  }

  Widget _buildStatusBadge(bool isOnline, AppLocalizations l10n) {
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
          _pulseAnimation != null
              ? AnimatedBuilder(
                  animation: _pulseAnimation!,
                  builder: (context, _) {
                    final dotColor = isOnline ? AppColors.primary : AppColors.error;
                    final v = _pulseAnimation!.value;
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor.withOpacity(v),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withOpacity(v * 0.6),
                            blurRadius: 6 * v,
                            spreadRadius: 2 * v,
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.primary : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 6),
          Text(
            isOnline ? l10n.t('ONLINE') : l10n.t('OFFLINE'),
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
  Widget _buildOverviewHeader(AppLocalizations l10n) {
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
            Text(
              l10n.t('Overview'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Today, ${months[now.month - 1]} ${now.day}',
              style: TextStyle(
                fontSize: 14,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Stack(
              children: [
                FaIcon(
                  FontAwesomeIcons.bell,
                  color: ThemeColors.icon(context),
                  size: 18,
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
  Widget _buildWeatherCard(AppLocalizations l10n) {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
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
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('Weather Unavailable'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('Set farm location in settings'),
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
          gradient: _getWeatherCardGradient(weather),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context).withOpacity(0.4)),
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
                              color: ThemeColors.textSecondary(context).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('h:mm a').format(weather.localTime),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.locationDot,
                            size: 12,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _farmLocationName.isNotEmpty ? _farmLocationName : weather.cityName,
                              style: TextStyle(
                                fontSize: 12,
                                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FaIcon(
                            FontAwesomeIcons.wind,
                            size: 12,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weather.windSpeed.toStringAsFixed(1)} km/h',
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
                      color: ThemeColors.bg(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.clock,
                          size: 12,
                          color: ThemeColors.textSecondary(context).withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.t('Next hour:'),
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemeColors.textPrimary(context),
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

  LinearGradient _getWeatherCardGradient(WeatherData weather) {
    final hour = weather.localTime.hour;
    final main = weather.main.toLowerCase();

    // Base colours by time of day
    if (hour >= 20 || hour < 6) {
      // Night
      if (main.contains('thunder')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF12102A), Color(0xFF1A1535)]);
      if (main.contains('rain') || main.contains('drizzle')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1825), Color(0xFF121E30)]);
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1535), Color(0xFF121A3A)]);
    }
    if (hour < 12) {
      // Morning
      if (main.contains('rain') || main.contains('thunder')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF151E2A), Color(0xFF1A2535)]);
      if (main.contains('cloud')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A2030), Color(0xFF1E2838)]);
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A10), Color(0xFF252510)]);
    }
    if (hour < 17) {
      // Afternoon
      if (main.contains('rain') || main.contains('thunder')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF131E2A), Color(0xFF182030)]);
      if (main.contains('cloud')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A2030), Color(0xFF1E252A)]);
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1505), Color(0xFF20180A)]);
    }
    // Evening
    if (main.contains('rain') || main.contains('thunder')) return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF151525), Color(0xFF1A1830)]);
    return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1208), Color(0xFF201510)]);
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
  /// ------------------------------------------------
  /// FARM HEALTH SCORE CARD
  /// ------------------------------------------------
  Widget _buildFarmHealthCard(AppLocalizations l10n) {
    // Score each sensor 0–100 (skip if error)
    int total = 0;
    int count = 0;

    // Soil moisture: 40–70% ideal
    if (_sensorHealth['soil'] != 'error' && (_soil > 0 || _sensorHealth.isNotEmpty)) {
      int s = _soil < 20 || _soil > 85 ? 20 : (_soil < 35 || _soil > 75 ? 55 : 100);
      total += s; count++;
    }
    // pH: 6.0–7.0 ideal
    if (_sensorHealth['ph'] != 'error' && _ph > 0) {
      int s = _ph < 5 || _ph > 8.5 ? 20 : (_ph < 5.5 || _ph > 7.5 ? 55 : 100);
      total += s; count++;
    }
    // Temperature: 20–30°C ideal
    if (_temp > 0) {
      int s = _temp < 10 || _temp > 40 ? 20 : (_temp < 15 || _temp > 33 ? 55 : 100);
      total += s; count++;
    }
    // Humidity: 40–70% ideal
    if (_humidity > 0) {
      int s = _humidity < 20 || _humidity > 90 ? 20 : (_humidity < 30 || _humidity > 80 ? 55 : 100);
      total += s; count++;
    }

    final score = count > 0 ? (total / count).round() : 0;
    final scoreLabel = score >= 85 ? 'Excellent' : score >= 65 ? 'Good' : score >= 40 ? 'Fair' : 'Poor';
    final scoreColor = score >= 85 ? AppColors.primary : score >= 65 ? const Color(0xFF8BC34A) : score >= 40 ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: ThemeColors.border(context),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
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
                  l10n.t('Crop Health'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? l10n.t('No sensor data')
                      : '$count ${l10n.t('sensors active')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          // Mini sensor status pills
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _healthPill('Soil', _sensorHealth['soil'] != 'error' && _soil > 0),
              const SizedBox(height: 4),
              _healthPill('pH', _sensorHealth['ph'] != 'error' && _ph > 0),
              const SizedBox(height: 4),
              _healthPill('Temp', _temp > 0),
              const SizedBox(height: 4),
              _healthPill('Humid', _humidity > 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthPill(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? AppColors.primary.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ok ? AppColors.primary : AppColors.error,
        ),
      ),
    );
  }

  Widget _buildSensorGrid(AppLocalizations l10n) {
    if (_selectedDeviceId == null) {
      return _buildNoDeviceCard(l10n);
    }

    return Column(
      children: [
        // Row 1: Soil Moisture & pH Level
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, _SlideUpRoute(
                    page: SensorGraphScreen(
                      deviceId: _selectedDeviceId!,
                      sensorType: 'soil',
                      heroTag: 'sensor_icon_soil',
                    ),
                  ));
                },
                child: _buildSensorCard(
                  icon: const FaIcon(FontAwesomeIcons.droplet, color: AppColors.soilMoisture, size: 20),
                  iconColor: AppColors.soilMoisture,
                  iconBgColor: AppColors.soilMoistureBackground,
                  label: l10n.t('SOIL MOISTURE'),
                  value: '$_soil',
                  unit: '%',
                  numericValue: _soil.toDouble(),
                  formatter: (v) => v.round().toString(),
                  status: _getSoilStatus(_soil, l10n),
                  statusColor: _getSoilStatusColor(_soil),
                  progressColor: AppColors.soilMoisture,
                  progressValue: _soil / 100,
                  heroTag: 'sensor_icon_soil',
                  sensorHealth: _sensorHealth['soil'],
                  sensorErrorText: l10n.t('Sensor Error'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, _SlideUpRoute(
                    page: SensorGraphScreen(
                      deviceId: _selectedDeviceId!,
                      sensorType: 'ph',
                      heroTag: 'sensor_icon_ph',
                    ),
                  ));
                },
                child: _buildSensorCard(
                  icon: const FaIcon(FontAwesomeIcons.flask, color: AppColors.phLevel, size: 20),
                  iconColor: AppColors.phLevel,
                  iconBgColor: AppColors.phLevelBackground,
                  label: l10n.t('PH LEVEL'),
                  value: _ph.toStringAsFixed(1),
                  unit: '',
                  numericValue: _ph,
                  formatter: (v) => v.toStringAsFixed(1),
                  status: _getPhStatus(_ph, l10n),
                  statusColor: _getPhStatusColor(_ph),
                  progressColor: AppColors.phLevel,
                  progressValue: _ph / 14,
                  heroTag: 'sensor_icon_ph',
                  sensorHealth: _sensorHealth['ph'],
                  sensorErrorText: l10n.t('Sensor Error'),
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
                  Navigator.push(context, _SlideUpRoute(
                    page: SensorGraphScreen(
                      deviceId: _selectedDeviceId!,
                      sensorType: 'temp',
                      heroTag: 'sensor_icon_temp',
                    ),
                  ));
                },
                child: _buildSensorCard(
                  icon: const FaIcon(FontAwesomeIcons.temperatureHalf, color: AppColors.temperature, size: 20),
                  iconColor: AppColors.temperature,
                  iconBgColor: AppColors.temperatureBackground,
                  label: l10n.t('TEMPERATURE'),
                  value: '$_temp',
                  unit: '°C',
                  numericValue: _temp.toDouble(),
                  formatter: (v) => v.round().toString(),
                  status: _getTempStatus(_temp, l10n),
                  statusColor: _getTempStatusColor(_temp),
                  progressColor: AppColors.temperature,
                  progressValue: _temp / 50,
                  heroTag: 'sensor_icon_temp',
                  isWarning: _temp > 30,
                  sensorErrorText: l10n.t('Sensor Error'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, _SlideUpRoute(
                    page: SensorGraphScreen(
                      deviceId: _selectedDeviceId!,
                      sensorType: 'humidity',
                      heroTag: 'sensor_icon_humidity',
                    ),
                  ));
                },
                child: _buildSensorCard(
                  icon: const FaIcon(FontAwesomeIcons.water, color: AppColors.humidity, size: 20),
                  iconColor: AppColors.humidity,
                  iconBgColor: AppColors.humidityBackground,
                  label: l10n.t('HUMIDITY'),
                  value: '$_humidity',
                  unit: '%',
                  numericValue: _humidity.toDouble(),
                  formatter: (v) => v.round().toString(),
                  status: _getHumidityStatus(_humidity, l10n),
                  statusColor: _getHumidityStatusColor(_humidity),
                  progressColor: AppColors.humidity,
                  progressValue: _humidity / 100,
                  heroTag: 'sensor_icon_humidity',
                  sensorErrorText: l10n.t('Sensor Error'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required Widget icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required Color progressColor,
    required double progressValue,
    required double numericValue,
    required String Function(double) formatter,
    String? heroTag,
    bool isWarning = false,
    String? sensorHealth,
    String sensorErrorText = 'Sensor Error',
  }) {
    final hasError = sensorHealth == 'error';

    return Hero(
      tag: heroTag ?? label,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.error.withOpacity(0.5)
              : isWarning
              ? AppColors.warning.withOpacity(0.5)
              : ThemeColors.border(context),
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
                    color: hasError ? AppColors.error.withOpacity(0.1) : iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
              FaIcon(
                hasError
                    ? FontAwesomeIcons.circleExclamation
                    : isWarning
                    ? FontAwesomeIcons.triangleExclamation
                    : FontAwesomeIcons.circleCheck,
                color: hasError
                    ? AppColors.error
                    : isWarning
                    ? AppColors.warning
                    : AppColors.primary,
                size: 18,
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
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Animated Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              hasError
                  ? Text(
                      '--',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    )
                  : _AnimatedSensorValue(
                      value: numericValue,
                      formatter: formatter,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
              if (unit.isNotEmpty && !hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasError ? sensorErrorText : status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError ? AppColors.error : statusColor,
            ),
          ),
          const SizedBox(height: 12),
          // Animated progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: hasError ? 0 : progressValue.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: v,
                backgroundColor: ThemeColors.bg(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  hasError ? AppColors.error : progressColor,
                ),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    ),
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
            Icons.sensors_off,
            size: 48,
            color: ThemeColors.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('No Device Selected'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('Select a field to view sensor data'),
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
  /// WATER TANK CARD
  /// RTDB: sensors/ESP32_001/waterLevel: 80
  /// RTDB: sensors/ESP32_001/sensorHealth/waterLevel: "error"
  /// ------------------------------------------------
  Widget _buildWaterTankCard(AppLocalizations l10n) {
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
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError
                    ? AppColors.error.withOpacity(0.5)
                    : isCritical
                    ? AppColors.error.withOpacity(0.5)
                    : ThemeColors.border(context),
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
                          Text(
                            l10n.t('Water Tank Level'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ThemeColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasError
                                ? l10n.t('SENSOR ERROR')
                                : isCritical
                                ? l10n.t('CRITICAL LOW')
                                : l10n.t('Normal'),
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
                        color: hasError ? AppColors.error : ThemeColors.textPrimary(context),
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
                    backgroundColor: ThemeColors.bg(context),
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
  String _getSoilStatus(int value, AppLocalizations l10n) {
    if (value < 30) return l10n.t('Low');
    if (value > 80) return l10n.t('High');
    return l10n.t('Normal');
  }

  Color _getSoilStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 80) return AppColors.warning;
    return AppColors.primary;
  }

  String _getPhStatus(double value, AppLocalizations l10n) {
    if (value < 5.5) return l10n.t('Acidic');
    if (value > 7.5) return l10n.t('Alkaline');
    return l10n.t('Optimal');
  }

  Color _getPhStatusColor(double value) {
    if (value < 5.5) return AppColors.warning;
    if (value > 7.5) return AppColors.warning;
    return AppColors.primary;
  }

  String _getTempStatus(int value, AppLocalizations l10n) {
    if (value < 15) return l10n.t('Low');
    if (value > 30) return l10n.t('High');
    return l10n.t('Normal');
  }

  Color _getTempStatusColor(int value) {
    if (value < 15) return AppColors.info;
    if (value > 30) return AppColors.warning;
    return AppColors.primary;
  }

  String _getHumidityStatus(int value, AppLocalizations l10n) {
    if (value < 30) return l10n.t('Low');
    if (value > 70) return l10n.t('High');
    return l10n.t('Normal');
  }

  Color _getHumidityStatusColor(int value) {
    if (value < 30) return AppColors.warning;
    if (value > 70) return AppColors.warning;
    return AppColors.primary;
  }
}
