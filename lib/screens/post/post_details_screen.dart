import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import 'edit_post_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailsScreen extends StatelessWidget {
  final PostModel post;
  final bool isOwnPost;

  const PostDetailsScreen({
    super.key,
    required this.post,
    this.isOwnPost = false,
  });

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
              if (isOwnPost)
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
                      if (isOwnPost) ...[
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

                  // Action Buttons
                  if (!isOwnPost && isAvailable) ...[
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
                  ] else if (isOwnPost &&
                      post.status == PostStatus.claimed) ...[
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

  IconData _getStatusIcon() {
    if (post.isExpired) {
      return Icons.timer_off;
    }
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

  String _getStatusText() {
    if (post.isExpired) {
      return 'Expired';
    }
    switch (post.status) {
      case PostStatus.available:
        return 'Available';
      case PostStatus.claimed:
        return 'Claimed';
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
          'Are you sure you want to claim this food? The poster will be notified and you can arrange pickup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  throw Exception('You must be logged in to claim food');
                }

                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.postId)
                    .update({
                      'status': PostStatus.claimed.name,
                      'claimedBy': user.uid,
                      'updatedAt': Timestamp.fromDate(DateTime.now()),
                    });

                // Increment user's claim count
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                      'totalClaims': FieldValue.increment(1),
                      'lastActive': Timestamp.fromDate(DateTime.now()),
                    });

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to previous screen with refresh flag
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Food claimed successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
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

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Poster'),
        content: const Text(
          'Messaging functionality will be available soon. For now, you can claim the food to get contact information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClaimManagementDialog(BuildContext context) async {
    final claimerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(post.claimedBy)
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
              'Claimed on: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(post.updatedAt ?? post.timestamp)}',
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
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.postId)
                    .update({
                      'status': PostStatus.rejected.name,
                      'updatedAt': Timestamp.fromDate(DateTime.now()),
                    });

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to previous screen with refresh flag
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Claim rejected successfully'),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject Claim'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.postId)
                    .update({
                      'status': PostStatus.completed.name,
                      'updatedAt': Timestamp.fromDate(DateTime.now()),
                    });

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to previous screen with refresh flag
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Claim completed successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to complete claim: ${e.toString()}',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Complete Handover'),
          ),
        ],
      ),
    );
  }
}
