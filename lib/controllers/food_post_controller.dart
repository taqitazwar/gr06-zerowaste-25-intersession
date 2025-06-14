import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:math';
import '../models/food_post_model.dart';
import '../models/user_model.dart';
import 'user_controller.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

// Data class for nearby posts computation
class NearbyPostsData {
  final List<FoodPostModel> posts;
  final double latitude;
  final double longitude;
  final double radiusInKm;

  NearbyPostsData({
    required this.posts,
    required this.latitude,
    required this.longitude,
    required this.radiusInKm,
  });
}

// Helper function for filtering and sorting nearby posts
List<FoodPostModel> _filterAndSortNearbyPosts(NearbyPostsData data) {
  final filteredPosts = data.posts.where((post) {
    final distance = Geolocator.distanceBetween(
          data.latitude,
          data.longitude,
          post.pickupLocation.latitude,
          post.pickupLocation.longitude,
        ) /
        1000; // Convert to km

    return distance <= data.radiusInKm;
  }).toList();

  // Sort by distance
  filteredPosts.sort((a, b) {
    final distanceA = Geolocator.distanceBetween(
      data.latitude,
      data.longitude,
      a.pickupLocation.latitude,
      a.pickupLocation.longitude,
    );
    final distanceB = Geolocator.distanceBetween(
      data.latitude,
      data.longitude,
      b.pickupLocation.latitude,
      b.pickupLocation.longitude,
    );
    return distanceA.compareTo(distanceB);
  });

  return filteredPosts;
}

