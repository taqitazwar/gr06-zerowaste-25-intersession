import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../models/claim_model.dart';
import '../../services/claim_service.dart';
import '../../services/rating_service.dart';
import '../post/post_details_screen.dart';
import '../chat/chat_screen.dart';
import '../rating/rate_user_screen.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({Key? key}) : super(key: key);

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ClaimModel> _claims = [];
  Map<String, PostModel> _posts = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchMyClaims();
  }

  Future<void> _fetchMyClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get claims made by current user
      final claims = await ClaimService.getMyClaimsWithPosts();

      // Get post details for each claim
      final Map<String, PostModel> posts = {};
      for (final claim in claims) {
        final postDoc = await _firestore
            .collection('posts')
            .doc(claim.postId)
            .get();
        if (postDoc.exists) {
          posts[claim.postId] = PostModel.fromDocument(postDoc);
        }
      }

      setState(() {
        _claims = claims;
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching claims: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelClaim(ClaimModel claim) async {
    try {
      await ClaimService.cancelClaim(claim.claimId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim cancelled successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
      _fetchMyClaims(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel claim: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startChat(ClaimModel claim) async {
    try {
      final post = _posts[claim.postId];
      if (post == null) return;

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

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              postTitle: post.title,
              otherUserId: post.postedBy,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Claims'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyClaims,
          ),
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
              onPressed: _fetchMyClaims,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.handshake_outlined,
              color: AppColors.secondary,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'No claims yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start claiming food to help reduce waste!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyClaims,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _claims.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final claim = _claims[index];
          final post = _posts[claim.postId];
          if (post == null) return const SizedBox.shrink();
          return _buildClaimCard(claim, post);
        },
      ),
    );
  }

  Widget _buildClaimCard(ClaimModel claim, PostModel post) {
    final bool isPending = claim.status == ClaimStatus.pending;
    final bool isAccepted = claim.status == ClaimStatus.accepted;
    final bool isRejected = claim.status == ClaimStatus.rejected;

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
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
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
                        color: _getClaimStatusColor(claim.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getClaimStatusIcon(claim.status),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getClaimStatusText(claim.status),
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

                // Claim Date and Location
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Claimed: ${DateFormat('MMM d, yyyy').format(claim.timestamp)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
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

                const SizedBox(height: 16),

                // Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // View Details Button (always present)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailsScreen(
                              initialPost: post,
                              isOwnPost: false,
                            ),
                          ),
                        ).then((value) {
                          if (value == true) {
                            _fetchMyClaims();
                          }
                        });
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    // Status-specific buttons
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startChat(claim),
                              icon: const Icon(Icons.message_outlined),
                              label: const Text('Message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _cancelClaim(claim),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isAccepted) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startChat(claim),
                              icon: const Icon(Icons.message_outlined),
                              label: const Text('Message Creator'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<bool>(
                              future: RatingService.hasRatedUser(
                                claimId: claim.claimId,
                                toUserId: post.postedBy,
                              ),
                              builder: (context, snapshot) {
                                final hasRated = snapshot.data ?? false;

                                if (hasRated) {
                                  return OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.star, size: 18),
                                    label: const Text('Rated'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  );
                                }

                                return ElevatedButton.icon(
                                  onPressed: () => _rateUser(claim, post),
                                  icon: const Icon(
                                    Icons.star_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Rate Creator'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _rateUser(ClaimModel claim, PostModel post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateUserScreen(
          claimId: claim.claimId,
          postId: post.postId,
          toUserId: post.postedBy,
          postTitle: post.title,
          userRole: 'claimer', // Current user is the claimer
        ),
      ),
    );

    if (result == true) {
      // Rating was submitted, refresh the screen
      _fetchMyClaims();
    }
  }

  Color _getClaimStatusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return Colors.orange;
      case ClaimStatus.accepted:
        return Colors.green;
      case ClaimStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getClaimStatusIcon(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return Icons.hourglass_empty;
      case ClaimStatus.accepted:
        return Icons.check_circle;
      case ClaimStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getClaimStatusText(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return 'Pending';
      case ClaimStatus.accepted:
        return 'Accepted';
      case ClaimStatus.rejected:
        return 'Rejected';
    }
  }
}
