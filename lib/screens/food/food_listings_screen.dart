import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/post_model.dart';
import '../../services/claim_service.dart';
import '../post/add_post_screen.dart';
import '../post/post_details_screen.dart';

class FoodListingsScreen extends StatefulWidget {
  const FoodListingsScreen({Key? key}) : super(key: key);

  @override
  State<FoodListingsScreen> createState() => _FoodListingsScreenState();
}

class _FoodListingsScreenState extends State<FoodListingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<DietaryTag> _selectedDietaryTags = {};

  @override
  void initState() {
    super.initState();
  }

  Stream<List<PostModel>> _getPostsStream() {
    return _firestore
        .collection('posts')
        .where('status', whereIn: [PostStatus.available.name, PostStatus.pending.name])
        .where('expiry', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiry')
        .orderBy('timestamp', descending: true) // Latest first
        .snapshots()
        .map((snapshot) {
      List<PostModel> posts = snapshot.docs
          .map((doc) => PostModel.fromDocument(doc))
          .toList();
      
      // Apply dietary filter if any tags are selected
      if (_selectedDietaryTags.isNotEmpty) {
        posts = posts.where((post) {
          // If no dietary tags on post, only show if "none" is selected
          if (post.dietaryTags.isEmpty || post.dietaryTags.contains(DietaryTag.none)) {
            return _selectedDietaryTags.contains(DietaryTag.none);
          }
          // Check if post has any of the selected dietary tags
          return post.dietaryTags.any((tag) => _selectedDietaryTags.contains(tag));
        }).toList();
      }
      
      return posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),
          // Posts List
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState('Error loading posts: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final posts = snapshot.data!;
                return _buildPostsList(posts);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
          // No need to refresh manually - StreamBuilder handles it automatically
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Rebuild to retry the stream
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_food, color: AppColors.secondary, size: 80),
          const SizedBox(height: 16),
          const Text(
            'No food available right now',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share some food!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPostScreen(),
                ),
              );
              // No need to refresh manually - StreamBuilder handles it automatically
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Food Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(List<PostModel> posts) {
    return ListView.builder(
      itemCount: posts.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final post = posts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(PostModel post) {
    final formattedDate = DateFormat('MMM d, yyyy').format(post.timestamp);
    final formattedTime = DateFormat('h:mm a').format(post.timestamp);
    final isCurrentUserPost = post.postedBy == _auth.currentUser?.uid;
    final isPending = post.status == PostStatus.pending;
    final isAvailable = post.status == PostStatus.available;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          if (post.imageUrl.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    post.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Image not available',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Status overlays
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // "Your Post" overlay
                      if (isCurrentUserPost)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Your Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Pending status overlay
                      if (isPending) ...[
                        if (isCurrentUserPost) const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Claim Pending',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  post.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 15,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[500], size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.address,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Time info row
                Row(
                  children: [
                    // Posted time
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.grey[500],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Posted: $formattedDate · $formattedTime',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status info (for pending posts)
                if (isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Someone has claimed this food - awaiting response',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Expiry info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Expires in: ${_getExpiryText(post)}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dietary Tags
                if (post.dietaryTags.isNotEmpty && !post.dietaryTags.contains(DietaryTag.none)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.dietaryTags
                        .where((tag) => tag != DietaryTag.none)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.secondary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getDietaryTagDisplayName(tag),
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _viewPostDetails(post);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (isCurrentUserPost || isPending)
                            ? null
                            : () {
                                _claimPost(post);
                              },
                        icon: Icon(
                          isPending ? Icons.hourglass_empty : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text(isPending ? 'Pending' : 'Claim'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPending ? Colors.orange : AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
    );
  }

  String _getExpiryText(PostModel post) {
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

  void _viewPostDetails(PostModel post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(
          initialPost: post,
          isOwnPost: post.postedBy == _auth.currentUser?.uid,
        ),
      ),
    );

    // Refresh posts if the post was claimed
    if (result == true) {
      setState(() {}); // Rebuild to refresh the stream
    }
  }

  void _claimPost(PostModel post) async {
    try {
      await ClaimService.createClaim(
        postId: post.postId,
        creatorId: post.postedBy,
      );

      // Show success message and refresh posts
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food claimed successfully! The poster will be notified.'),
            backgroundColor: AppColors.primary,
          ),
        );
        setState(() {}); // Rebuild to refresh the stream
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim food: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Filter button
          OutlinedButton.icon(
            onPressed: _showDietaryFilterDialog,
            icon: Icon(
              Icons.filter_list,
              size: 18,
              color: _selectedDietaryTags.isNotEmpty 
                  ? AppColors.primary 
                  : Colors.grey[600],
            ),
            label: Text(
              _selectedDietaryTags.isEmpty 
                  ? 'Filter' 
                  : 'Filter (${_selectedDietaryTags.length})',
              style: TextStyle(
                color: _selectedDietaryTags.isNotEmpty 
                    ? AppColors.primary 
                    : Colors.grey[600],
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _selectedDietaryTags.isNotEmpty 
                    ? AppColors.primary 
                    : Colors.grey[300]!,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          
          // Clear filters button (only show if filters are active)
          if (_selectedDietaryTags.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
          
          const Spacer(),
          
          // Active filter chips
          if (_selectedDietaryTags.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _selectedDietaryTags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text(
                          _getDietaryTagDisplayName(tag),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () => _removeFilter(tag),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelStyle: const TextStyle(color: AppColors.primary),
                        deleteIconColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDietaryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Dietary Tags'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: DietaryTag.values.map((tag) {
                  return CheckboxListTile(
                    title: Text(_getDietaryTagDisplayName(tag)),
                    value: _selectedDietaryTags.contains(tag),
                    activeColor: AppColors.primary,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          _selectedDietaryTags.add(tag);
                        } else {
                          _selectedDietaryTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedDietaryTags.clear();
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // Update main screen to apply filters
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedDietaryTags.clear();
    });
  }

  void _removeFilter(DietaryTag tag) {
    setState(() {
      _selectedDietaryTags.remove(tag);
    });
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
        return 'No Restrictions';
    }
  }
}
