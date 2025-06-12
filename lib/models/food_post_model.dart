import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum FoodPostStatus {
  available,
  claimed,
  completed,
  expired,
  cancelled,
}

enum DietaryTag {
  vegetarian,
  vegan,
  glutenFree,
  halal,
  kosher,
  dairyFree,
  nutFree,
  organic,
  lowSodium,
  sugarFree;

  String get displayName {
    switch (this) {
      case DietaryTag.vegetarian:
        return 'Vegetarian';
      case DietaryTag.vegan:
        return 'Vegan';
      case DietaryTag.glutenFree:
        return 'Gluten-Free';
      case DietaryTag.halal:
        return 'Halal';
      case DietaryTag.kosher:
        return 'Kosher';
      case DietaryTag.dairyFree:
        return 'Dairy-Free';
      case DietaryTag.nutFree:
        return 'Nut-Free';
      case DietaryTag.organic:
        return 'Organic';
      case DietaryTag.lowSodium:
        return 'Low Sodium';
      case DietaryTag.sugarFree:
        return 'Sugar-Free';
    }
  }
}

class FoodPostModel {
  final String id;
  final String donorId;
  final String title;
  final String description;
  final List<String> imageUrls;
  final LocationData pickupLocation;
  final List<DietaryTag> dietaryTags;
  final DateTime expiryTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FoodPostStatus status;
  final String? claimedBy; // User ID who claimed the food
  final DateTime? claimedAt;
  final String? pickupInstructions;

  FoodPostModel({
    required this.id,
    required this.donorId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.pickupLocation,
    required this.dietaryTags,
    required this.expiryTime,
    required this.createdAt,
    required this.updatedAt,
    this.status = FoodPostStatus.available,
    this.claimedBy,
    this.claimedAt,
    this.pickupInstructions,
  });

  // Convert from Firestore document
  factory FoodPostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    
    return FoodPostModel(
      id: doc.id,
      donorId: data['donorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      pickupLocation: LocationData.fromMap(data['pickupLocation'] as Map<String, dynamic>),
      dietaryTags: (data['dietaryTags'] as List<dynamic>? ?? [])
          .map((tag) => DietaryTag.values.firstWhere(
            (e) => e.toString().split('.').last == tag,
            orElse: () => DietaryTag.organic,
          ))
          .toList(),
      expiryTime: (data['expiryTime'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      status: FoodPostStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => FoodPostStatus.available,
      ),
      claimedBy: data['claimedBy'],
      claimedAt: data['claimedAt'] != null 
          ? (data['claimedAt'] as Timestamp).toDate()
          : null,
      pickupInstructions: data['pickupInstructions'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'donorId': donorId,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'pickupLocation': pickupLocation.toMap(),
      'dietaryTags': dietaryTags.map((tag) => tag.toString().split('.').last).toList(),
      'expiryTime': Timestamp.fromDate(expiryTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.toString().split('.').last,
      'claimedBy': claimedBy,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'pickupInstructions': pickupInstructions,
    };
  }

  // Copy with new values
  FoodPostModel copyWith({
    String? id,
    String? donorId,
    String? title,
    String? description,
    List<String>? imageUrls,
    LocationData? pickupLocation,
    Set<DietaryTag>? dietaryTags,
    DateTime? expiryTime,
    FoodPostStatus? status,
    String? claimedBy,
    DateTime? claimedAt,
    String? pickupInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodPostModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dietaryTags: dietaryTags?.toList() ?? this.dietaryTags,
      expiryTime: expiryTime ?? this.expiryTime,
      status: status ?? this.status,
      claimedBy: claimedBy ?? this.claimedBy,
      claimedAt: claimedAt ?? this.claimedAt,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isAvailable => status == FoodPostStatus.available;
  bool get isClaimed => status == FoodPostStatus.claimed;
  bool get isExpired => DateTime.now().isAfter(expiryTime);
  
  // Get dietary tags as readable strings
  List<String> get dietaryTagsAsStrings {
    return dietaryTags.map((tag) => tag.displayName).toList();
  }
} 