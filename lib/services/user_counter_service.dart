import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage sequential user IDs (USER_001, USER_002, etc.)
class UserCounterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user document by Auth UID
  Future<DocumentSnapshot?> getUserByAuthUid(String uid) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return querySnapshot.docs.first;
  }

  /// Get next user ID (USER_001, USER_002, etc.)
  Future<String> getNextUserId() async {
    final counterDoc = _firestore.collection('counters').doc('users');

    String nextId = '';

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterDoc);

      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()?['count'] ?? 0;
      }

      currentCount++;
      nextId = 'USER_${currentCount.toString().padLeft(3, '0')}';

      transaction.set(counterDoc, {'count': currentCount}, SetOptions(merge: true));
    });

    return nextId;
  }
}