class FoodPostController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _postsCollection = 'food_posts';
  static const String _imageFolder = 'food_images';

  // Create a new food post
  static Future<FoodPostModel> createFoodPost({
    required FoodPostModel foodPost,
    required List<File> imageFiles,
  }) async {
    try {
      // Upload images first
      List<String> imageUrls = [];
      for (int i = 0; i < imageFiles.length; i++) {
        final imageUrl = await _uploadImage(imageFiles[i], foodPost.donorId, i);
        imageUrls.add(imageUrl);
      }

      // Create the post with image URLs
      final postWithImages = foodPost.copyWith(imageUrls: imageUrls);

      // Save to Firestore
      final docRef = await _firestore
          .collection(_postsCollection)
          .add(postWithImages.toFirestore());

      // Update the post with the generated ID
      final finalPost = postWithImages.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});

      // Increment user's post count
      await UserController.incrementUserStats(
        foodPost.donorId,
        isPost: true,
      );

      return finalPost;
    } catch (e) {
      throw Exception('Failed to create food post: $e');
    }
  }

  // Upload image to Firebase Storage
  static Future<String> _uploadImage(
      File imageFile, String userId, int index) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_${timestamp}_$index.jpg';

      final ref = _storage.ref().child('$_imageFolder/$fileName');
      final uploadTask = ref.putFile(imageFile);

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get nearby food posts based on location
  static Future<List<FoodPostModel>> getNearbyFoodPosts({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
    int limit = 50,
  }) async {
    try {
      // Calculate bounding box for the search area
      final bounds = _calculateBounds(latitude, longitude, radiusInKm);

      final query = await _firestore
          .collection(_postsCollection)
          .where('status', isEqualTo: FoodPostStatus.available.name)
          .where('expiryTime',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .where('pickupLocation.latitude',
              isGreaterThanOrEqualTo: bounds['minLat'])
          .where('pickupLocation.latitude',
              isLessThanOrEqualTo: bounds['maxLat'])
          .orderBy('pickupLocation.latitude')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final posts =
          query.docs.map((doc) => FoodPostModel.fromFirestore(doc)).toList();

      // Use compute to filter and sort posts in a separate isolate
      return await compute(
        _filterAndSortNearbyPosts,
        NearbyPostsData(
          posts: posts,
          latitude: latitude,
          longitude: longitude,
          radiusInKm: radiusInKm,
        ),
      );
    } catch (e) {
      throw Exception('Failed to get nearby food posts: $e');
    }
  }

  // Calculate bounding box for location search
  static Map<String, double> _calculateBounds(
      double lat, double lng, double radiusKm) {
    const double earthRadiusKm = 6371.0;

    final double latDelta = (radiusKm / earthRadiusKm) * (180 / pi);
    final double lngDelta =
        (radiusKm / earthRadiusKm) * (180 / pi) / cos(pi / 180 * lat);

    return {
      'minLat': lat - latDelta,
      'maxLat': lat + latDelta,
      'minLng': lng - lngDelta,
      'maxLng': lng + lngDelta,
    };
  }

  // Get food posts by user
  static Future<List<FoodPostModel>> getUserFoodPosts(String userId) async {
    try {
      final query = await _firestore
          .collection(_postsCollection)
          .where('donorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => FoodPostModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get user food posts: $e');
    }
  }

  // Get food post by ID
  static Future<FoodPostModel?> getFoodPost(String postId) async {
    try {
      final doc =
          await _firestore.collection(_postsCollection).doc(postId).get();

      if (doc.exists) {
        return FoodPostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get food post: $e');
    }
  }

  // Update food post status
  static Future<void> updateFoodPostStatus({
    required String postId,
    required FoodPostStatus status,
    String? claimedBy,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (status == FoodPostStatus.claimed && claimedBy != null) {
        updates['claimedBy'] = claimedBy;
        updates['claimedAt'] = Timestamp.fromDate(DateTime.now());

        // Increment claimer's claim count
        await UserController.incrementUserStats(claimedBy, isClaim: true);
      }

      await _firestore.collection(_postsCollection).doc(postId).update(updates);
    } catch (e) {
      throw Exception('Failed to update food post status: $e');
    }
  }

  // Delete food post
  static Future<void> deleteFoodPost(String postId) async {
    try {
      final post = await getFoodPost(postId);
      if (post == null) return;

      // Delete images from storage
      for (String imageUrl in post.imageUrls) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Warning: Could not delete image: $e');
        }
      }

      // Delete post document
      await _firestore.collection(_postsCollection).doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete food post: $e');
    }
  }

  // Search food posts by title/description
  static Future<List<FoodPostModel>> searchFoodPosts({
    required String query,
    double? latitude,
    double? longitude,
    double radiusInKm = 50.0,
  }) async {
    try {
      // Get all available posts first
      final firestoreQuery = await _firestore
          .collection(_postsCollection)
          .where('status', isEqualTo: FoodPostStatus.available.name)
          .where('expiryTime',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiryTime')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      List<FoodPostModel> posts = firestoreQuery.docs
          .map((doc) => FoodPostModel.fromFirestore(doc))
          .toList();

      // Filter by search query
      final searchTerms = query.toLowerCase().split(' ');
      posts = posts.where((post) {
        final title = post.title.toLowerCase();
        final description = post.description.toLowerCase();

        return searchTerms
            .any((term) => title.contains(term) || description.contains(term));
      }).toList();

      // Filter by location if provided
      if (latitude != null && longitude != null) {
        posts = posts.where((post) {
          final distance = Geolocator.distanceBetween(
                latitude,
                longitude,
                post.pickupLocation.latitude,
                post.pickupLocation.longitude,
              ) /
              1000; // Convert to km

          return distance <= radiusInKm;
        }).toList();

        // Sort by distance
        posts.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            latitude,
            longitude,
            a.pickupLocation.latitude,
            a.pickupLocation.longitude,
          );
          final distanceB = Geolocator.distanceBetween(
            latitude,
            longitude,
            b.pickupLocation.latitude,
            b.pickupLocation.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      return posts;
    } catch (e) {
      throw Exception('Failed to search food posts: $e');
    }
  }

  // Get food posts by dietary tags
  static Future<List<FoodPostModel>> getFoodPostsByTags({
    required Set<DietaryTag> tags,
    double? latitude,
    double? longitude,
    double radiusInKm = 50.0,
  }) async {
    try {
      if (tags.isEmpty) {
        if (latitude != null && longitude != null) {
          return getNearbyFoodPosts(
            latitude: latitude,
            longitude: longitude,
            radiusInKm: radiusInKm,
          );
        }
        return [];
      }

      // Convert tags to strings for Firestore query
      final tagNames = tags.map((tag) => tag.name).toList();

      final query = await _firestore
          .collection(_postsCollection)
          .where('status', isEqualTo: FoodPostStatus.available.name)
          .where('expiryTime',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .where('dietaryTags', arrayContainsAny: tagNames)
          .orderBy('expiryTime')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      List<FoodPostModel> posts =
          query.docs.map((doc) => FoodPostModel.fromFirestore(doc)).toList();

      // Filter by location if provided
      if (latitude != null && longitude != null) {
        posts = posts.where((post) {
          final distance = Geolocator.distanceBetween(
                latitude,
                longitude,
                post.pickupLocation.latitude,
                post.pickupLocation.longitude,
              ) /
              1000; // Convert to km

          return distance <= radiusInKm;
        }).toList();

        // Sort by distance
        posts.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            latitude,
            longitude,
            a.pickupLocation.latitude,
            a.pickupLocation.longitude,
          );
          final distanceB = Geolocator.distanceBetween(
            latitude,
            longitude,
            b.pickupLocation.latitude,
            b.pickupLocation.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      return posts;
    } catch (e) {
      throw Exception('Failed to get food posts by tags: $e');
    }
  }

  // Update food post
  static Future<void> updateFoodPost({
    required String postId,
    String? title,
    String? description,
    Set<DietaryTag>? dietaryTags,
    DateTime? expiryTime,
    String? pickupInstructions,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dietaryTags != null) {
        updates['dietaryTags'] = dietaryTags.map((tag) => tag.name).toList();
      }
      if (expiryTime != null)
        updates['expiryTime'] = Timestamp.fromDate(expiryTime);
      if (pickupInstructions != null)
        updates['pickupInstructions'] = pickupInstructions;

      await _firestore.collection(_postsCollection).doc(postId).update(updates);
    } catch (e) {
      throw Exception('Failed to update food post: $e');
    }
  }

  // Get claimed food posts for a user
  static Future<List<FoodPostModel>> getClaimedFoodPosts(String userId) async {
    try {
      final query = await _firestore
          .collection(_postsCollection)
          .where('claimedBy', isEqualTo: userId)
          .orderBy('claimedAt', descending: true)
          .get();

      return query.docs.map((doc) => FoodPostModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get claimed food posts: $e');
    }
  }
}
