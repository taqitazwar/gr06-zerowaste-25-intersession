import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../models/claim_model.dart';
import 'edit_post_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/chat_screen.dart';
import '../../services/claim_service.dart';

class PostDetailsScreen extends StatefulWidget {
  final PostModel initialPost;
  final bool isOwnPost;

  const PostDetailsScreen({
    super.key,
    required this.initialPost,
    this.isOwnPost = false,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late PostModel post;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    post = widget.initialPost;
  }

  Future<void> _refreshPost() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId)
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          post = PostModel.fromDocument(doc);
        });
      }
    } catch (e) {
      // Handle error silently or show a snackbar if needed
      print('Error refreshing post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'EEEE, MMM d, yyyy',
    ).format(post.timestamp);
    final formattedTime = DateFormat('h:mm a').format(post.timestamp);
    final formattedExpiry = DateFormat(
      'EEEE, MMM d, yyyy \'at\' h:mm a',
    ).format(post.expiry);
    final isExpired = post.isExpired;
    final isAvailable = post.status == PostStatus.available && !isExpired;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: post.imageUrl.isNotEmpty
                  ? Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Image not available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant,
                              color: Colors.grey,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No photo available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            actions: [
              if (widget.isOwnPost)
                IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPostScreen(post: post),
                      ),
                    );

                    if (result == true && context.mounted) {
                      Navigator.pop(context, true); // Return to previous screen
                    }
                  },
                  icon: const Icon(Icons.edit),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                  ),
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
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
                          color: _getStatusColor(),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isOwnPost) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: const Text(
                            'Your Post',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Details Cards
                  _buildDetailCard(
                    icon: Icons.location_on,
                    title: 'Pickup Location',
                    content: post.address,
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: 16),

                  _buildDetailCard(
                    icon: Icons.access_time,
                    title: 'Posted',
                    content: '$formattedDate at $formattedTime',
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 16),

                  _buildDetailCard(
                    icon: Icons.schedule,
                    title: 'Available Until',
                    content: formattedExpiry,
                    color: isExpired ? Colors.red : Colors.orange,
                    subtitle: isExpired
                        ? 'This food has expired'
                        : 'Expires in ${_getExpiryText()}',
                  ),

                  if (post.dietaryTags.isNotEmpty &&
                      !post.dietaryTags.contains(DietaryTag.none)) ...[
                    const SizedBox(height: 16),
                    _buildDietaryTagsCard(),
                  ],

                  const SizedBox(height: 32),

                  // Loading indicator
                  if (_isLoading) ...[
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Buttons
                  if (!widget.isOwnPost && isAvailable && !_isLoading) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showClaimDialog(context);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Claim This Food'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showContactDialog(context);
                        },
                        icon: const Icon(Icons.message_outlined),
                        label: const Text('Contact Poster'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else if (!widget.isOwnPost && post.status == PostStatus.pending && !_isLoading) ...[
                    // Pending claim info for non-owners
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                color: Colors.orange[700],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Claim Pending',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Someone has already claimed this food and is waiting for the poster\'s response.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showContactDialog(context);
                        },
                        icon: const Icon(Icons.message_outlined),
                        label: const Text('Contact Poster'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else if (widget.isOwnPost &&
                      post.status == PostStatus.pending && !_isLoading) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showClaimManagementDialog(context),
                        icon: const Icon(Icons.manage_accounts),
                        label: const Text('Manage Claim'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryTagsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Dietary Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.dietaryTags
                .where((tag) => tag != DietaryTag.none)
                .map(
                  (tag) => Chip(
                    label: Text(_getDietaryTagDisplayName(tag)),
                    backgroundColor: AppColors.secondary.withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (post.isExpired) {
      return Colors.red;
    }
    switch (post.status) {
      case PostStatus.available:
        return AppColors.primary;
      case PostStatus.pending:
        return Colors.orange;
      case PostStatus.completed:
        return Colors.green;
    }
  }

  IconData _getStatusIcon() {
    if (post.isExpired) {
      return Icons.timer_off;
    }
    switch (post.status) {
      case PostStatus.available:
        return Icons.check_circle;
      case PostStatus.pending:
        return Icons.handshake;
      case PostStatus.completed:
        return Icons.task_alt;
    }
  }

  String _getStatusText() {
    if (post.isExpired) {
      return 'Expired';
    }
    switch (post.status) {
      case PostStatus.available:
        return 'Available';
      case PostStatus.pending:
        return 'Claim Pending';
      case PostStatus.completed:
        return 'Completed';
    }
  }

  String _getExpiryText() {
    final expiryDate = post.expiry;
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''}';
    }
  }

  String _getDietaryTagDisplayName(DietaryTag tag) {
    switch (tag) {
      case DietaryTag.vegetarian:
        return 'Vegetarian';
      case DietaryTag.vegan:
        return 'Vegan';
      case DietaryTag.glutenFree:
        return 'Gluten-Free';
      case DietaryTag.dairyFree:
        return 'Dairy-Free';
      case DietaryTag.nutFree:
        return 'Nut-Free';
      case DietaryTag.halal:
        return 'Halal';
      case DietaryTag.kosher:
        return 'Kosher';
      case DietaryTag.organic:
        return 'Organic';
      case DietaryTag.spicy:
        return 'Spicy';
      case DietaryTag.none:
        return 'None';
    }
  }

  void _showClaimDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Food'),
        content: const Text(
          'Are you sure you want to claim this food? The poster will be notified and can accept or reject your claim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                setState(() {
                  _isLoading = true;
                });

                await ClaimService.createClaim(
                  postId: post.postId,
                  creatorId: post.postedBy,
                );

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  
                  // Refresh the post data to show updated status
                  await _refreshPost();
                  
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Food claimed successfully! The poster will be notified.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to claim food: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to contact the poster');
      }

      // Create a unique chat ID that will be the same regardless of who initiates
      final List<String> participants = [post.postedBy, user.uid]..sort();
      final chatId = '${post.postId}_${participants.join('_')}';

      // Create or get chat document
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);
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

  void _showClaimManagementDialog(BuildContext context) async {
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
      // Get the claim details
      final claimDoc = await FirebaseFirestore.instance
          .collection('claims')
          .doc(post.activeClaim!)
          .get();

      if (!claimDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Claim not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final claim = ClaimModel.fromDocument(claimDoc);
      
      // Get claimer details
      final claimerSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(claim.claimerId)
          .get();

      final claimerName = claimerSnapshot.data()?['name'] ?? 'Unknown User';

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Manage Claim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Claimed by: $claimerName'),
              const SizedBox(height: 8),
              Text(
                'Claimed on: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(claim.timestamp)}',
              ),
              const SizedBox(height: 16),
              const Text('What would you like to do with this claim?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ClaimService.rejectClaim(claimId: claim.claimId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context, true); // Refresh parent screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claim rejected. Post is now available again.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to reject claim: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ClaimService.acceptClaim(claimId: claim.claimId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context, true); // Refresh parent screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claim accepted! Food marked as completed.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to accept claim: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading claim details: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
