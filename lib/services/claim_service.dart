import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/claim_model.dart';
import '../models/post_model.dart';

class ClaimService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new claim for a food post
  static Future<String> createClaim({
    required String postId,
    required String creatorId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to claim food');
    }

    if (user.uid == creatorId) {
      throw Exception('You cannot claim your own post');
    }

    // Check if post is still available
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Post not found');
    }

    final post = PostModel.fromDocument(postDoc);
    if (post.status != PostStatus.available) {
      throw Exception('This food is no longer available');
    }

    if (post.isExpired) {
      throw Exception('This food has expired');
    }

    // Check if user already has a pending claim for this post
    final existingClaim = await _firestore
        .collection('claims')
        .where('postId', isEqualTo: postId)
        .where('claimerId', isEqualTo: user.uid)
        .where('status', isEqualTo: ClaimStatus.pending.name)
        .get();

    if (existingClaim.docs.isNotEmpty) {
      throw Exception('You already have a pending claim for this post');
    }

    // Create the claim
    final claimData = ClaimModel(
      claimId: '', // Will be set by Firestore
      postId: postId,
      claimerId: user.uid,
      creatorId: creatorId,
      timestamp: DateTime.now(),
    );

    final claimRef = await _firestore.collection('claims').add(claimData.toMap());

    // Update post status to pending and set active claim
    await _firestore.collection('posts').doc(postId).update({
      'status': PostStatus.pending.name,
      'activeClaim': claimRef.id,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update user's claim count
    await _firestore.collection('users').doc(user.uid).update({
      'totalClaims': FieldValue.increment(1),
      'lastActive': Timestamp.fromDate(DateTime.now()),
    });

    return claimRef.id;
  }

  /// Accept a claim (by post creator)
  static Future<void> acceptClaim({
    required String claimId,
    String? responseMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to accept claims');
    }

    // Get the claim
    final claimDoc = await _firestore.collection('claims').doc(claimId).get();
    if (!claimDoc.exists) {
      throw Exception('Claim not found');
    }

    final claim = ClaimModel.fromDocument(claimDoc);
    
    // Verify user is the creator
    if (claim.creatorId != user.uid) {
      throw Exception('You can only accept claims for your own posts');
    }

    if (claim.status != ClaimStatus.pending) {
      throw Exception('This claim has already been processed');
    }

    // Update claim status
    await _firestore.collection('claims').doc(claimId).update({
      'status': ClaimStatus.accepted.name,
      'responseTimestamp': Timestamp.fromDate(DateTime.now()),
      'responseMessage': responseMessage,
    });

    // Update post status to completed
    await _firestore.collection('posts').doc(claim.postId).update({
      'status': PostStatus.completed.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reject a claim (by post creator)
  static Future<void> rejectClaim({
    required String claimId,
    String? responseMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to reject claims');
    }

    // Get the claim
    final claimDoc = await _firestore.collection('claims').doc(claimId).get();
    if (!claimDoc.exists) {
      throw Exception('Claim not found');
    }

    final claim = ClaimModel.fromDocument(claimDoc);
    
    // Verify user is the creator
    if (claim.creatorId != user.uid) {
      throw Exception('You can only reject claims for your own posts');
    }

    if (claim.status != ClaimStatus.pending) {
      throw Exception('This claim has already been processed');
    }

    // Update claim status
    await _firestore.collection('claims').doc(claimId).update({
      'status': ClaimStatus.rejected.name,
      'responseTimestamp': Timestamp.fromDate(DateTime.now()),
      'responseMessage': responseMessage,
    });

    // Update post status back to available and remove active claim
    await _firestore.collection('posts').doc(claim.postId).update({
      'status': PostStatus.available.name,
      'activeClaim': null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get claims for a specific post (for post creator)
  static Future<List<ClaimModel>> getClaimsForPost(String postId) async {
    final snapshot = await _firestore
        .collection('claims')
        .where('postId', isEqualTo: postId)
        .get();

    final claims = snapshot.docs.map((doc) => ClaimModel.fromDocument(doc)).toList();
    
    // Sort in memory to avoid potential index requirement
    claims.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return claims;
  }

  /// Get claims made by current user
  static Future<List<ClaimModel>> getMyClaimsWithPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view claims');
    }

    final snapshot = await _firestore
        .collection('claims')
        .where('claimerId', isEqualTo: user.uid)
        .get();

    final claims = snapshot.docs.map((doc) => ClaimModel.fromDocument(doc)).toList();
    
    // Sort in memory to avoid potential index requirement
    claims.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return claims;
  }

  /// Get pending claims for posts created by current user
  static Future<List<ClaimModel>> getPendingClaimsForMyPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view claims');
    }

    final snapshot = await _firestore
        .collection('claims')
        .where('creatorId', isEqualTo: user.uid)
        .where('status', isEqualTo: ClaimStatus.pending.name)
        .get();

    final claims = snapshot.docs.map((doc) => ClaimModel.fromDocument(doc)).toList();
    
    // Sort in memory to avoid composite index requirement
    claims.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return claims;
  }

  /// Get the active claim for a specific post
  static Future<ClaimModel?> getActiveClaimForPost(String postId) async {
    final snapshot = await _firestore
        .collection('claims')
        .where('postId', isEqualTo: postId)
        .where('status', isEqualTo: ClaimStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return ClaimModel.fromDocument(snapshot.docs.first);
  }

  /// Cancel a claim (by claimer, only if pending)
  static Future<void> cancelClaim(String claimId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to cancel claims');
    }

    // Get the claim
    final claimDoc = await _firestore.collection('claims').doc(claimId).get();
    if (!claimDoc.exists) {
      throw Exception('Claim not found');
    }

    final claim = ClaimModel.fromDocument(claimDoc);
    
    // Verify user is the claimer
    if (claim.claimerId != user.uid) {
      throw Exception('You can only cancel your own claims');
    }

    if (claim.status != ClaimStatus.pending) {
      throw Exception('You can only cancel pending claims');
    }

    // Delete the claim
    await _firestore.collection('claims').doc(claimId).delete();

    // Update post status back to available and remove active claim
    await _firestore.collection('posts').doc(claim.postId).update({
      'status': PostStatus.available.name,
      'activeClaim': null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Decrement user's claim count
    await _firestore.collection('users').doc(user.uid).update({
      'totalClaims': FieldValue.increment(-1),
      'lastActive': Timestamp.fromDate(DateTime.now()),
    });
  }
} 