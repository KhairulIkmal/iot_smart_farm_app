import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  /// Load existing location from Firestore
  Future<void> _loadSavedLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
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

      await _firestore
          .collection('users')
          .doc(user.uid)
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Set Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Column(
              children: [
                // Map Section
                Expanded(flex: 3, child: _buildMapSection()),

                // Location Details Section
                _buildLocationDetailsSection(),
              ],
            ),
    );
  }

  /// ------------------------------------------------
  /// MAP SECTION
  /// ------------------------------------------------
  Widget _buildMapSection() {
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
              if (hasGesture) {
                _currentZoom = position.zoom;
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
                  width: 50,
                  height: 50,
                  child: _buildCustomMarker(),
                ),
              ],
            ),
          ],
        ),

        // Instruction Tooltip
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Move map to pin farm location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),

        // Current Location Button
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: _getCurrentLocation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Custom map marker with pin design
  Widget _buildCustomMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
        // Pin shadow/point
        Container(
          width: 3,
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.3)],
            ),
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// LOCATION DETAILS SECTION
  /// ------------------------------------------------
  Widget _buildLocationDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected Location Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isFetchingAddress
                        ? Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey[400]!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fetching address...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _selectedAddress.isNotEmpty
                                ? _selectedAddress
                                : 'Tap on map to select location',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Coordinates Display
          Row(
            children: [
              Expanded(
                child: _buildCoordinateChip(
                  label: 'Lat',
                  value: _selectedLocation.latitude.toStringAsFixed(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCoordinateChip(
                  label: 'Lng',
                  value: _selectedLocation.longitude.toStringAsFixed(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildCoordinateChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
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
