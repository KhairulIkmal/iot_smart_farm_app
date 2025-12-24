import 'package:cloud_firestore/cloud_firestore.dart';

/// ------------------------------------------------------------
/// USER MODEL
///
/// Represents: Authenticated user + profile info
/// Source: Firestore (`users/{uid}`)
///
/// Used in:
/// - Profile screen
/// - Role checks
/// - Admin panel
///
/// Does NOT contain:
/// - FirebaseAuth logic
/// - Login / register methods
/// ------------------------------------------------------------
class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? phone;
  final String? farmName;
  final String role; // 'farmer' or 'admin'
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.phone,
    this.farmName,
    this.role = 'farmer',
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      phone: data['phone'],
      farmName: data['farm_name'],
      role: data['role'] ?? 'farmer',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create from Map (for manual parsing)
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'],
      phone: map['phone'],
      farmName: map['farm_name'],
      role: map['role'] ?? 'farmer',
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'farm_name': farmName,
      'role': role,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Map for creation (includes createdAt)
  Map<String, dynamic> toCreateMap() {
    return {...toMap(), 'createdAt': FieldValue.serverTimestamp()};
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    String? farmName,
    String? role,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      farmName: farmName ?? this.farmName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Check if user is farmer
  bool get isFarmer => role == 'farmer';

  /// Get display name (name or email)
  String get displayName => name ?? email.split('@').first;

  /// Get initials for avatar
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, name: $name, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
