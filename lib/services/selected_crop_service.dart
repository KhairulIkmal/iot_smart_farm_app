import 'dart:async';

/// Service to manage the globally selected crop/field across all screens
class SelectedCropService {
  // Singleton instance
  static final SelectedCropService _instance = SelectedCropService._internal();
  factory SelectedCropService() => _instance;
  SelectedCropService._internal();

  // Stream controller for selected crop changes
  final _selectedCropController = StreamController<SelectedCropData?>.broadcast();

  // Current selected crop data
  SelectedCropData? _selectedCrop;

  /// Get stream of selected crop changes
  Stream<SelectedCropData?> get selectedCropStream => _selectedCropController.stream;

  /// Get current selected crop
  SelectedCropData? get selectedCrop => _selectedCrop;

  /// Update selected crop (called from dashboard)
  void updateSelectedCrop({
    required String? cropId,
    required String? deviceId,
    required String? cropType,
  }) {
    _selectedCrop = cropId != null
        ? SelectedCropData(
            cropId: cropId,
            deviceId: deviceId,
            cropType: cropType,
          )
        : null;
    _selectedCropController.add(_selectedCrop);
  }

  /// Clear selected crop
  void clearSelectedCrop() {
    _selectedCrop = null;
    _selectedCropController.add(null);
  }

  /// Dispose the service
  void dispose() {
    _selectedCropController.close();
  }
}

/// Data class for selected crop information
class SelectedCropData {
  final String cropId;
  final String? deviceId;
  final String? cropType;

  SelectedCropData({
    required this.cropId,
    this.deviceId,
    this.cropType,
  });
}
