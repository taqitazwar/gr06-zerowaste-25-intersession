import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  inappropriate,
  scam,
  unsafeBehavior,
}

class ReportModel {
  final String id;
  final String postId;
  final String reporterId;
  final ReportType type;
  final String description;
  final DateTime timestamp;
  final bool isResolved;

  ReportModel({
    required this.id,
    required this.postId,
    required this.reporterId,
    required this.type,
    required this.description,
    required this.timestamp,
    this.isResolved = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'reporterId': reporterId,
      'type': type.name,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'isResolved': isResolved,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      reporterId: map['reporterId'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ReportType.inappropriate,
      ),
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isResolved: map['isResolved'] ?? false,
    );
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }
} 