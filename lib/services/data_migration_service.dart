import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_counter_service.dart';

/// Service to migrate existing data from Auth UIDs to custom user IDs
class DataMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserCounterService _userCounterService = UserCounterService();

  /// Check if current user needs migration
  Future<bool> needsMigration(User user) async {
    final userDoc = await _userCounterService.getUserByAuthUid(user.uid);
    return userDoc == null;
  }

  /// Migrate current user's data from Auth UID to custom user ID
  Future<String?> migrateUserData(User user) async {
    try {
      // Check if user already has a custom ID
      final existingUser = await _userCounterService.getUserByAuthUid(user.uid);
      if (existingUser != null) {
        print('User already migrated: ${existingUser.id}');
        return existingUser.id;
      }

      // Get next custom user ID
      final customUserId = await _userCounterService.getNextUserId();
      print('Migrating user to: $customUserId');

      // Get old user document (if exists)
      final oldUserDoc = await _firestore.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData = {};

      if (oldUserDoc.exists) {
        userData = Map<String, dynamic>.from(oldUserDoc.data() ?? {});
      }

      // Add/update auth UID field
      userData['uid'] = user.uid;
      userData['email'] = user.email;
      userData['displayName'] = user.displayName ?? userData['name'];
      userData['photoURL'] = user.photoURL ?? userData['photoURL'];
      userData['createdAt'] = userData['createdAt'] ?? FieldValue.serverTimestamp();
      userData['updatedAt'] = FieldValue.serverTimestamp();

      // Create new user document with custom ID
      await _firestore.collection('users').doc(customUserId).set(userData);

      // Migrate crops
      await _migrateCrops(user.uid, customUserId);

      // Migrate farm location
      await _migrateFarmLocation(user.uid, customUserId);

      // Delete old user document
      if (oldUserDoc.exists) {
        await _firestore.collection('users').doc(user.uid).delete();
      }

      print('Migration completed for: $customUserId');
      return customUserId;
    } catch (e) {
      print('Migration error: $e');
      return null;
    }
  }

  /// Migrate crops from Auth UID to custom user ID
  Future<void> _migrateCrops(String authUid, String customUserId) async {
    final crops = await _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: authUid)
        .get();

    for (final crop in crops.docs) {
      await crop.reference.update({'farmer_id': customUserId});
      print('Migrated crop: ${crop.id}');
    }

    print('Migrated ${crops.docs.length} crops');
  }

  /// Migrate farm location from Auth UID to custom user ID
  Future<void> _migrateFarmLocation(String authUid, String customUserId) async {
    final locationDoc = await _firestore
        .collection('users')
        .doc(authUid)
        .collection('farm')
        .doc('location')
        .get();

    if (locationDoc.exists) {
      final data = locationDoc.data();
      if (data != null) {
        await _firestore
            .collection('users')
            .doc(customUserId)
            .collection('farm')
            .doc('location')
            .set(data);

        await locationDoc.reference.delete();
        print('Migrated farm location');
      }
    }
  }
}
