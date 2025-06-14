import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/user_controller.dart';
import 'edit_post_screen.dart';
import 'report_dialog.dart';
import 'report_list_dialog.dart';

class PostDetailsScreen extends StatelessWidget {
  final PostModel post;

  const PostDetailsScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(post.timestamp);
    final formattedTime = DateFormat('h:mm a').format(post.timestamp);
    final formattedExpiry = DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(post.expiry);
    final isExpired = post.isExpired;
    final isAvailable = post.status == PostStatus.available && !isExpired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          StreamBuilder<bool>(
            stream: Stream.fromFuture(_checkIfOwnPost()),
            builder: (context, snapshot) {
              final isOwnPost = snapshot.data ?? false;
              return Row(
                children: [
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
                  if (!isOwnPost)
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ReportDialog(postId: post.postId),
                        );
                      },
                      icon: const Icon(Icons.flag_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 48,
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
                  // Title and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(post.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(post.status)),
                        ),
                        child: Text(
                          _getStatusText(post.status),
                          style: TextStyle(
                            color: _getStatusColor(post.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    post.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Dietary tags
                  if (post.dietaryTags.isNotEmpty) ...[
                    const Text(
                      'Dietary Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.dietaryTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            _getDietaryTagDisplayName(tag),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Expiry date
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expires ${DateFormat('MMM d, y').format(post.expiry)}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.address,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(PostStatus status) {
    if (status == PostStatus.expired) {
      return Colors.red;
    } else if (status == PostStatus.available) {
      return AppColors.primary;
    } else if (status == PostStatus.claimed) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String _getStatusText(PostStatus status) {
    if (status == PostStatus.expired) {
      return 'Expired';
    } else if (status == PostStatus.available) {
      return 'Available';
    } else if (status == PostStatus.claimed) {
      return 'Claimed';
    } else {
      return 'Inactive';
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

  Future<bool> _checkIfOwnPost() async {
    final currentUser = await UserController.getCurrentUser();
    return currentUser?.uid == post.postedBy;
  }
} 