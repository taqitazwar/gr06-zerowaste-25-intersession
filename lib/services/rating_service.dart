import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Collection references
  CollectionReference get _ratingsCollection =>
      _firestore.collection('ratings');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Create a new rating
  Future<void> createRating({
    required String fromUserId,
    required String toUserId,
    required double rating,
    String? comment,
    String? relatedPostId,
  }) async {
    try {
      final ratingId = _uuid.v4();
      final ratingModel = RatingModel(
        id: ratingId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
        relatedPostId: relatedPostId,
      );

      // Save rating to Firestore
      await _ratingsCollection.doc(ratingId).set(ratingModel.toMap());

      // Update user's average rating
      await _updateUserAverageRating(toUserId);
    } catch (e) {
      throw Exception('Failed to create rating: $e');
    }
  }

  /// Update an existing rating
  Future<void> updateRating({
    required String ratingId,
    required double rating,
    String? comment,
  }) async {
    try {
      final ratingDoc = await _ratingsCollection.doc(ratingId).get();
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }

      final ratingData = ratingDoc.data() as Map<String, dynamic>;
      final toUserId = ratingData['toUserId'] as String;

      // Update rating
      await _ratingsCollection.doc(ratingId).update({
        'rating': rating,
        'comment': comment,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update user's average rating
      await _updateUserAverageRating(toUserId);
    } catch (e) {
      throw Exception('Failed to update rating: $e');
    }
  }

  /// Delete a rating
  Future<void> deleteRating(String ratingId) async {
    try {
      final ratingDoc = await _ratingsCollection.doc(ratingId).get();
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }

      final ratingData = ratingDoc.data() as Map<String, dynamic>;
      final toUserId = ratingData['toUserId'] as String;

      // Delete rating
      await _ratingsCollection.doc(ratingId).delete();

      // Update user's average rating
      await _updateUserAverageRating(toUserId);
    } catch (e) {
      throw Exception('Failed to delete rating: $e');
    }
  }

  /// Get all ratings for a specific user
  Stream<List<RatingModel>> getUserRatings(String userId) {
    return _ratingsCollection
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RatingModel.fromDocument(doc))
              .toList(),
        );
  }

  /// Get a specific rating by ID
  Future<RatingModel?> getRatingById(String ratingId) async {
    try {
      final doc = await _ratingsCollection.doc(ratingId).get();
      if (doc.exists) {
        return RatingModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get rating: $e');
    }
  }

  /// Check if a user has already rated another user
  Future<RatingModel?> getExistingRating({
    required String fromUserId,
    required String toUserId,
    String? relatedPostId,
  }) async {
    try {
      Query query = _ratingsCollection
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId);

      if (relatedPostId != null) {
        query = query.where('relatedPostId', isEqualTo: relatedPostId);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isNotEmpty) {
        return RatingModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to check existing rating: $e');
    }
  }

  /// Get average rating for a user
  Future<double> getUserAverageRating(String userId) async {
    try {
      final querySnapshot = await _ratingsCollection
          .where('toUserId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 0.0;
      }

      double totalRating = 0.0;
      for (var doc in querySnapshot.docs) {
        final rating = doc.data() as Map<String, dynamic>;
        totalRating += (rating['rating'] ?? 0.0).toDouble();
      }

      return totalRating / querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get average rating: $e');
    }
  }

  /// Get rating statistics for a user
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final querySnapshot = await _ratingsCollection
          .where('toUserId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingDistribution': <int, int>{},
        };
      }

      double totalRating = 0.0;
      Map<int, int> ratingDistribution = {};

      for (var doc in querySnapshot.docs) {
        final rating = doc.data() as Map<String, dynamic>;
        final ratingValue = (rating['rating'] ?? 0.0).toDouble();
        totalRating += ratingValue;

        final ratingInt = ratingValue.round();
        ratingDistribution[ratingInt] =
            (ratingDistribution[ratingInt] ?? 0) + 1;
      }

      return {
        'averageRating': totalRating / querySnapshot.docs.length,
        'totalRatings': querySnapshot.docs.length,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      throw Exception('Failed to get rating stats: $e');
    }
  }

  /// Update user's average rating in the user document
  Future<void> _updateUserAverageRating(String userId) async {
    try {
      final averageRating = await getUserAverageRating(userId);
      await _usersCollection.doc(userId).update({
        'rating': averageRating,
        'lastRatingUpdate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user average rating: $e');
    }
  }

  /// Get recent ratings (for dashboard or activity feed)
  Stream<List<RatingModel>> getRecentRatings({int limit = 10}) {
    return _ratingsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RatingModel.fromDocument(doc))
              .toList(),
        );
  }

  /// Get ratings for a specific post (if ratings are post-related)
  Stream<List<RatingModel>> getPostRatings(String postId) {
    return _ratingsCollection
        .where('relatedPostId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RatingModel.fromDocument(doc))
              .toList(),
        );
  }
}
