import 'package:cloud_firestore/cloud_firestore.dart';

enum PostStatus {
  available, // Initial state
  claimed, // Someone has claimed it
  completed, // Claim was accepted and completed
  rejected, // Claim was rejected
  expired, // Post has expired
  cancelled, // Post was cancelled by owner
}

enum DietaryTag {
  vegetarian,
  vegan,
  glutenFree,
  dairyFree,
  nutFree,
  halal,
  kosher,
  organic,
  spicy,
  none,
}

class PostModel {
  final String postId;
  final String postedBy;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime expiry;
  final GeoPoint location;
  final String address;
  final String? claimedBy;
  final PostStatus status;
  final List<DietaryTag> dietaryTags;
  final DateTime timestamp;
  final DateTime? updatedAt;

  PostModel({
    required this.postId,
    required this.postedBy,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.expiry,
    required this.location,
    required this.address,
    this.claimedBy,
    this.status = PostStatus.available,
    this.dietaryTags = const [],
    required this.timestamp,
    this.updatedAt,
  });

  // Convert PostModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'postedBy': postedBy,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'expiry': Timestamp.fromDate(expiry),
      'location': location,
      'address': address,
      'claimedBy': claimedBy,
      'status': status.name,
      'dietaryTags': dietaryTags.map((tag) => tag.name).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create PostModel from Firestore Document
  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['postId'] ?? '',
      postedBy: map['postedBy'] ?? '',
      title:
          map['title'] ??
          (map['description'] != null
              ? (map['description'] as String).split('\n').first
              : ''),
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      expiry: map['expiry'] != null
          ? (map['expiry'] as Timestamp).toDate()
          : DateTime.now(),
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'] ?? '',
      claimedBy: map['claimedBy'],
      status: PostStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'available'),
        orElse: () => PostStatus.available,
      ),
      dietaryTags:
          (map['dietaryTags'] as List<dynamic>?)
              ?.map(
                (tag) => DietaryTag.values.firstWhere(
                  (e) => e.name == tag,
                  orElse: () => DietaryTag.none,
                ),
              )
              .toList() ??
          [],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create PostModel from Firestore DocumentSnapshot
  factory PostModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['postId'] = doc.id; // Use document ID as postId
    return PostModel.fromMap(data);
  }

  PostModel copyWith({
    String? postId,
    String? postedBy,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? expiry,
    GeoPoint? location,
    String? address,
    String? claimedBy,
    PostStatus? status,
    List<DietaryTag>? dietaryTags,
    DateTime? timestamp,
    DateTime? updatedAt,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      postedBy: postedBy ?? this.postedBy,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      expiry: expiry ?? this.expiry,
      location: location ?? this.location,
      address: address ?? this.address,
      claimedBy: claimedBy ?? this.claimedBy,
      status: status ?? this.status,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if post is expired
  bool get isExpired => DateTime.now().isAfter(expiry);

  // Check if post is available for claiming
  bool get isAvailable => status == PostStatus.available && !isExpired;

  // Helper method to get dietary tags as readable string
  String get dietaryTagsString {
    if (dietaryTags.isEmpty || dietaryTags.contains(DietaryTag.none)) {
      return 'No dietary restrictions';
    }
    return dietaryTags.map((tag) => _getDietaryTagDisplayName(tag)).join(', ');
  }

  String _getDietaryTagDisplayName(DietaryTag tag) {
    switch (tag) {
      case DietaryTag.vegetarian:
        return 'Vegetarian';
      case DietaryTag.vegan:
        return 'Vegan';
      case DietaryTag.glutenFree:
        return 'Gluten-Free';
      case DietaryTag.dairyFree:
        return 'Dairy-Free';
      case DietaryTag.nutFree:
        return 'Nut-Free';
      case DietaryTag.halal:
        return 'Halal';
      case DietaryTag.kosher:
        return 'Kosher';
      case DietaryTag.organic:
        return 'Organic';
      case DietaryTag.spicy:
        return 'Spicy';
      case DietaryTag.none:
        return 'None';
    }
  }

  @override
  String toString() {
    return 'PostModel(postId: $postId, title: $title, description: $description, status: $status)';
  }
}
