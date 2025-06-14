import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/claim_service.dart';
import 'claim_details_screen.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({Key? key}) : super(key: key);

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen>
    with SingleTickerProviderStateMixin {
  final ClaimService _claimService = ClaimService();
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Claims'),
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'As Claimer'),
            Tab(text: 'As Donor'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClaimsList(true), // As claimer
          _buildClaimsList(false), // As donor
        ],
      ),
    );
  }

  Widget _buildClaimsList(bool asClaimer) {
    if (_currentUserId == null) {
      return const Center(child: Text('Please sign in to view your claims'));
    }

    return StreamBuilder<List<ClaimModel>>(
      stream: _claimService.getUserClaims(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        final allClaims = snapshot.data!;
        final filteredClaims = allClaims.where((claim) {
          if (asClaimer) {
            return claim.claimerId == _currentUserId;
          } else {
            return claim.donorId == _currentUserId;
          }
        }).toList();

        if (filteredClaims.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  asClaimer ? Icons.shopping_basket : Icons.restaurant,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  asClaimer ? 'No claims yet' : 'No donations claimed yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  asClaimer
                      ? 'Start claiming food items from others!'
                      : 'Share food items to see claims here!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh by rebuilding the stream
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredClaims.length,
            itemBuilder: (context, index) {
              final claim = filteredClaims[index];
              return _buildClaimCard(claim, asClaimer);
            },
          ),
        );
      },
    );
  }

  Widget _buildClaimCard(ClaimModel claim, bool asClaimer) {
    final isExpired = claim.isExpired;
    final canTakeAction = _canTakeAction(claim, asClaimer);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ClaimDetailsScreen(claimId: claim.claimId, claim: claim),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claim #${claim.claimId.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(claim.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(claim.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isExpired)
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                ],
              ),

              const SizedBox(height: 12),

              // Timestamp
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Claimed: ${DateFormat('MMM dd, yyyy').format(claim.timestamp)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              if (claim.pickupNotes != null &&
                  claim.pickupNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Notes: ${claim.pickupNotes}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Action button
              if (canTakeAction) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClaimDetailsScreen(
                            claimId: claim.claimId,
                            claim: claim,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(_getActionButtonText(claim, asClaimer)),
                  ),
                ),
              ],

              // Rating prompt
              if (claim.isCompleted && claim.canRate) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rate your experience!',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClaimDetailsScreen(
                                claimId: claim.claimId,
                                claim: claim,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber[800],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Rate Now'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _canTakeAction(ClaimModel claim, bool asClaimer) {
    if (asClaimer) {
      return claim.canBeConfirmedByClaimer;
    } else {
      return claim.canBeAccepted || claim.canBeConfirmedByDonor;
    }
  }

  String _getActionButtonText(ClaimModel claim, bool asClaimer) {
    if (asClaimer) {
      if (claim.canBeConfirmedByClaimer) {
        return 'Confirm Pickup';
      }
    } else {
      if (claim.canBeAccepted) {
        return 'Accept Claim';
      } else if (claim.canBeConfirmedByDonor) {
        return 'Confirm Completion';
      }
    }
    return 'View Details';
  }

  Color _getStatusColor(ClaimStatus status) {
    switch (status) {
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

  String _getStatusText(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return 'Pending';
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
