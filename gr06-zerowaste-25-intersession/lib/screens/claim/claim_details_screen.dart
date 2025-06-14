import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/claim_service.dart';
import '../../services/rating_service.dart';
import '../../views/rating_widgets.dart';
import '../rating_screen.dart';

class ClaimDetailsScreen extends StatefulWidget {
  final String claimId;
  final ClaimModel? claim;

  const ClaimDetailsScreen({Key? key, required this.claimId, this.claim})
    : super(key: key);

  @override
  State<ClaimDetailsScreen> createState() => _ClaimDetailsScreenState();
}

class _ClaimDetailsScreenState extends State<ClaimDetailsScreen> {
  final ClaimService _claimService = ClaimService();
  final RatingService _ratingService = RatingService();
  final TextEditingController _notesController = TextEditingController();

  ClaimModel? _claim;
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadClaim();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClaim() async {
    try {
      if (widget.claim != null) {
        _claim = widget.claim;
      } else {
        _claim = await _claimService.getClaimById(widget.claimId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptClaim() async {
    try {
      await _claimService.acceptClaim(widget.claimId);
      await _loadClaim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim accepted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmPickup() async {
    try {
      await _claimService.confirmPickup(
        widget.claimId,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      await _loadClaim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup confirmed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming pickup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmCompletion() async {
    try {
      await _claimService.confirmCompletion(widget.claimId);
      await _loadClaim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion confirmed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming completion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelClaim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Claim'),
        content: const Text('Are you sure you want to cancel this claim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _claimService.cancelClaim(widget.claimId);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim cancelled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog(String targetUserId, String targetUserName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RatingSubmissionWidget(
            fromUserId: _currentUserId!,
            toUserId: targetUserId,
            relatedPostId: _claim!.postId,
            onSubmit: (rating, comment) async {
              try {
                await _ratingService.createRating(
                  fromUserId: _currentUserId!,
                  toUserId: targetUserId,
                  rating: rating,
                  comment: comment,
                  relatedPostId: _claim!.postId,
                );

                // Mark claim as rated
                final isClaimer = _currentUserId == _claim!.claimerId;
                await _claimService.markClaimAsRated(widget.claimId, isClaimer);

                Navigator.of(context).pop();
                await _loadClaim();

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
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_claim == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Claim Details'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: Text('Claim not found')),
      );
    }

    final isClaimer = _currentUserId == _claim!.claimerId;
    final isDonor = _currentUserId == _claim!.donorId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Claim Details'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_claim!.status != ClaimStatus.completed &&
              _claim!.status != ClaimStatus.cancelled &&
              _claim!.status != ClaimStatus.expired)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelClaim,
              tooltip: 'Cancel Claim',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),

            const SizedBox(height: 16),

            // Timeline Card
            _buildTimelineCard(),

            const SizedBox(height: 16),

            // Action Buttons
            if (_claim!.status != ClaimStatus.completed &&
                _claim!.status != ClaimStatus.cancelled &&
                _claim!.status != ClaimStatus.expired)
              _buildActionButtons(),

            const SizedBox(height: 16),

            // Rating Section
            if (_claim!.isCompleted) _buildRatingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim Status',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_claim!.pickupNotes != null &&
                _claim!.pickupNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Pickup Notes:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(_claim!.pickupNotes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Claim Requested',
              _claim!.timestamp,
              Icons.add_circle,
              Colors.blue,
            ),
            if (_claim!.acceptedAt != null)
              _buildTimelineItem(
                'Claim Accepted',
                _claim!.acceptedAt!,
                Icons.check_circle,
                Colors.green,
              ),
            if (_claim!.pickupConfirmedAt != null)
              _buildTimelineItem(
                'Pickup Confirmed',
                _claim!.pickupConfirmedAt!,
                Icons.local_shipping,
                Colors.orange,
              ),
            if (_claim!.completedAt != null)
              _buildTimelineItem(
                'Completed',
                _claim!.completedAt!,
                Icons.done_all,
                Colors.purple,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM dd, yyyy \'at\' h:mm a').format(date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isClaimer = _currentUserId == _claim!.claimerId;
    final isDonor = _currentUserId == _claim!.donorId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Donor actions
            if (isDonor && _claim!.canBeAccepted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _acceptClaim,
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Claim'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            // Claimer actions
            if (isClaimer && _claim!.canBeConfirmedByClaimer) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add pickup notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmPickup,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Confirm Pickup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

            // Donor completion action
            if (isDonor && _claim!.canBeConfirmedByDonor) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmCompletion,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Confirm Completion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    final isClaimer = _currentUserId == _claim!.claimerId;
    final isDonor = _currentUserId == _claim!.donorId;

    if (!isClaimer && !isDonor) return const SizedBox.shrink();

    final canRateClaimer = isDonor && !_claim!.donorRated;
    final canRateDonor = isClaimer && !_claim!.claimerRated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate Your Experience',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (canRateClaimer)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Rate the Claimer'),
                subtitle: const Text(
                  'Share your experience with the person who claimed your food',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRatingDialog(_claim!.claimerId, 'Claimer'),
              ),

            if (canRateDonor)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Rate the Donor'),
                subtitle: const Text(
                  'Share your experience with the person who shared the food',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRatingDialog(_claim!.donorId, 'Donor'),
              ),

            if (!canRateClaimer && !canRateDonor)
              const Text(
                'You have already rated for this claim.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_claim!.status) {
      case ClaimStatus.pending:
        return Colors.orange;
      case ClaimStatus.accepted:
        return Colors.blue;
      case ClaimStatus.pickup_confirmed:
        return Colors.purple;
      case ClaimStatus.completed:
        return Colors.green;
      case ClaimStatus.cancelled:
        return Colors.red;
      case ClaimStatus.expired:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_claim!.status) {
      case ClaimStatus.pending:
        return 'Pending Approval';
      case ClaimStatus.accepted:
        return 'Accepted';
      case ClaimStatus.pickup_confirmed:
        return 'Pickup Confirmed';
      case ClaimStatus.completed:
        return 'Completed';
      case ClaimStatus.cancelled:
        return 'Cancelled';
      case ClaimStatus.expired:
        return 'Expired';
    }
  }
}
