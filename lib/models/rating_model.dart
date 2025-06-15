import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String ratingId;
  final String claimId; // Reference to the claim this rating is for
  final String postId; // Reference to the post this rating is for
  final String fromUserId; // User who gave the rating
  final String toUserId; // User who received the rating
  final double rating; // Rating value (1-5 stars)
  final String? review; // Optional text review
  final DateTime timestamp; // When the rating was given

  RatingModel({
    required this.ratingId,
    required this.claimId,
    required this.postId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.review,
    required this.timestamp,
  });

  // Convert RatingModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'ratingId': ratingId,
      'claimId': claimId,
      'postId': postId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'review': review,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create RatingModel from Firestore Document
  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      ratingId: map['ratingId'] ?? '',
      claimId: map['claimId'] ?? '',
      postId: map['postId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create RatingModel from Firestore DocumentSnapshot
  factory RatingModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['ratingId'] = doc.id; // Use document ID as ratingId
    return RatingModel.fromMap(data);
  }

  RatingModel copyWith({
    String? ratingId,
    String? claimId,
    String? postId,
    String? fromUserId,
    String? toUserId,
    double? rating,
    String? review,
    DateTime? timestamp,
  }) {
    return RatingModel(
      ratingId: ratingId ?? this.ratingId,
      claimId: claimId ?? this.claimId,
      postId: postId ?? this.postId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'RatingModel(ratingId: $ratingId, fromUserId: $fromUserId, toUserId: $toUserId, rating: $rating)';
  }
}
