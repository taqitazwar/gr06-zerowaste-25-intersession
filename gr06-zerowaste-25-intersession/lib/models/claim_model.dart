import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus {
  pending, // Claimer has requested the item
  accepted, // Donor has accepted the claim
  pickup_confirmed, // Claimer has confirmed pickup
  completed, // Donor has confirmed completion
  cancelled, // Claim was cancelled by either party
  expired, // Claim expired without completion
}

enum PickupConfirmation {
  none, // No confirmation yet
  claimer_confirmed, // Claimer confirmed pickup
  donor_confirmed, // Donor confirmed pickup
  both_confirmed, // Both parties confirmed
}

class ClaimModel {
  final String claimId;
  final String postId;
  final String claimerId;
  final String donorId;
  final DateTime timestamp;
  final DateTime? acceptedAt;
  final DateTime? pickupConfirmedAt;
  final DateTime? completedAt;
  final ClaimStatus status;
  final PickupConfirmation pickupConfirmation;
  final String? pickupNotes;
  final bool claimerRated;
  final bool donorRated;
  final DateTime? expiryDate;

  ClaimModel({
    required this.claimId,
    required this.postId,
    required this.claimerId,
    required this.donorId,
    required this.timestamp,
    this.acceptedAt,
    this.pickupConfirmedAt,
    this.completedAt,
    this.status = ClaimStatus.pending,
    this.pickupConfirmation = PickupConfirmation.none,
    this.pickupNotes,
    this.claimerRated = false,
    this.donorRated = false,
    this.expiryDate,
  });

  // Convert ClaimModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'claimId': claimId,
      'postId': postId,
      'claimerId': claimerId,
      'donorId': donorId,
      'timestamp': Timestamp.fromDate(timestamp),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'pickupConfirmedAt': pickupConfirmedAt != null
          ? Timestamp.fromDate(pickupConfirmedAt!)
          : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'status': status.name,
      'pickupConfirmation': pickupConfirmation.name,
      'pickupNotes': pickupNotes,
      'claimerRated': claimerRated,
      'donorRated': donorRated,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    };
  }

  // Create ClaimModel from Firestore Document
  factory ClaimModel.fromMap(Map<String, dynamic> map) {
    return ClaimModel(
      claimId: map['claimId'] ?? '',
      postId: map['postId'] ?? '',
      claimerId: map['claimerId'] ?? '',
      donorId: map['donorId'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      acceptedAt: map['acceptedAt'] != null
          ? (map['acceptedAt'] as Timestamp).toDate()
          : null,
      pickupConfirmedAt: map['pickupConfirmedAt'] != null
          ? (map['pickupConfirmedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      status: ClaimStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => ClaimStatus.pending,
      ),
      pickupConfirmation: PickupConfirmation.values.firstWhere(
        (e) => e.name == (map['pickupConfirmation'] ?? 'none'),
        orElse: () => PickupConfirmation.none,
      ),
      pickupNotes: map['pickupNotes'],
      claimerRated: map['claimerRated'] ?? false,
      donorRated: map['donorRated'] ?? false,
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
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
    String? donorId,
    DateTime? timestamp,
    DateTime? acceptedAt,
    DateTime? pickupConfirmedAt,
    DateTime? completedAt,
    ClaimStatus? status,
    PickupConfirmation? pickupConfirmation,
    String? pickupNotes,
    bool? claimerRated,
    bool? donorRated,
    DateTime? expiryDate,
  }) {
    return ClaimModel(
      claimId: claimId ?? this.claimId,
      postId: postId ?? this.postId,
      claimerId: claimerId ?? this.claimerId,
      donorId: donorId ?? this.donorId,
      timestamp: timestamp ?? this.timestamp,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickupConfirmedAt: pickupConfirmedAt ?? this.pickupConfirmedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      pickupConfirmation: pickupConfirmation ?? this.pickupConfirmation,
      pickupNotes: pickupNotes ?? this.pickupNotes,
      claimerRated: claimerRated ?? this.claimerRated,
      donorRated: donorRated ?? this.donorRated,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  // Helper methods
  bool get canBeAccepted => status == ClaimStatus.pending;
  bool get canBeConfirmedByClaimer => status == ClaimStatus.accepted;
  bool get canBeConfirmedByDonor =>
      status == ClaimStatus.accepted ||
      (status == ClaimStatus.pickup_confirmed &&
          pickupConfirmation == PickupConfirmation.claimer_confirmed);
  bool get isCompleted => status == ClaimStatus.completed;
  bool get canRate => isCompleted && (!claimerRated || !donorRated);
  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  @override
  String toString() {
    return 'ClaimModel(claimId: $claimId, postId: $postId, status: $status, pickupConfirmation: $pickupConfirmation)';
  }
}
