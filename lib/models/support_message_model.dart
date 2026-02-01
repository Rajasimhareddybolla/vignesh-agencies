import 'package:cloud_firestore/cloud_firestore.dart';

class SupportMessageModel {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final DateTime createdAt;
  final String status; // 'new', 'read', 'replied'

  SupportMessageModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.createdAt,
    this.status = 'new',
  });

  factory SupportMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportMessageModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'new',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'subject': subject,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}
