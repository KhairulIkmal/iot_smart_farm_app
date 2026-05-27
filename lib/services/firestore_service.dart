import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ------------------------------------------------------------
/// FIRESTORE SERVICE
///
/// Handles all Firestore operations for:
/// - Users
/// - Farms
/// - Crops
/// - Devices
/// - Irrigation Rules
///
/// Collections:
/// - users/{uid}
/// - users/{uid}/farm/location
/// - users/{uid}/farm/details
/// - crops/{cropId}
/// - devices/{deviceId}
/// - irrigation_rules/{ruleId}
/// ------------------------------------------------------------
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // USER OPERATIONS
  // ============================================================

  /// Get user document
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  /// Get current user document
  Future<DocumentSnapshot<Map<String, dynamic>>?> getCurrentUser() async {
    if (currentUserId == null) return null;
    return getUser(currentUserId!);
  }

  /// Create or update user
  Future<void> setUser({
    required String uid,
    required Map<String, dynamic> data,
    bool merge = true,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: merge));
  }

  /// Update user fields
  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _firestore.collection('users').doc(uid).update(data);
  }

  /// Stream user document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ============================================================
  // FARM LOCATION OPERATIONS
  // ============================================================

  /// Get farm location
  Future<DocumentSnapshot<Map<String, dynamic>>> getFarmLocation(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('farm')
        .doc('location')
        .get();
  }

  /// Set farm location
  Future<void> setFarmLocation({
    required String uid,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('farm')
        .doc('location')
        .set({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Check if farm location exists
  Future<bool> hasFarmLocation(String uid) async {
    final doc = await getFarmLocation(uid);
    return doc.exists && doc.data()?['latitude'] != null;
  }

  // ============================================================
  // FARM DETAILS OPERATIONS
  // ============================================================

  /// Get farm details
  Future<DocumentSnapshot<Map<String, dynamic>>> getFarmDetails(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('farm')
        .doc('details')
        .get();
  }

  /// Set farm details
  Future<void> setFarmDetails({
    required String uid,
    required String name,
    double? size,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('farm')
        .doc('details')
        .set({
          'name': name,
          'size': size,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ============================================================
  // CROP OPERATIONS
  // ============================================================

  /// Get all crops for a user
  Future<QuerySnapshot<Map<String, dynamic>>> getUserCrops(String uid) {
    return _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: uid)
        .get();
  }

  /// Get active crop for a user
  Future<QuerySnapshot<Map<String, dynamic>>> getActiveCrop(String uid) {
    return _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
  }

  /// Check if user has active crop
  Future<bool> hasActiveCrop(String uid) async {
    final query = await getActiveCrop(uid);
    return query.docs.isNotEmpty;
  }

  /// Stream active crop
  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveCrop(String uid) {
    return _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();
  }

  /// Create new crop
  Future<DocumentReference<Map<String, dynamic>>> createCrop({
    required String farmerId,
    required String deviceId,
    required String cropType,
    String? fieldName,
    String? notes,
  }) {
    return _firestore.collection('crops').add({
      'farmer_id': farmerId,
      'device_id': deviceId,
      'crop_type': cropType,
      'field_name': fieldName ?? 'Field A',
      'notes': notes ?? '',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update crop status
  Future<void> updateCropStatus(String cropId, String status) {
    return _firestore.collection('crops').doc(cropId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deactivate crop
  Future<void> deactivateCrop(String cropId) {
    return _firestore.collection('crops').doc(cropId).update({
      'status': 'inactive',
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deactivate all active crops for a user
  Future<void> deactivateAllUserCrops(String uid) async {
    final activeCrops = await getActiveCrop(uid);
    final batch = _firestore.batch();

    for (final doc in activeCrops.docs) {
      batch.update(doc.reference, {
        'status': 'inactive',
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    }

    return batch.commit();
  }

  // ============================================================
  // DEVICE OPERATIONS
  // ============================================================

  /// Get device by ID
  Future<DocumentSnapshot<Map<String, dynamic>>> getDevice(String deviceId) {
    return _firestore.collection('devices').doc(deviceId).get();
  }

  /// Get all devices
  Future<QuerySnapshot<Map<String, dynamic>>> getAllDevices() {
    return _firestore.collection('devices').get();
  }

  /// Get unassigned devices
  Future<QuerySnapshot<Map<String, dynamic>>> getUnassignedDevices() {
    return _firestore
        .collection('devices')
        .where('status', isEqualTo: 'unassigned')
        .get();
  }

  /// Get devices assigned to user
  Future<QuerySnapshot<Map<String, dynamic>>> getUserDevices(String uid) {
    return _firestore
        .collection('devices')
        .where('assigned_to', isEqualTo: uid)
        .get();
  }

  /// Check if device is available
  Future<bool> isDeviceAvailable(String deviceId) async {
    final doc = await getDevice(deviceId);
    if (!doc.exists) return true; // New device
    return doc.data()?['status'] != 'assigned';
  }

  /// Assign device to user
  Future<void> assignDevice({
    required String deviceId,
    required String userId,
    required String cropId,
  }) {
    return _firestore.collection('devices').doc(deviceId).set({
      'status': 'assigned',
      'assigned_to': userId,
      'assigned_crop_id': cropId,
      'assignedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unassign device
  Future<void> unassignDevice(String deviceId) {
    return _firestore.collection('devices').doc(deviceId).update({
      'status': 'unassigned',
      'assigned_to': FieldValue.delete(),
      'assigned_crop_id': FieldValue.delete(),
      'unassignedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Register new device
  Future<void> registerDevice({
    required String deviceId,
    String? deviceName,
    String? deviceType,
  }) {
    return _firestore.collection('devices').doc(deviceId).set({
      'device_id': deviceId,
      'device_name': deviceName ?? 'ESP32 Controller',
      'device_type': deviceType ?? 'ESP32',
      'status': 'unassigned',
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // IRRIGATION RULES OPERATIONS
  // ============================================================

  /// Get irrigation rules for a crop
  Future<QuerySnapshot<Map<String, dynamic>>> getIrrigationRules(
    String cropId,
  ) {
    return _firestore
        .collection('irrigation_rules')
        .where('crop_id', isEqualTo: cropId)
        .limit(1)
        .get();
  }

  /// Set irrigation rules
  Future<void> setIrrigationRules({
    required String cropId,
    required String deviceId,
    required String mode,
    required double soilMin,
    required double soilMax,
    double? phMin,
    double? phMax,
    String? schedule,
  }) async {
    final existing = await getIrrigationRules(cropId);

    final data = {
      'crop_id': cropId,
      'device_id': deviceId,
      'mode': mode,
      'soil_min': soilMin,
      'soil_max': soilMax,
      'ph_min': phMin ?? 6.0,
      'ph_max': phMax ?? 7.5,
      'schedule': schedule ?? 'morning',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.reference.update(data);
    } else {
      return _firestore.collection('irrigation_rules').add(data).then((_) {});
    }
  }

  /// Stream irrigation rules
  Stream<QuerySnapshot<Map<String, dynamic>>> streamIrrigationRules(
    String cropId,
  ) {
    return _firestore
        .collection('irrigation_rules')
        .where('crop_id', isEqualTo: cropId)
        .limit(1)
        .snapshots();
  }

  // ============================================================
  // CLAIM / UNCLAIM OPERATIONS (ATOMIC)
  // ============================================================

  /// Claim device atomically
  /// Creates crop, updates device, deactivates old crops
  Future<String> claimDevice({
    required String userId,
    required String deviceId,
    required String cropType,
    String? fieldName,
    String? notes,
  }) async {
    return _firestore.runTransaction<String>((transaction) async {
      // 1. Check for existing active crops
      final activeCrops = await _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      // 2. Deactivate existing crops
      for (final doc in activeCrops.docs) {
        transaction.update(doc.reference, {
          'status': 'inactive',
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Create new crop
      final cropRef = _firestore.collection('crops').doc();
      transaction.set(cropRef, {
        'farmer_id': userId,
        'device_id': deviceId,
        'crop_type': cropType,
        'field_name': fieldName ?? 'Field A',
        'notes': notes ?? '',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Update device
      final deviceRef = _firestore.collection('devices').doc(deviceId);
      transaction.set(deviceRef, {
        'status': 'assigned',
        'assigned_to': userId,
        'assigned_crop_id': cropRef.id,
        'assignedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return cropRef.id;
    });
  }

  /// Unclaim device atomically
  /// Deactivates crop and unassigns device
  Future<void> unclaimDevice({
    required String cropId,
    required String deviceId,
  }) async {
    final batch = _firestore.batch();

    // 1. Deactivate crop
    batch.update(_firestore.collection('crops').doc(cropId), {
      'status': 'inactive',
      'deactivatedAt': FieldValue.serverTimestamp(),
      'unclaimed': true,
    });

    // 2. Unassign device
    batch.update(_firestore.collection('devices').doc(deviceId), {
      'status': 'unassigned',
      'assigned_to': FieldValue.delete(),
      'assigned_crop_id': FieldValue.delete(),
      'unassignedAt': FieldValue.serverTimestamp(),
    });

    return batch.commit();
  }

  // ============================================================
  // NOTIFICATIONS / ALERTS OPERATIONS
  // ============================================================

  /// Get user notifications
  Future<QuerySnapshot<Map<String, dynamic>>> getNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
  }

  /// Stream notifications
  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Add notification
  Future<void> addNotification({
    required String uid,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
          'type': type,
          'title': title,
          'message': message,
          'data': data,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Mark notification as read
  Future<void> markNotificationRead(String uid, String notificationId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead(String uid) async {
    final notifications = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    return batch.commit();
  }

  // ============================================================
  // CROP LIFECYCLE / THRESHOLD / NOTES / HARVEST OPERATIONS
  // ============================================================

  Future<void> updateCropLifecycle(String cropId, {
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? growthStage,
  }) {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (plantingDate != null) data['planting_date'] = Timestamp.fromDate(plantingDate);
    if (expectedHarvestDate != null) data['expected_harvest_date'] = Timestamp.fromDate(expectedHarvestDate);
    if (growthStage != null) data['growth_stage'] = growthStage;
    return _firestore.collection('crops').doc(cropId).update(data);
  }

  Future<void> updateCropThresholds(String cropId, {
    double? soilMin, double? soilMax,
    double? phMin, double? phMax,
    double? tempMin, double? tempMax,
    bool clearCustom = false,
  }) {
    if (clearCustom) {
      return _firestore.collection('crops').doc(cropId).update({
        'custom_soil_min': FieldValue.delete(),
        'custom_soil_max': FieldValue.delete(),
        'custom_ph_min': FieldValue.delete(),
        'custom_ph_max': FieldValue.delete(),
        'custom_temp_min': FieldValue.delete(),
        'custom_temp_max': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (soilMin != null) data['custom_soil_min'] = soilMin;
    if (soilMax != null) data['custom_soil_max'] = soilMax;
    if (phMin != null) data['custom_ph_min'] = phMin;
    if (phMax != null) data['custom_ph_max'] = phMax;
    if (tempMin != null) data['custom_temp_min'] = tempMin;
    if (tempMax != null) data['custom_temp_max'] = tempMax;
    return _firestore.collection('crops').doc(cropId).update(data);
  }

  Future<void> addCropNote(String cropId, Map<String, dynamic> noteMap) {
    return _firestore.collection('crops').doc(cropId).update({
      'crop_notes': FieldValue.arrayUnion([noteMap]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addHarvestEntry(String cropId, Map<String, dynamic> entryMap) {
    return _firestore.collection('crops').doc(cropId).update({
      'harvest_log': FieldValue.arrayUnion([entryMap]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
