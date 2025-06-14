import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/rating_service.dart';
import '../services/auth_service.dart';
import '../views/rating_widgets.dart';

class RatingScreen extends StatefulWidget {
  final String targetUserId;
  final String? targetUserName;
  final String? relatedPostId;

  const RatingScreen({
    Key? key,
    required this.targetUserId,
    this.targetUserName,
    this.relatedPostId,
  }) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final RatingService _ratingService = RatingService();
  String? _currentUserId;
  RatingModel? _existingRating;
  Map<String, dynamic> _ratingStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _currentUserId = authService.currentUser?.uid;

      if (_currentUserId != null) {
        // Load existing rating if any
        _existingRating = await _ratingService.getExistingRating(
          fromUserId: _currentUserId!,
          toUserId: widget.targetUserId,
          relatedPostId: widget.relatedPostId,
        );

        // Load rating statistics
        _ratingStats = await _ratingService.getUserRatingStats(
          widget.targetUserId,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRating(double rating, String? comment) async {
    try {
      if (_existingRating != null) {
        // Update existing rating
        await _ratingService.updateRating(
          ratingId: _existingRating!.id,
          rating: rating,
          comment: comment,
        );
      } else {
        // Create new rating
        await _ratingService.createRating(
          fromUserId: _currentUserId!,
          toUserId: widget.targetUserId,
          rating: rating,
          comment: comment,
          relatedPostId: widget.relatedPostId,
        );
      }

      // Reload data
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRating(String ratingId) async {
    try {
      await _ratingService.deleteRating(ratingId);
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RatingSubmissionWidget(
            fromUserId: _currentUserId!,
            toUserId: widget.targetUserId,
            relatedPostId: widget.relatedPostId,
            onSubmit: _submitRating,
            initialRating: _existingRating?.rating,
            initialComment: _existingRating?.comment,
            isEditing: _existingRating != null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUserName ?? 'User Ratings'),
        actions: [
          if (_currentUserId != null && _currentUserId != widget.targetUserId)
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: _showRatingDialog,
              tooltip: _existingRating != null ? 'Edit Rating' : 'Rate User',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating Statistics
                    RatingStatsWidget(
                      averageRating: _ratingStats['averageRating'] ?? 0.0,
                      totalRatings: _ratingStats['totalRatings'] ?? 0,
                      ratingDistribution: Map<int, int>.from(
                        _ratingStats['ratingDistribution'] ?? {},
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Individual Ratings
                    const Text(
                      'All Ratings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    StreamBuilder<List<RatingModel>>(
                      stream: _ratingService.getUserRatings(
                        widget.targetUserId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final ratings = snapshot.data!;

                        return RatingsListWidget(
                          ratings: ratings,
                          currentUserId: _currentUserId ?? '',
                          onEditRating: (rating) {
                            _existingRating = rating;
                            _showRatingDialog();
                          },
                          onDeleteRating: _deleteRating,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
