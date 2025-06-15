import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../post/post_details_screen.dart';
import '../chat/chat_screen.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({Key? key}) : super(key: key);

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<PostModel> _claims = [];
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('claimedBy', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .get();

      final List<PostModel> claims = snapshot.docs
          .map((doc) => PostModel.fromDocument(doc))
          .toList();

      setState(() {
        _claims = claims;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching claims: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(PostModel post) async {
    try {
      // Create a unique chat ID using post ID and user IDs
      final chatId = '${post.postId}_${post.postedBy}_${post.claimedBy}';

      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Create new chat
        await _firestore.collection('chats').doc(chatId).set({
          'postId': post.postId,
          'postTitle': post.title,
          'participants': [post.postedBy, post.claimedBy],
          'lastMessage': null,
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });
      }

      if (mounted) {
        // Navigate to chat screen (you'll need to create this)
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
          return _buildClaimCard(claim);
        },
      ),
    );
  }

  Widget _buildClaimCard(PostModel claim) {
    final bool isPending = claim.status == PostStatus.claimed;
    final bool isCompleted = claim.status == PostStatus.completed;
    final bool isRejected = claim.status == PostStatus.rejected;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (claim.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                claim.imageUrl,
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
                        color: _getStatusColor(claim),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(claim),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(claim),
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
                  claim.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  claim.description,
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
                      'Claimed: ${DateFormat('MMM d, yyyy').format(claim.updatedAt ?? claim.timestamp)}',
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
                        claim.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),

                // Status message
                if (isCompleted || isRejected) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green[200]!
                            : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.cancel,
                          color: isCompleted ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isCompleted
                                ? 'Claim was accepted and completed'
                                : 'Claim was rejected by the donor',
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsScreen(
                                post: claim,
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
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startChat(claim),
                          icon: const Icon(Icons.message_outlined),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
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

  Color _getStatusColor(PostModel post) {
    if (post.isExpired) return Colors.red;
    switch (post.status) {
      case PostStatus.available:
        return AppColors.primary;
      case PostStatus.claimed:
        return Colors.orange;
      case PostStatus.completed:
        return Colors.green;
      case PostStatus.rejected:
        return Colors.red;
      case PostStatus.cancelled:
        return Colors.grey;
      case PostStatus.expired:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(PostModel post) {
    if (post.isExpired) return Icons.timer_off;
    switch (post.status) {
      case PostStatus.available:
        return Icons.check_circle;
      case PostStatus.claimed:
        return Icons.handshake;
      case PostStatus.completed:
        return Icons.task_alt;
      case PostStatus.rejected:
        return Icons.cancel;
      case PostStatus.cancelled:
        return Icons.block;
      case PostStatus.expired:
        return Icons.timer_off;
    }
  }

  String _getStatusText(PostModel post) {
    if (post.isExpired) return 'Expired';
    switch (post.status) {
      case PostStatus.available:
        return 'Available';
      case PostStatus.claimed:
        return 'Pending';
      case PostStatus.completed:
        return 'Completed';
      case PostStatus.rejected:
        return 'Rejected';
      case PostStatus.cancelled:
        return 'Cancelled';
      case PostStatus.expired:
        return 'Expired';
    }
  }
}
