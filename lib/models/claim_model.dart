import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus { 
  pending,    // Initial state when claim is made
  accepted,   // Creator accepted the claim
  rejected    // Creator rejected the claim
}

class ClaimModel {
  final String claimId;
  final String postId;
  final String claimerId;
  final String creatorId;  // Post creator's ID
  final DateTime timestamp;
  final ClaimStatus status;
  final DateTime? responseTimestamp;  // When creator responded
  final String? responseMessage;      // Optional message from creator

  ClaimModel({
    required this.claimId,
    required this.postId,
    required this.claimerId,
    required this.creatorId,
    required this.timestamp,
    this.status = ClaimStatus.pending,
    this.responseTimestamp,
    this.responseMessage,
  });

  // Convert ClaimModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'claimId': claimId,
      'postId': postId,
      'claimerId': claimerId,
      'creatorId': creatorId,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      'responseTimestamp': responseTimestamp != null 
          ? Timestamp.fromDate(responseTimestamp!) 
          : null,
      'responseMessage': responseMessage,
    };
  }

  // Create ClaimModel from Firestore Document
  factory ClaimModel.fromMap(Map<String, dynamic> map) {
    return ClaimModel(
      claimId: map['claimId'] ?? '',
      postId: map['postId'] ?? '',
      claimerId: map['claimerId'] ?? '',
      creatorId: map['creatorId'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      status: ClaimStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => ClaimStatus.pending,
      ),
      responseTimestamp: map['responseTimestamp'] != null
          ? (map['responseTimestamp'] as Timestamp).toDate()
          : null,
      responseMessage: map['responseMessage'],
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
    String? creatorId,
    DateTime? timestamp,
    ClaimStatus? status,
    DateTime? responseTimestamp,
    String? responseMessage,
  }) {
    return ClaimModel(
      claimId: claimId ?? this.claimId,
      postId: postId ?? this.postId,
      claimerId: claimerId ?? this.claimerId,
      creatorId: creatorId ?? this.creatorId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      responseMessage: responseMessage ?? this.responseMessage,
    );
  }

  @override
  String toString() {
    return 'ClaimModel(claimId: $claimId, postId: $postId, status: $status)';
  }
} 