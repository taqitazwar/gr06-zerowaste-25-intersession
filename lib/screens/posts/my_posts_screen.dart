import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../models/claim_model.dart';
import '../../services/claim_service.dart';
import '../../services/rating_service.dart';
import '../post/add_post_screen.dart';
import '../post/edit_post_screen.dart';
import '../post/post_details_screen.dart';
import '../chat/chat_screen.dart';
import '../rating/rate_user_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({Key? key}) : super(key: key);

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('postedBy', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final List<PostModel> posts = snapshot.docs
          .map((doc) => PostModel.fromDocument(doc))
          .toList();

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching posts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleClaimAction(PostModel post, bool accept) async {
    if (post.activeClaim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active claim found'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      if (accept) {
        await ClaimService.acceptClaim(claimId: post.activeClaim!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim accepted! Food marked as completed.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        await ClaimService.rejectClaim(claimId: post.activeClaim!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim rejected. Post is now available again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Add a small delay to ensure Firestore updates are propagated
      await Future.delayed(const Duration(milliseconds: 500));
      _fetchMyPosts(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update claim: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePost(PostModel post) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: Text(
          'Are you sure you want to delete "${post.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('posts').doc(post.postId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: AppColors.primary,
        ),
      );

      _fetchMyPosts(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _startChatWithClaimer(PostModel post) async {
    try {
      // Get the active claim for this post
      final claim = await ClaimService.getActiveClaimForPost(post.postId);
      if (claim == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active claim found for this post'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Create a unique chat ID
      final List<String> participants = [post.postedBy, claim.claimerId]
        ..sort();
      final chatId = '${post.postId}_${participants.join('_')}';

      // Create or get chat document
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        // Create new chat
        await chatRef.set({
          'participants': participants,
          'postId': post.postId,
          'postTitle': post.title,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
          'messages': [],
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              postTitle: post.title,
              otherUserId: claim.claimerId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _rateUser(ClaimModel claim, PostModel post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateUserScreen(
          claimId: claim.claimId,
          postId: post.postId,
          toUserId: claim.claimerId,
          postTitle: post.title,
          userRole: 'creator', // Current user is the creator
        ),
      ),
    );

    if (result == true) {
      // Rating was submitted, refresh the screen
      _fetchMyPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMyPosts),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchMyPosts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_food, color: AppColors.secondary, size: 80),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start sharing food with your community!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyPosts,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _posts.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final bool isPending = post.status == PostStatus.pending;
    final bool isCompleted = post.status == PostStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (post.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                post.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(post),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(post),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(post),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),

                const SizedBox(height: 16),

                // Date and Location
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(post.timestamp),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),

                // Claim Management Buttons
                if (isPending) ...[
                  const SizedBox(height: 16),
                  // Show claimer info with rating
                  FutureBuilder<ClaimModel?>(
                    future: ClaimService.getActiveClaimForPost(post.postId),
                    builder: (context, claimSnapshot) {
                      if (!claimSnapshot.hasData ||
                          claimSnapshot.data == null) {
                        return const SizedBox.shrink();
                      }

                      final claim = claimSnapshot.data!;
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('users')
                            .doc(claim.claimerId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          final claimerName =
                              userData['name'] ?? 'Unknown User';
                          final claimerRating = (userData['rating'] ?? 0.0)
                              .toDouble();
                          final totalRatings = userData['totalRatings'] ?? 0;
                          final ratingDisplay = totalRatings == 0
                              ? 'No ratings yet'
                              : '${claimerRating.toStringAsFixed(1)} ⭐ ($totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'})';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Claimer info card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Claimed by:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      claimerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          ratingDisplay,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Claimed on: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(claim.timestamp)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Message button (full width)
                              ElevatedButton.icon(
                                onPressed: () => _startChatWithClaimer(post),
                                icon: const Icon(
                                  Icons.message_outlined,
                                  size: 18,
                                ),
                                label: const Text('Message Claimer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Accept/Reject buttons (side by side)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _handleClaimAction(post, false),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _handleClaimAction(post, true),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ] else if (isCompleted) ...[
                  const SizedBox(height: 16),
                  // For completed posts, find the accepted claim for this post
                  FutureBuilder<ClaimModel?>(
                    future: _getAcceptedClaimForPost(post.postId),
                    builder: (context, claimSnapshot) {
                      if (!claimSnapshot.hasData ||
                          claimSnapshot.data == null) {
                        return const SizedBox.shrink();
                      }

                      final claim = claimSnapshot.data!;
                      return FutureBuilder<bool>(
                        future: RatingService.hasRatedUser(
                          claimId: claim.claimId,
                          toUserId: claim.claimerId,
                        ),
                        builder: (context, ratingSnapshot) {
                          final hasRated = ratingSnapshot.data ?? false;

                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailsScreen(
                                          initialPost: post,
                                          isOwnPost: true,
                                        ),
                                      ),
                                    ).then((value) {
                                      if (value == true) {
                                        _fetchMyPosts();
                                      }
                                    });
                                  },
                                  child: const Text('View Details'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: hasRated
                                    ? OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.star, size: 18),
                                        label: const Text('Rated'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () => _rateUser(claim, post),
                                        icon: const Icon(
                                          Icons.star_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Rate Claimer'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],

                // View Details Button (for available posts)
                if (!isPending && !isCompleted) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailsScreen(
                              initialPost: post,
                              isOwnPost: true,
                            ),
                          ),
                        ).then((value) {
                          if (value == true) {
                            _fetchMyPosts();
                          }
                        });
                      },
                      child: const Text('View Details'),
                    ),
                  ),
                ],

                // Delete Button (appears for all posts)
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deletePost(post),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Post'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PostModel post) {
    if (post.isExpired) return Colors.red;
    switch (post.status) {
      case PostStatus.available:
        return AppColors.primary;
      case PostStatus.pending:
        return Colors.orange;
      case PostStatus.completed:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(PostModel post) {
    if (post.isExpired) return Icons.timer_off;
    switch (post.status) {
      case PostStatus.available:
        return Icons.check_circle;
      case PostStatus.pending:
        return Icons.handshake;
      case PostStatus.completed:
        return Icons.task_alt;
    }
  }

  String _getStatusText(PostModel post) {
    if (post.isExpired) return 'Expired';
    switch (post.status) {
      case PostStatus.available:
        return 'Available';
      case PostStatus.pending:
        return 'Claim Pending';
      case PostStatus.completed:
        return 'Completed';
    }
  }

  Future<ClaimModel?> _getAcceptedClaimForPost(String postId) async {
    final snapshot = await _firestore
        .collection('claims')
        .where('postId', isEqualTo: postId)
        .where('status', isEqualTo: ClaimStatus.accepted.name)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return ClaimModel.fromDocument(snapshot.docs.first);
    }
    return null;
  }
}
