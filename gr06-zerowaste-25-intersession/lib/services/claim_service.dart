import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class ClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Collection references
  CollectionReference get _claimsCollection => _firestore.collection('claims');
  CollectionReference get _postsCollection => _firestore.collection('posts');
  CollectionReference get _ratingsCollection =>
      _firestore.collection('ratings');

  /// Create a new claim
  Future<ClaimModel> createClaim({
    required String postId,
    required String donorId,
    String? pickupNotes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user has already claimed this post
      final existingClaim = await _claimsCollection
          .where('postId', isEqualTo: postId)
          .where('claimerId', isEqualTo: currentUser.uid)
          .get();

      if (existingClaim.docs.isNotEmpty) {
        throw Exception('You have already claimed this item');
      }

      // Check if post is still available
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      if (postData['status'] != 'available') {
        throw Exception('This item is no longer available');
      }

      final claimId = _uuid.v4();
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 7)); // 7 days expiry

      final claim = ClaimModel(
        claimId: claimId,
        postId: postId,
        claimerId: currentUser.uid,
        donorId: donorId,
        timestamp: now,
        pickupNotes: pickupNotes,
        expiryDate: expiryDate,
      );

      // Save claim to Firestore
      await _claimsCollection.doc(claimId).set(claim.toMap());

      // Update post status to claimed
      await _postsCollection.doc(postId).update({
        'status': 'claimed',
        'claimedBy': currentUser.uid,
        'claimedAt': Timestamp.fromDate(now),
      });

      return claim;
    } catch (e) {
      throw Exception('Failed to create claim: $e');
    }
  }

  /// Accept a claim (by donor)
  Future<void> acceptClaim(String claimId) async {
    try {
      final claimDoc = await _claimsCollection.doc(claimId).get();
      if (!claimDoc.exists) {
        throw Exception('Claim not found');
      }

      final claim = ClaimModel.fromDocument(claimDoc);
      if (!claim.canBeAccepted) {
        throw Exception('Claim cannot be accepted in current state');
      }

      final currentUser = _auth.currentUser;
      if (currentUser?.uid != claim.donorId) {
        throw Exception('Only the donor can accept this claim');
      }

      await _claimsCollection.doc(claimId).update({
        'status': ClaimStatus.accepted.name,
        'acceptedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to accept claim: $e');
    }
  }

  /// Confirm pickup (by claimer)
  Future<void> confirmPickup(String claimId, {String? notes}) async {
    try {
      final claimDoc = await _claimsCollection.doc(claimId).get();
      if (!claimDoc.exists) {
        throw Exception('Claim not found');
      }

      final claim = ClaimModel.fromDocument(claimDoc);
      if (!claim.canBeConfirmedByClaimer) {
        throw Exception('Pickup cannot be confirmed in current state');
      }

      final currentUser = _auth.currentUser;
      if (currentUser?.uid != claim.claimerId) {
        throw Exception('Only the claimer can confirm pickup');
      }

      final now = DateTime.now();
      final updateData = {
        'pickupConfirmedAt': Timestamp.fromDate(now),
        'status': ClaimStatus.pickup_confirmed.name,
        'pickupConfirmation': PickupConfirmation.claimer_confirmed.name,
      };

      if (notes != null && notes.isNotEmpty) {
        updateData['pickupNotes'] = notes;
      }

      await _claimsCollection.doc(claimId).update(updateData);
    } catch (e) {
      throw Exception('Failed to confirm pickup: $e');
    }
  }

  /// Confirm completion (by donor)
  Future<void> confirmCompletion(String claimId) async {
    try {
      final claimDoc = await _claimsCollection.doc(claimId).get();
      if (!claimDoc.exists) {
        throw Exception('Claim not found');
      }

      final claim = ClaimModel.fromDocument(claimDoc);
      if (!claim.canBeConfirmedByDonor) {
        throw Exception('Completion cannot be confirmed in current state');
      }

      final currentUser = _auth.currentUser;
      if (currentUser?.uid != claim.donorId) {
        throw Exception('Only the donor can confirm completion');
      }

      final now = DateTime.now();
      final newPickupConfirmation =
          claim.pickupConfirmation == PickupConfirmation.claimer_confirmed
          ? PickupConfirmation.both_confirmed
          : PickupConfirmation.donor_confirmed;

      await _claimsCollection.doc(claimId).update({
        'completedAt': Timestamp.fromDate(now),
        'status': ClaimStatus.completed.name,
        'pickupConfirmation': newPickupConfirmation.name,
      });

      // Update post status to completed
      await _postsCollection.doc(claim.postId).update({
        'status': 'completed',
        'completedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      throw Exception('Failed to confirm completion: $e');
    }
  }

  /// Cancel a claim
  Future<void> cancelClaim(String claimId, {String? reason}) async {
    try {
      final claimDoc = await _claimsCollection.doc(claimId).get();
      if (!claimDoc.exists) {
        throw Exception('Claim not found');
      }

      final claim = ClaimModel.fromDocument(claimDoc);
      final currentUser = _auth.currentUser;

      if (currentUser?.uid != claim.claimerId &&
          currentUser?.uid != claim.donorId) {
        throw Exception('You are not authorized to cancel this claim');
      }

      await _claimsCollection.doc(claimId).update({
        'status': ClaimStatus.cancelled.name,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
        'cancelledBy': currentUser?.uid,
        'cancelReason': reason,
      });

      // Reset post status to available
      await _postsCollection.doc(claim.postId).update({
        'status': 'available',
        'claimedBy': null,
        'claimedAt': null,
      });
    } catch (e) {
      throw Exception('Failed to cancel claim: $e');
    }
  }

  /// Get claims for a user (as claimer or donor)
  Stream<List<ClaimModel>> getUserClaims(String userId) {
    return _claimsCollection
        .where('claimerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ClaimModel.fromDocument(doc)).toList(),
        );
  }

  /// Get claims for a specific post
  Stream<List<ClaimModel>> getPostClaims(String postId) {
    return _claimsCollection
        .where('postId', isEqualTo: postId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ClaimModel.fromDocument(doc)).toList(),
        );
  }

  /// Get a specific claim by ID
  Future<ClaimModel?> getClaimById(String claimId) async {
    try {
      final doc = await _claimsCollection.doc(claimId).get();
      if (doc.exists) {
        return ClaimModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get claim: $e');
    }
  }

  /// Mark claim as rated (for rating workflow)
  Future<void> markClaimAsRated(String claimId, bool isClaimer) async {
    try {
      final updateData = isClaimer
          ? {'claimerRated': true}
          : {'donorRated': true};

      await _claimsCollection.doc(claimId).update(updateData);
    } catch (e) {
      throw Exception('Failed to mark claim as rated: $e');
    }
  }

  /// Get claims that are ready for rating
  Stream<List<ClaimModel>> getClaimsReadyForRating(String userId) {
    return _claimsCollection
        .where('claimerId', isEqualTo: userId)
        .where('status', isEqualTo: ClaimStatus.completed.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClaimModel.fromDocument(doc))
              .where((claim) => claim.canRate)
              .toList(),
        );
  }

  /// Check if user can rate another user for a specific claim
  Future<bool> canRateUser(
    String claimId,
    String fromUserId,
    String toUserId,
  ) async {
    try {
      final claim = await getClaimById(claimId);
      if (claim == null || !claim.isCompleted) {
        return false;
      }

      // Check if user has already rated
      final existingRating = await _ratingsCollection
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('relatedPostId', isEqualTo: claim.postId)
          .get();

      return existingRating.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get claim statistics for a user
  Future<Map<String, int>> getUserClaimStats(String userId) async {
    try {
      final claimsQuery = await _claimsCollection
          .where('claimerId', isEqualTo: userId)
          .get();

      final claims = claimsQuery.docs
          .map((doc) => ClaimModel.fromDocument(doc))
          .toList();

      return {
        'total': claims.length,
        'pending': claims.where((c) => c.status == ClaimStatus.pending).length,
        'accepted': claims
            .where((c) => c.status == ClaimStatus.accepted)
            .length,
        'completed': claims
            .where((c) => c.status == ClaimStatus.completed)
            .length,
        'cancelled': claims
            .where((c) => c.status == ClaimStatus.cancelled)
            .length,
        'expired': claims.where((c) => c.isExpired).length,
      };
    } catch (e) {
      throw Exception('Failed to get claim stats: $e');
    }
  }

  /// Clean up expired claims
  Future<void> cleanupExpiredClaims() async {
    try {
      final now = DateTime.now();
      final expiredClaimsQuery = await _claimsCollection
          .where('expiryDate', isLessThan: Timestamp.fromDate(now))
          .where(
            'status',
            whereIn: [ClaimStatus.pending.name, ClaimStatus.accepted.name],
          )
          .get();

      final batch = _firestore.batch();

      for (final doc in expiredClaimsQuery.docs) {
        final claim = ClaimModel.fromDocument(doc);

        // Mark claim as expired
        batch.update(doc.reference, {
          'status': ClaimStatus.expired.name,
          'expiredAt': Timestamp.fromDate(now),
        });

        // Reset post status to available
        batch.update(_postsCollection.doc(claim.postId), {
          'status': 'available',
          'claimedBy': null,
          'claimedAt': null,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cleanup expired claims: $e');
    }
  }
}
