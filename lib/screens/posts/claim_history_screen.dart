import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../models/claim_model.dart';
import '../../services/claim_service.dart';
import '../post/post_details_screen.dart';
import '../chat/chat_screen.dart';

class ClaimHistoryScreen extends StatefulWidget {
  const ClaimHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ClaimHistoryScreen> createState() => _ClaimHistoryScreenState();
}

class _ClaimHistoryScreenState extends State<ClaimHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ClaimModel> _claims = [];
  Map<String, PostModel> _posts = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'accepted', 'rejected'

  @override
  void initState() {
    super.initState();
    _fetchClaims();
  }

  Future<void> _fetchClaims() async {
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
        final postDoc = await _firestore.collection('posts').doc(claim.postId).get();
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

  List<ClaimModel> get _filteredClaims {
    switch (_selectedFilter) {
      case 'pending':
        return _claims.where((claim) => claim.status == ClaimStatus.pending).toList();
      case 'accepted':
        return _claims.where((claim) => claim.status == ClaimStatus.accepted).toList();
      case 'rejected':
        return _claims.where((claim) => claim.status == ClaimStatus.rejected).toList();
      default:
        return _claims;
    }
  }

  void _startChat(ClaimModel claim) async {
    try {
      final post = _posts[claim.postId];
      if (post == null) return;

      // Create a unique chat ID
      final List<String> participants = [post.postedBy, claim.claimerId]..sort();
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
        title: const Text('Claim History'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchClaims),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Accepted', 'accepted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
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
              onPressed: _fetchClaims,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final filteredClaims = _filteredClaims;

    if (filteredClaims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.history,
              color: AppColors.secondary,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all' ? 'No claims yet' : 'No ${_selectedFilter} claims',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your claim history will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchClaims,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: filteredClaims.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final claim = filteredClaims[index];
          final post = _posts[claim.postId];
          if (post == null) return const SizedBox.shrink();
          return _buildClaimCard(claim, post);
        },
      ),
    );
  }

  Widget _buildClaimCard(ClaimModel claim, PostModel post) {
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

                // Claim Date
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

                if (claim.responseTimestamp != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        claim.status == ClaimStatus.accepted 
                            ? Icons.check_circle 
                            : Icons.cancel,
                        size: 16, 
                        color: claim.status == ClaimStatus.accepted 
                            ? Colors.green 
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${claim.status == ClaimStatus.accepted ? 'Accepted' : 'Rejected'}: ${DateFormat('MMM d, yyyy').format(claim.responseTimestamp!)}',
                        style: TextStyle(
                          color: claim.status == ClaimStatus.accepted 
                              ? Colors.green[700] 
                              : Colors.red[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsScreen(
                                initialPost: post,
                                isOwnPost: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View Details'),
                      ),
                    ),
                    if (claim.status == ClaimStatus.pending) ...[
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
                    ] else if (claim.status == ClaimStatus.accepted) ...[
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
