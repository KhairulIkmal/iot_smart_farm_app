import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/user_counter_service.dart';

/// ------------------------------------------------------------
/// FARM LOCATION SCREEN
/// Uses OpenStreetMap (flutter_map) for interactive pin selection
/// ------------------------------------------------------------
class FarmLocationScreen extends StatefulWidget {
  /// When [isSetupMode] is true, the screen is shown as part of new-user
  /// onboarding — it shows a "Skip for now" option and returns `true`/`false`
  /// via Navigator.pop when the user confirms or skips.
  final bool isSetupMode;

  const FarmLocationScreen({super.key, this.isSetupMode = false});

  @override
  State<FarmLocationScreen> createState() => _FarmLocationScreenState();
}

class _FarmLocationScreenState extends State<FarmLocationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  LatLng _selectedLocation = LatLng(3.1390, 101.6869);
  String _selectedAddress = '';
  double _currentZoom = 13.0;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingAddress = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        const apiKey = 'ca6f5f0810167431d32955c435826e53';
        final url = Uri.parse(
          'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(query)}&limit=5&appid=$apiKey',
        );
        final response = await http.get(url);
        if (response.statusCode == 200 && mounted) {
          final List<dynamic> data = json.decode(response.body);
          setState(() => _searchResults = data.cast<Map<String, dynamic>>());
        }
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = (result['lat'] as num).toDouble();
    final lon = (result['lon'] as num).toDouble();
    final newLocation = LatLng(lat, lon);
    setState(() {
      _selectedLocation = newLocation;
      _searchResults = [];
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
    _mapController.move(newLocation, 14.0);
    _getAddressFromCoordinates(newLocation);
  }

  Future<void> _loadSavedLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);
      if (userDoc == null || !userDoc.exists) { setState(() => _isLoading = false); return; }
      final customUserId = userDoc.id;
      final doc = await _firestore
          .collection('users').doc(customUserId)
          .collection('farm').doc('location').get();
      if (doc.exists) {
        final data = doc.data()!;
        final lat = data['latitude']?.toDouble();
        final lng = data['longitude']?.toDouble();
        final address = data['address'] as String?;
        if (lat != null && lng != null) {
          setState(() {
            _selectedLocation = LatLng(lat, lng);
            _selectedAddress = address ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permission permanently denied');
        return;
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Please enable location services');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = newLocation);
      _mapController.move(newLocation, _currentZoom);
      await _getAddressFromCoordinates(newLocation);
    } catch (e) {
      _showErrorSnackBar('Failed to get current location');
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedLocation = point);
    _getAddressFromCoordinates(point);
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() => _isFetchingAddress = true);
    try {
      const apiKey = 'ca6f5f0810167431d32955c435826e53';
      final url = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/reverse?lat=${location.latitude}&lon=${location.longitude}&limit=1&appid=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final place = data[0];
          final name = place['name'] ?? '';
          final state = place['state'] ?? '';
          final country = place['country'] ?? '';
          final parts = <String>[];
          if (name.isNotEmpty) parts.add(name);
          if (state.isNotEmpty) parts.add(state);
          if (country.isNotEmpty) parts.add(country);
          setState(() {
            _selectedAddress = parts.isNotEmpty ? parts.join(', ') : 'Location selected';
          });
        } else {
          setState(() => _selectedAddress = 'Location selected');
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      setState(() {
        _selectedAddress =
            'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
      });
    } finally {
      setState(() => _isFetchingAddress = false);
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) { _showErrorSnackBar('User not authenticated'); return; }
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);
      if (userDoc == null || !userDoc.exists) { _showErrorSnackBar('User not found'); return; }
      final customUserId = userDoc.id;
      await _firestore
          .collection('users').doc(customUserId)
          .collection('farm').doc('location')
          .set({
            'latitude': _selectedLocation.latitude,
            'longitude': _selectedLocation.longitude,
            'address': _selectedAddress,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _showSuccessSnackBar('Farm location saved successfully');
      if (mounted) Navigator.pop(context, widget.isSetupMode ? true : null);
    } catch (e) {
      _showErrorSnackBar('Failed to save location');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Stack(
              children: [
                _buildMapSection(l10n),
                _buildTopGradient(),
                _buildTopOverlay(l10n),
                _buildMapControls(),
                _buildLocationDetailsSection(l10n),
              ],
            ),
    );
  }

  /// ------------------------------------------------
  /// TOP GRADIENT — makes header readable over any map
  /// ------------------------------------------------
  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 240,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.7, 1.0],
            colors: [
              Colors.black.withOpacity(0.75),
              Colors.black.withOpacity(0.35),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// TOP OVERLAY — back button + title + search
  /// ------------------------------------------------
  Widget _buildTopOverlay(AppLocalizations l10n) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Back button + title + optional skip
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, widget.isSetupMode ? false : null),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isSetupMode)
                          Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF69F0AE).withOpacity(0.4)),
                            ),
                            child: const Text(
                              'Step 3 of 4',
                              style: TextStyle(
                                color: Color(0xFF69F0AE),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Text(
                          widget.isSetupMode ? 'Set Farm Location' : l10n.t('Setup Location'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isSetupMode)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Search bar
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        _isSearching
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              )
                            : Icon(Icons.search, color: Colors.white.withOpacity(0.6), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: l10n.t('Search farm address or city...'),
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onChanged: _searchLocation,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _searchLocation,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                              _searchFocusNode.unfocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.white.withOpacity(0.8), size: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Search results
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          children: _searchResults.asMap().entries.map((entry) {
                            final index = entry.key;
                            final result = entry.value;
                            final name = result['name'] ?? '';
                            final state = result['state'] ?? '';
                            final country = result['country'] ?? '';
                            final subtitle = [state, country].where((s) => s.isNotEmpty).join(', ');

                            return Column(
                              children: [
                                if (index != 0)
                                  Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                                GestureDetector(
                                  onTap: () => _selectSearchResult(result),
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.location_on, color: AppColors.primary, size: 16),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (subtitle.isNotEmpty)
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.north_west, color: Colors.white.withOpacity(0.25), size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),

              // Setup-mode importance banner
              if (widget.isSetupMode) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF69F0AE).withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF69F0AE), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pin your farm on the map — this helps with weather data and monitoring accuracy.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// MAP SECTION
  /// ------------------------------------------------
  Widget _buildMapSection(AppLocalizations l10n) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation,
        initialZoom: _currentZoom,
        onTap: _onMapTap,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && position.zoom != null) {
            _currentZoom = position.zoom!;
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.iot.smartfarm',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _selectedLocation,
              width: 60,
              height: 80,
              rotate: true,
              child: _buildCustomMarker(),
            ),
          ],
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// MAP CONTROLS — location + zoom grouped cleanly
  /// ------------------------------------------------
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 220,
      child: Column(
        children: [
          // My location
          _mapControlButton(
            icon: Icons.my_location_rounded,
            onTap: _getCurrentLocation,
            isAccent: true,
          ),
          const SizedBox(height: 8),
          // Zoom group
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _zoomButton(
                  icon: Icons.add,
                  onTap: () {
                    setState(() => _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0));
                    _mapController.move(_selectedLocation, _currentZoom);
                  },
                  isTop: true,
                ),
                Container(height: 1, color: const Color(0xFFEEEEEE)),
                _zoomButton(
                  icon: Icons.remove,
                  onTap: () {
                    setState(() => _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0));
                    _mapController.move(_selectedLocation, _currentZoom);
                  },
                  isTop: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton({required IconData icon, required VoidCallback onTap, bool isAccent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isAccent ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: isAccent ? Colors.black : Colors.black87, size: 20),
      ),
    );
  }

  Widget _zoomButton({required IconData icon, required VoidCallback onTap, required bool isTop}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(14) : Radius.zero,
            bottom: isTop ? Radius.zero : const Radius.circular(14),
          ),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }

  /// Clean pin marker — no label
  Widget _buildCustomMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.agriculture, color: Colors.black, size: 18),
        ),
        // Pin tail
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: AppColors.primary),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// BOTTOM SHEET
  /// ------------------------------------------------
  Widget _buildLocationDetailsSection(AppLocalizations l10n) {
    final cityName = _selectedAddress.isNotEmpty
        ? _selectedAddress.split(',').first.trim()
        : '—';
    final regionName = _selectedAddress.isNotEmpty && _selectedAddress.contains(',')
        ? _selectedAddress.substring(_selectedAddress.indexOf(',') + 1).trim()
        : '';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.agriculture, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),

                        // Address info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isFetchingAddress
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              ThemeColors.textSecondary(context),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n.t('Fetching location...'),
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: ThemeColors.textSecondary(context),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      cityName,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: ThemeColors.textPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              if (regionName.isNotEmpty && !_isFetchingAddress)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    regionName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ThemeColors.textSecondary(context).withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Coordinate chips
                    Row(
                      children: [
                        _coordChip(
                          icon: Icons.location_on_outlined,
                          label: 'Lat',
                          value: _selectedLocation.latitude.toStringAsFixed(4),
                        ),
                        const SizedBox(width: 10),
                        _coordChip(
                          icon: Icons.language,
                          label: 'Long',
                          value: _selectedLocation.longitude.toStringAsFixed(4),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.isSetupMode
                                        ? 'Set My Farm Location'
                                        : l10n.t('Confirm Location'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (widget.isSetupMode) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Text(
                            'Set up later',
                            style: TextStyle(
                              fontSize: 13,
                              color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              decoration: TextDecoration.underline,
                              decorationColor: ThemeColors.textSecondary(context).withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coordChip({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeColors.bg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              '$label  ',
              style: TextStyle(
                fontSize: 11,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textPrimary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Triangle tail for the map pin
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
