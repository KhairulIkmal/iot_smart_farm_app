import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/user_counter_service.dart';

/// ------------------------------------------------------------
/// FARM LOCATION SCREEN
/// Uses OpenStreetMap (flutter_map) for interactive pin selection
/// No API key required for maps
/// Location sent to OpenWeather API for weather forecast
/// ------------------------------------------------------------
class FarmLocationScreen extends StatefulWidget {
  const FarmLocationScreen({super.key});

  @override
  State<FarmLocationScreen> createState() => _FarmLocationScreenState();
}

class _FarmLocationScreenState extends State<FarmLocationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  // Default location (Malaysia - Kuala Lumpur)
  LatLng _selectedLocation = LatLng(3.1390, 101.6869);
  String _selectedAddress = '';
  double _currentZoom = 13.0;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingAddress = false;

  // Search
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

  /// Forward geocoding — search place name → coordinates
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
          setState(() {
            _searchResults = data.cast<Map<String, dynamic>>();
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  /// Move map to selected search result
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

  /// Load existing location from Firestore
  Future<void> _loadSavedLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final customUserId = userDoc.id;

      final doc = await _firestore
          .collection('users')
          .doc(customUserId)
          .collection('farm')
          .doc('location')
          .get();

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

  /// Get current GPS location
  Future<void> _getCurrentLocation() async {
    try {
      // Check permission
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

      // Check if service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Please enable location services');
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = newLocation;
      });

      // Move map to new location
      _mapController.move(newLocation, _currentZoom);

      // Get address for new location
      await _getAddressFromCoordinates(newLocation);
    } catch (e) {
      _showErrorSnackBar('Failed to get current location');
    }
  }

  /// Handle map tap - update pin location
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _getAddressFromCoordinates(point);
  }

  /// Get address from coordinates using OpenWeather Geocoding API
  /// API Key: ca6f5f0810167431d32955c435826e53
  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() => _isFetchingAddress = true);

    try {
      // Using OpenWeather Reverse Geocoding API
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

          // Build address string
          final parts = <String>[];
          if (name.isNotEmpty) parts.add(name);
          if (state.isNotEmpty) parts.add(state);
          if (country.isNotEmpty) parts.add(country);

          setState(() {
            _selectedAddress = parts.isNotEmpty
                ? parts.join(', ')
                : 'Location selected';
          });
        } else {
          setState(() {
            _selectedAddress = 'Location selected';
          });
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

  /// Save location to Firestore
  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) {
        _showErrorSnackBar('User not found');
        return;
      }

      final customUserId = userDoc.id;

      await _firestore
          .collection('users')
          .doc(customUserId)
          .collection('farm')
          .doc('location')
          .set({
            'latitude': _selectedLocation.latitude,
            'longitude': _selectedLocation.longitude,
            'address': _selectedAddress,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showSuccessSnackBar('Farm location saved successfully');

      if (mounted) {
        Navigator.pop(context);
      }
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
      backgroundColor: ThemeColors.bg(context),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Stack(
              children: [
                // Full screen map
                _buildMapSection(l10n),

                // Top overlay with back button and search
                _buildTopOverlay(l10n),

                // Bottom location details sheet
                _buildLocationDetailsSection(l10n),
              ],
            ),
    );
  }

  /// ------------------------------------------------
  /// TOP OVERLAY (Back button + Search bar + Title)
  /// ------------------------------------------------
  Widget _buildTopOverlay(AppLocalizations l10n) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Back button and title
              Row(
                children: [
                  GestureDetector(
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
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.t('Setup Location'),
                        style: TextStyle(
                          color: ThemeColors.textPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44), // Balance for back button
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3D2F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.5),
                                size: 22,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.t('Search farm address or city...'),
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
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
                              child: Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Search results dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2D20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: _searchResults.asMap().entries.map((entry) {
                            final index = entry.key;
                            final result = entry.value;
                            final name = result['name'] ?? '';
                            final state = result['state'] ?? '';
                            final country = result['country'] ?? '';

                            final subtitle = [state, country]
                                .where((s) => s.isNotEmpty)
                                .join(', ');

                            return Column(
                              children: [
                                if (index != 0)
                                  Divider(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                GestureDetector(
                                  onTap: () => _selectSearchResult(result),
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                    color: Colors.white
                                                        .withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
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
    return Stack(
      children: [
        // OpenStreetMap
        FlutterMap(
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
            // Map Tiles (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.iot.smartfarm',
            ),

            // Pin Marker
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLocation,
                  width: 80,
                  height: 100,
                  rotate: true,
                  child: _buildCustomMarker(l10n),
                ),
              ],
            ),
          ],
        ),

        // Zoom Controls
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 160,
          child: Column(
            children: [
              // Current Location Button
              GestureDetector(
                onTap: _getCurrentLocation,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3D2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Zoom In
              GestureDetector(
                onTap: () {
                  setState(() => _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0));
                  _mapController.move(_selectedLocation, _currentZoom);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3D2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Zoom Out
              GestureDetector(
                onTap: () {
                  setState(() => _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0));
                  _mapController.move(_selectedLocation, _currentZoom);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3D2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Custom map marker with pin design
  Widget _buildCustomMarker(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Green pin icon
        const Icon(
          Icons.location_on,
          color: AppColors.primary,
          size: 48,
          shadows: [
            Shadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // "DRAG TO ADJUST" label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.t('DRAG TO ADJUST'),
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// LOCATION DETAILS SECTION
  /// ------------------------------------------------
  Widget _buildLocationDetailsSection(AppLocalizations l10n) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Farm icon and location details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Farm icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Location details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _isFetchingAddress
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.grey[500]!,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          l10n.t('Fetching location...'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _selectedAddress.isNotEmpty
                                          ? _selectedAddress.split(',').first
                                          : 'Green Valley Farm',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: ThemeColors.textPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 20),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'EDIT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedAddress.isNotEmpty && _selectedAddress.contains(',')
                              ? _selectedAddress.substring(_selectedAddress.indexOf(',') + 2)
                              : '1240 Farm Road, California, USA',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Coordinates
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lat : ${_selectedLocation.latitude.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Icon(
                              Icons.language,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Long : ${_selectedLocation.longitude.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Confirm Location Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              l10n.t('Confirm Location'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
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
