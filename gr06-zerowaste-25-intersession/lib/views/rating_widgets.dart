import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Widget to display a user's average rating
class UserRatingDisplay extends StatelessWidget {
  final double rating;
  final int totalRatings;
  final double size;
  final bool showText;

  const UserRatingDisplay({
    Key? key,
    required this.rating,
    this.totalRatings = 0,
    this.size = 20.0,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBar.builder(
          initialRating: rating,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemSize: size,
          ignoreGestures: true,
          itemBuilder: (context, index) {
            return const Icon(Icons.star, color: Colors.amber);
          },
          onRatingUpdate: (rating) {},
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            '${rating.toStringAsFixed(1)}',
            style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.bold),
          ),
          if (totalRatings > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($totalRatings)',
              style: TextStyle(fontSize: size * 0.5, color: Colors.grey[600]),
            ),
          ],
        ],
      ],
    );
  }
}

/// Widget to submit a rating
class RatingSubmissionWidget extends StatefulWidget {
  final String fromUserId;
  final String toUserId;
  final String? relatedPostId;
  final Function(double rating, String? comment) onSubmit;
  final double? initialRating;
  final String? initialComment;
  final bool isEditing;

  const RatingSubmissionWidget({
    Key? key,
    required this.fromUserId,
    required this.toUserId,
    this.relatedPostId,
    required this.onSubmit,
    this.initialRating,
    this.initialComment,
    this.isEditing = false,
  }) : super(key: key);

  @override
  State<RatingSubmissionWidget> createState() => _RatingSubmissionWidgetState();
}

class _RatingSubmissionWidgetState extends State<RatingSubmissionWidget> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRating != null) {
      _rating = widget.initialRating!;
    }
    if (widget.initialComment != null) {
      _commentController.text = widget.initialComment!;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isEditing ? 'Edit Rating' : 'Rate this user',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Rating stars
          Center(
            child: RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 40,
              itemBuilder: (context, index) {
                return const Icon(Icons.star, color: Colors.amber);
              },
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Comment field
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating == 0 || _isSubmitting
                  ? null
                  : () async {
                      setState(() {
                        _isSubmitting = true;
                      });

                      try {
                        await widget.onSubmit(
                          _rating,
                          _commentController.text.isEmpty
                              ? null
                              : _commentController.text,
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSubmitting = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(widget.isEditing ? 'Update Rating' : 'Submit Rating'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display a list of ratings
class RatingsListWidget extends StatelessWidget {
  final List<RatingModel> ratings;
  final String currentUserId;
  final Function(RatingModel)? onEditRating;
  final Function(String)? onDeleteRating;

  const RatingsListWidget({
    Key? key,
    required this.ratings,
    required this.currentUserId,
    this.onEditRating,
    this.onDeleteRating,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No ratings yet',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ratings.length,
      itemBuilder: (context, index) {
        final rating = ratings[index];
        final canEdit = rating.fromUserId == currentUserId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: UserRatingDisplay(
                        rating: rating.rating,
                        size: 16,
                        showText: false,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(rating.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),

                if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(rating.comment!, style: const TextStyle(fontSize: 14)),
                ],

                if (canEdit) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => onEditRating?.call(rating),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => _showDeleteDialog(context, rating.id),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String ratingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text('Are you sure you want to delete this rating?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDeleteRating?.call(ratingId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Widget to show rating statistics
class RatingStatsWidget extends StatelessWidget {
  final double averageRating;
  final int totalRatings;
  final Map<int, int> ratingDistribution;

  const RatingStatsWidget({
    Key? key,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserRatingDisplay(
                  rating: averageRating,
                  totalRatings: totalRatings,
                  size: 24,
                ),
                const Spacer(),
                Text(
                  '${averageRating.toStringAsFixed(1)} out of 5',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (totalRatings > 0) ...[
              const SizedBox(height: 16),
              const Text(
                'Rating Distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(5, (index) {
                final starCount = 5 - index;
                final count = ratingDistribution[starCount] ?? 0;
                final percentage = totalRatings > 0
                    ? (count / totalRatings) * 100
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$starCount', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$count', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
