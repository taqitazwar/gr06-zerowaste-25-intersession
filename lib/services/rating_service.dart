import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rating_model.dart';
import '../models/claim_model.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new rating for a completed claim
  static Future<String> createRating({
    required String claimId,
    required String postId,
    required String toUserId,
    required double rating,
    String? review,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to rate users');
    }

    // Validate rating range
    if (rating < 1.0 || rating > 5.0) {
      throw Exception('Rating must be between 1.0 and 5.0');
    }

    // Check if the claim exists and is accepted
    final claimDoc = await _firestore.collection('claims').doc(claimId).get();
    if (!claimDoc.exists) {
      throw Exception('Claim not found');
    }

    final claim = ClaimModel.fromDocument(claimDoc);
    if (claim.status != ClaimStatus.accepted) {
      throw Exception('You can only rate users for accepted claims');
    }

    // Verify user is part of this claim (either claimer or creator)
    if (claim.claimerId != user.uid && claim.creatorId != user.uid) {
      throw Exception(
        'You can only rate users from claims you were involved in',
      );
    }

    // Verify toUserId is the other user in the claim
    String expectedToUserId;
    if (claim.claimerId == user.uid) {
      expectedToUserId = claim.creatorId; // Claimer rating creator
    } else {
      expectedToUserId = claim.claimerId; // Creator rating claimer
    }

    if (toUserId != expectedToUserId) {
      throw Exception('Invalid user to rate for this claim');
    }

    // Check if user has already rated this person for this claim
    final existingRating = await _firestore
        .collection('ratings')
        .where('claimId', isEqualTo: claimId)
        .where('fromUserId', isEqualTo: user.uid)
        .where('toUserId', isEqualTo: toUserId)
        .limit(1)
        .get();

    if (existingRating.docs.isNotEmpty) {
      throw Exception('You have already rated this user for this claim');
    }

    // Create the rating
    final ratingData = RatingModel(
      ratingId: '', // Will be set by Firestore
      claimId: claimId,
      postId: postId,
      fromUserId: user.uid,
      toUserId: toUserId,
      rating: rating,
      review: review,
      timestamp: DateTime.now(),
    );

    final ratingRef = await _firestore
        .collection('ratings')
        .add(ratingData.toMap());

    // Update the target user's overall rating
    await _updateUserRating(toUserId);

    return ratingRef.id;
  }

  /// Check if current user can rate another user for a specific claim
  static Future<bool> canRateUser({
    required String claimId,
    required String toUserId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check if the claim exists and is accepted
      final claimDoc = await _firestore.collection('claims').doc(claimId).get();
      if (!claimDoc.exists) return false;

      final claim = ClaimModel.fromDocument(claimDoc);
      if (claim.status != ClaimStatus.accepted) return false;

      // Verify user is part of this claim
      if (claim.claimerId != user.uid && claim.creatorId != user.uid)
        return false;

      // Verify toUserId is the other user in the claim
      String expectedToUserId = claim.claimerId == user.uid
          ? claim.creatorId
          : claim.claimerId;
      if (toUserId != expectedToUserId) return false;

      // Check if user has already rated this person for this claim
      final existingRating = await _firestore
          .collection('ratings')
          .where('claimId', isEqualTo: claimId)
          .where('fromUserId', isEqualTo: user.uid)
          .where('toUserId', isEqualTo: toUserId)
          .limit(1)
          .get();

      return existingRating.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get all ratings given to a specific user
  static Future<List<RatingModel>> getRatingsForUser(String userId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => RatingModel.fromDocument(doc)).toList();
  }

  /// Get all ratings given by a specific user
  static Future<List<RatingModel>> getRatingsByUser(String userId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('fromUserId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => RatingModel.fromDocument(doc)).toList();
  }

  /// Get ratings for a specific claim
  static Future<List<RatingModel>> getRatingsForClaim(String claimId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('claimId', isEqualTo: claimId)
        .get();

    return snapshot.docs.map((doc) => RatingModel.fromDocument(doc)).toList();
  }

  /// Check if current user has rated another user for a specific claim
  static Future<bool> hasRatedUser({
    required String claimId,
    required String toUserId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection('ratings')
        .where('claimId', isEqualTo: claimId)
        .where('fromUserId', isEqualTo: user.uid)
        .where('toUserId', isEqualTo: toUserId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get claims that can be rated by current user
  static Future<List<ClaimModel>> getRateableClaims() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view rateable claims');
    }

    // Get all accepted claims where user was involved
    final claimerSnapshot = await _firestore
        .collection('claims')
        .where('claimerId', isEqualTo: user.uid)
        .where('status', isEqualTo: ClaimStatus.accepted.name)
        .get();

    final creatorSnapshot = await _firestore
        .collection('claims')
        .where('creatorId', isEqualTo: user.uid)
        .where('status', isEqualTo: ClaimStatus.accepted.name)
        .get();

    // Combine both lists
    final allClaims = <ClaimModel>[];
    allClaims.addAll(
      claimerSnapshot.docs.map((doc) => ClaimModel.fromDocument(doc)),
    );
    allClaims.addAll(
      creatorSnapshot.docs.map((doc) => ClaimModel.fromDocument(doc)),
    );

    // Filter out claims where user has already rated the other party
    final rateableClaims = <ClaimModel>[];
    for (final claim in allClaims) {
      final otherUserId = claim.claimerId == user.uid
          ? claim.creatorId
          : claim.claimerId;
      final hasRated = await hasRatedUser(
        claimId: claim.claimId,
        toUserId: otherUserId,
      );
      if (!hasRated) {
        rateableClaims.add(claim);
      }
    }

    // Sort by response timestamp (most recent first)
    rateableClaims.sort(
      (a, b) => (b.responseTimestamp ?? DateTime(1970)).compareTo(
        a.responseTimestamp ?? DateTime(1970),
      ),
    );

    return rateableClaims;
  }

  /// Update a user's overall rating based on all ratings received
  static Future<void> _updateUserRating(String userId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // No ratings yet, set to 0.0
        await _firestore.collection('users').doc(userId).update({
          'rating': 0.0,
          'totalRatings': 0,
        });
        return;
      }

      // Calculate average rating
      double totalRating = 0.0;
      int ratingCount = ratingsSnapshot.docs.length;

      for (final doc in ratingsSnapshot.docs) {
        final rating = RatingModel.fromDocument(doc);
        totalRating += rating.rating;
      }

      final averageRating = totalRating / ratingCount;

      // Update user's rating and count
      await _firestore.collection('users').doc(userId).update({
        'rating': double.parse(
          averageRating.toStringAsFixed(1),
        ), // Round to 1 decimal
        'totalRatings': ratingCount,
        'lastActive': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating user rating: $e');
      // Don't throw error as this is a background operation
    }
  }

  /// Get user rating statistics
  static Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    final ratingsSnapshot = await _firestore
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    final ratings = ratingsSnapshot.docs
        .map((doc) => RatingModel.fromDocument(doc))
        .toList();

    double totalRating = 0.0;
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (final rating in ratings) {
      totalRating += rating.rating;
      final roundedRating = rating.rating.round();
      distribution[roundedRating] = (distribution[roundedRating] ?? 0) + 1;
    }

    return {
      'averageRating': double.parse(
        (totalRating / ratings.length).toStringAsFixed(1),
      ),
      'totalRatings': ratings.length,
      'ratingDistribution': distribution,
    };
  }
}
