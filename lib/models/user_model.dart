import 'package:cloud_firestore/cloud_firestore.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final String? cityState; // e.g., "San Francisco, CA"

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.cityState,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'cityState': cityState,
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      cityState: map['cityState'],
    );
  }
}

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl; // Add profile picture URL
  final LocationData? currentLocation;
  final String? fcmToken; // For push notifications
  final double rating;
  final int totalPosts;
  final int totalClaims;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.currentLocation,
    this.fcmToken,
    this.rating = 0.0,
    this.totalPosts = 0,
    this.totalClaims = 0,
    required this.createdAt,
    required this.lastActive,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      currentLocation: data['currentLocation'] != null 
          ? LocationData.fromMap(data['currentLocation'] as Map<String, dynamic>)
          : null,
      fcmToken: data['fcmToken'],
      rating: data['rating']?.toDouble() ?? 0.0,
      totalPosts: data['totalPosts'] ?? 0,
      totalClaims: data['totalClaims'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'currentLocation': currentLocation?.toMap(),
      'fcmToken': fcmToken,
      'rating': rating,
      'totalPosts': totalPosts,
      'totalClaims': totalClaims,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  // Copy with new values
  UserModel copyWith({
    String? email,
    String? displayName,
    String? profileImageUrl,
    LocationData? currentLocation,
    String? fcmToken,
    double? rating,
    int? totalPosts,
    int? totalClaims,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currentLocation: currentLocation ?? this.currentLocation,
      fcmToken: fcmToken ?? this.fcmToken,
      rating: rating ?? this.rating,
      totalPosts: totalPosts ?? this.totalPosts,
      totalClaims: totalClaims ?? this.totalClaims,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
} 