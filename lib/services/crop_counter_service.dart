import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage sequential crop IDs (CROP_001, CROP_002, etc.)
class CropCounterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get next crop ID (CROP_001, CROP_002, etc.)
  Future<String> getNextCropId() async {
    final counterDoc = _firestore.collection('counters').doc('crop_counter');

    String nextId = '';

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterDoc);

      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()?['count'] ?? 0;
      }

      currentCount++;
      nextId = 'CROP_${currentCount.toString().padLeft(3, '0')}';

      transaction.set(counterDoc, {'count': currentCount}, SetOptions(merge: true));
    });

    return nextId;
  }
}
