import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final String?
  relatedPostId; // Optional: if rating is related to a specific food post

  RatingModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.relatedPostId,
  });

  // Convert RatingModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'relatedPostId': relatedPostId,
    };
  }

  // Create RatingModel from Firestore Document
  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      id: map['id'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      relatedPostId: map['relatedPostId'],
    );
  }

  // Create RatingModel from Firestore DocumentSnapshot
  factory RatingModel.fromDocument(DocumentSnapshot doc) {
    return RatingModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  RatingModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    String? relatedPostId,
  }) {
    return RatingModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      relatedPostId: relatedPostId ?? this.relatedPostId,
    );
  }

  @override
  String toString() {
    return 'RatingModel(id: $id, fromUserId: $fromUserId, toUserId: $toUserId, rating: $rating)';
  }
}
