import 'package:cloud_firestore/cloud_firestore.dart';

enum PickupStatus { pending, completed }

class ClaimModel {
  final String claimId;
  final String postId;
  final String claimerId;
  final DateTime timestamp;
  final PickupStatus pickupStatus;

  ClaimModel({
    required this.claimId,
    required this.postId,
    required this.claimerId,
    required this.timestamp,
    this.pickupStatus = PickupStatus.pending,
  });

  // Convert ClaimModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'claimId': claimId,
      'postId': postId,
      'claimerId': claimerId,
      'timestamp': Timestamp.fromDate(timestamp),
      'pickupStatus': pickupStatus.name,
    };
  }

  // Create ClaimModel from Firestore Document
  factory ClaimModel.fromMap(Map<String, dynamic> map) {
    return ClaimModel(
      claimId: map['claimId'] ?? '',
      postId: map['postId'] ?? '',
      claimerId: map['claimerId'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      pickupStatus: PickupStatus.values.firstWhere(
        (e) => e.name == (map['pickupStatus'] ?? 'pending'),
        orElse: () => PickupStatus.pending,
      ),
    );
  }

  // Create ClaimModel from Firestore DocumentSnapshot
  factory ClaimModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['claimId'] = doc.id; // Use document ID as claimId
    return ClaimModel.fromMap(data);
  }

  ClaimModel copyWith({
    String? claimId,
    String? postId,
    String? claimerId,
    DateTime? timestamp,
    PickupStatus? pickupStatus,
  }) {
    return ClaimModel(
      claimId: claimId ?? this.claimId,
      postId: postId ?? this.postId,
      claimerId: claimerId ?? this.claimerId,
      timestamp: timestamp ?? this.timestamp,
      pickupStatus: pickupStatus ?? this.pickupStatus,
    );
  }

  @override
  String toString() {
    return 'ClaimModel(claimId: $claimId, postId: $postId, status: $pickupStatus)';
  }
} 