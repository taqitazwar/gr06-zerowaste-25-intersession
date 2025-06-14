import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';

class UserController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _usersCollection = 'users';

  // Create user profile when they first sign up
  static Future<UserModel?> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String? profileImageUrl,
    GeoPoint? location,
    String fcmToken = '',
  }) async {
    try {
      final newUser = UserModel(
        uid: uid,
        name: name,
        email: email,
        profileImageUrl: profileImageUrl,
        location: location ?? const GeoPoint(0, 0),
        fcmToken: fcmToken,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(newUser.toMap());

      return newUser;
    } catch (e) {
      print('Error creating user profile: $e');
      return null;
    }
  }

  // Get user profile
  static Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? profileImageUrl,
    GeoPoint? location,
    String? fcmToken,
    bool removeProfileImage = false,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
      if (removeProfileImage) updates['profileImageUrl'] = null;
      if (location != null) updates['location'] = location;
      if (fcmToken != null) updates['fcmToken'] = fcmToken;

      await _firestore.collection(_usersCollection).doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update user's last active time
  static Future<void> updateLastActive(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({'lastActive': Timestamp.fromDate(DateTime.now())});
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  // Ensure user profile exists (create if it doesn't)
  static Future<UserModel?> ensureUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    // First, try to get existing profile
    UserModel? userProfile = await getUserProfile(currentUser.uid);

    // If profile doesn't exist, create it
    if (userProfile == null) {
      userProfile = await createUserProfile(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        name: currentUser.displayName ?? 'User',
      );
    } else {
      // Update last active time
      await updateLastActive(currentUser.uid);
    }

    return userProfile;
  }

  // Update user location
  static Future<bool> updateUserLocation(String uid, GeoPoint location) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'location': location,
      });
      return true;
    } catch (e) {
      print('Error updating user location: $e');
      return false;
    }
  }

  // Increment user stats
  static Future<void> incrementUserStats(String uid, {bool isPost = false, bool isClaim = false}) async {
    try {
      final increment = FieldValue.increment(1);
      Map<String, dynamic> updates = {};

      if (isPost) {
        updates['totalPosts'] = increment;
      }
      if (isClaim) {
        updates['totalClaims'] = increment;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update(updates);
    } catch (e) {
      print('Error incrementing user stats: $e');
    }
  }

  // Upload profile picture to Firebase Storage
  static Future<String> uploadProfilePicture({
    required String uid,
    required File imageFile,
  }) async {
    try {
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$uid$timestamp.jpg';
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child('profile_pictures/$fileName');
      final uploadTask = ref.putFile(imageFile);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new image URL
      await updateUserProfile(
        uid: uid,
        profileImageUrl: downloadUrl,
      );
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Delete old profile picture from Storage
  static Future<void> deleteProfilePicture(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Ignore errors when deleting old images
      print('Warning: Could not delete old profile picture: $e');
    }
  }

  static Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromDocument(doc);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
} 