import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reportsCollection = 'reports';

  // Create a new report
  static Future<void> createReport({
    required String postId,
    required String reporterId,
    required ReportType type,
    required String description,
  }) async {
    try {
      final report = ReportModel(
        id: '', // Will be set by Firestore
        postId: postId,
        reporterId: reporterId,
        type: type,
        description: description,
        timestamp: DateTime.now(),
        isResolved: false,
      );

      await _firestore.collection(_reportsCollection).add(report.toMap());
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  // Get reports for a specific post
  static Stream<List<ReportModel>> getReportsForPost(String postId) {
    return _firestore
        .collection(_reportsCollection)
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList();
        });
  }

  // Check if a post has any reports
  static Stream<bool> hasReports(String postId) {
    return _firestore
        .collection(_reportsCollection)
        .where('postId', isEqualTo: postId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }
} 