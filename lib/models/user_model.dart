import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? profileImageUrl;
  final GeoPoint location;
  final String fcmToken;
  final double rating;
  final int totalRatings;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImageUrl,
    required this.location,
    required this.fcmToken,
    this.rating = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'location': location,
      'fcmToken': fcmToken,
      'rating': rating,
      'totalRatings': totalRatings,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create UserModel from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      location: map['location'] ?? const GeoPoint(0, 0),
      fcmToken: map['fcmToken'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create UserModel from Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? profileImageUrl,
    GeoPoint? location,
    String? fcmToken,
    double? rating,
    int? totalRatings,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper method to get formatted rating display
  String get ratingDisplay {
    if (totalRatings == 0) return 'No ratings yet';
    return '${rating.toStringAsFixed(1)} ⭐ ($totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'})';
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, rating: $rating, totalRatings: $totalRatings)';
  }
}
