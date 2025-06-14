import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../controllers/report_controller.dart';

class ReportListDialog extends StatelessWidget {
  final String postId;

  const ReportListDialog({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<ReportModel>>(
                  stream: ReportController.getReportsForPost(postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading reports: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }

                    final reports = snapshot.data ?? [];
                    if (reports.isEmpty) {
                      return const Center(
                        child: Text('No reports found'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getReportTypeIcon(report.type),
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getReportTypeText(report.type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(report.timestamp),
                                      style: TextStyle(
                                        color: AppColors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(report.description),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.inappropriate:
        return Icons.warning_amber_rounded;
      case ReportType.scam:
        return Icons.gpp_bad_rounded;
      case ReportType.unsafeBehavior:
        return Icons.security_rounded;
    }
  }

  String _getReportTypeText(ReportType type) {
    switch (type) {
      case ReportType.inappropriate:
        return 'Inappropriate Content';
      case ReportType.scam:
        return 'Scam or Fraud';
      case ReportType.unsafeBehavior:
        return 'Unsafe Behavior';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 