import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceRequestStatus {
  pending,
  assigned,
  inProgress,
  resolved,
  completed,
  escalated,
  cancelled,
}

extension ServiceRequestStatusExtension on ServiceRequestStatus {
  String get displayName {
    switch (this) {
      case ServiceRequestStatus.pending:
        return 'Pending';
      case ServiceRequestStatus.assigned:
        return 'Assigned';
      case ServiceRequestStatus.inProgress:
        return 'In Progress';
      case ServiceRequestStatus.resolved:
        return 'Resolved';
      case ServiceRequestStatus.completed:
        return 'Completed';
      case ServiceRequestStatus.escalated:
        return 'Escalated';
      case ServiceRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ServiceRequestStatus.pending:
        return 'pending';
      case ServiceRequestStatus.assigned:
        return 'assigned';
      case ServiceRequestStatus.inProgress:
        return 'in_progress';
      case ServiceRequestStatus.resolved:
        return 'resolved';
      case ServiceRequestStatus.completed:
        return 'completed';
      case ServiceRequestStatus.escalated:
        return 'escalated';
      case ServiceRequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static ServiceRequestStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ServiceRequestStatus.pending;
      case 'assigned':
        return ServiceRequestStatus.assigned;
      case 'in_progress':
        return ServiceRequestStatus.inProgress;
      case 'resolved':
        return ServiceRequestStatus.resolved;
      case 'completed':
        return ServiceRequestStatus.completed;
      case 'escalated':
        return ServiceRequestStatus.escalated;
      case 'cancelled':
        return ServiceRequestStatus.cancelled;
      default:
        return ServiceRequestStatus.pending;
    }
  }
}

enum ServicePriority { normal, urgent }

extension ServicePriorityExtension on ServicePriority {
  String get displayName {
    switch (this) {
      case ServicePriority.normal:
        return 'Normal';
      case ServicePriority.urgent:
        return 'Urgent';
    }
  }
}

/// Represents a status update in the service request timeline
class ServiceStatusUpdate {
  final String status;
  final String message;
  final DateTime timestamp;
  final String? updatedBy; // 'system', 'admin', 'technician'

  ServiceStatusUpdate({
    required this.status,
    required this.message,
    required this.timestamp,
    this.updatedBy,
  });

  factory ServiceStatusUpdate.fromMap(Map<String, dynamic> map) {
    return ServiceStatusUpdate(
      status: map['status']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedBy': updatedBy,
    };
  }
}

class ServiceRequestModel {
  final String id;
  final String userId;
  final String productId;
  final String ticketNumber;
  final String issueType;
  final String description;
  final List<String> evidenceImages;
  final String? audioRecordingUrl;
  final ServiceRequestStatus status;
  final ServicePriority priority;
  final String? assignedProvider;
  final String? technicianName;
  final String? technicianPhone;
  final String? technicianAddress;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;
  final String? adminVoiceNoteUrl;

  // Customer details (denormalized for quick access)
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;

  // Product details (denormalized)
  final String? productName;
  final String? productModel;

  // Phase 3: Enhanced tracking fields
  final DateTime? estimatedCompletionDate;
  final DateTime? technicianArrivalTime;
  final DateTime? serviceStartedAt;
  final DateTime? completedAt;
  final List<ServiceStatusUpdate> statusUpdates;
  
  // Phase 3: Feedback fields
  final int? rating; // 1-5 stars
  final String? feedbackComment;
  final DateTime? feedbackSubmittedAt;
  final bool feedbackRequested;

  ServiceRequestModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.ticketNumber,
    required this.issueType,
    required this.description,
    this.evidenceImages = const [],
    this.audioRecordingUrl,
    this.status = ServiceRequestStatus.pending,
    this.priority = ServicePriority.normal,
    this.assignedProvider,
    this.technicianName,
    this.technicianPhone,
    this.technicianAddress,
    this.resolutionNotes,
    required this.createdAt,
    this.assignedAt,
    this.resolvedAt,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.productName,
    this.productModel,
    this.adminVoiceNoteUrl,
    // Phase 3 fields
    this.estimatedCompletionDate,
    this.technicianArrivalTime,
    this.serviceStartedAt,
    this.completedAt,
    this.statusUpdates = const [],
    this.rating,
    this.feedbackComment,
    this.feedbackSubmittedAt,
    this.feedbackRequested = false,
  });

  factory ServiceRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Safety check for evidenceImages
    List<String> images = [];
    if (data['evidenceImages'] is List) {
      images =
          (data['evidenceImages'] as List).map((e) => e.toString()).toList();
    }

    return ServiceRequestModel(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      productId: data['productId']?.toString() ?? '',
      ticketNumber: data['ticketNumber']?.toString() ?? '',
      issueType: data['issueType']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      evidenceImages: images,
      audioRecordingUrl: data['audioRecordingUrl']?.toString(),
      status: ServiceRequestStatusExtension.fromString(
        data['status']?.toString() ?? 'pending',
      ),
      priority:
          data['priority'] == 'urgent'
              ? ServicePriority.urgent
              : ServicePriority.normal,
      assignedProvider: data['assignedProvider']?.toString(),
      technicianName: data['technicianName']?.toString(),
      technicianPhone: data['technicianPhone']?.toString(),
      technicianAddress: data['technicianAddress']?.toString(),
      resolutionNotes: data['resolutionNotes']?.toString(),
      createdAt:
          (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      assignedAt:
          (data['assignedAt'] is Timestamp)
              ? (data['assignedAt'] as Timestamp).toDate()
              : null,
      resolvedAt:
          (data['resolvedAt'] is Timestamp)
              ? (data['resolvedAt'] as Timestamp).toDate()
              : null,
      customerName: data['customerName']?.toString(),
      customerPhone: data['customerPhone']?.toString(),
      customerAddress: data['customerAddress']?.toString(),
      productName: data['productName']?.toString(),
      productModel: data['productModel']?.toString(),
      adminVoiceNoteUrl: data['adminVoiceNoteUrl']?.toString(),
      // Phase 3 fields
      estimatedCompletionDate:
          (data['estimatedCompletionDate'] is Timestamp)
              ? (data['estimatedCompletionDate'] as Timestamp).toDate()
              : null,
      technicianArrivalTime:
          (data['technicianArrivalTime'] is Timestamp)
              ? (data['technicianArrivalTime'] as Timestamp).toDate()
              : null,
      serviceStartedAt:
          (data['serviceStartedAt'] is Timestamp)
              ? (data['serviceStartedAt'] as Timestamp).toDate()
              : null,
      completedAt:
          (data['completedAt'] is Timestamp)
              ? (data['completedAt'] as Timestamp).toDate()
              : null,
      statusUpdates: (data['statusUpdates'] is List)
          ? (data['statusUpdates'] as List)
              .map((e) => ServiceStatusUpdate.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
      rating: data['rating'] as int?,
      feedbackComment: data['feedbackComment']?.toString(),
      feedbackSubmittedAt:
          (data['feedbackSubmittedAt'] is Timestamp)
              ? (data['feedbackSubmittedAt'] as Timestamp).toDate()
              : null,
      feedbackRequested: data['feedbackRequested'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'productId': productId,
      'ticketNumber': ticketNumber,
      'issueType': issueType,
      'description': description,
      'evidenceImages': evidenceImages,
      'audioRecordingUrl': audioRecordingUrl,
      'status': status.firestoreValue,
      'priority': priority == ServicePriority.urgent ? 'urgent' : 'normal',
      'assignedProvider': assignedProvider,
      'technicianName': technicianName,
      'technicianPhone': technicianPhone,
      'technicianAddress': technicianAddress,
      'resolutionNotes': resolutionNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'productName': productName,
      'productModel': productModel,
      'adminVoiceNoteUrl': adminVoiceNoteUrl,
      // Phase 3 fields
      'estimatedCompletionDate': estimatedCompletionDate != null 
          ? Timestamp.fromDate(estimatedCompletionDate!) : null,
      'technicianArrivalTime': technicianArrivalTime != null 
          ? Timestamp.fromDate(technicianArrivalTime!) : null,
      'serviceStartedAt': serviceStartedAt != null 
          ? Timestamp.fromDate(serviceStartedAt!) : null,
      'completedAt': completedAt != null 
          ? Timestamp.fromDate(completedAt!) : null,
      'statusUpdates': statusUpdates.map((e) => e.toMap()).toList(),
      'rating': rating,
      'feedbackComment': feedbackComment,
      'feedbackSubmittedAt': feedbackSubmittedAt != null 
          ? Timestamp.fromDate(feedbackSubmittedAt!) : null,
      'feedbackRequested': feedbackRequested,
    };
  }

  ServiceRequestModel copyWith({
    String? issueType,
    String? description,
    List<String>? evidenceImages,
    String? audioRecordingUrl,
    ServiceRequestStatus? status,
    ServicePriority? priority,
    String? assignedProvider,
    String? technicianName,
    String? technicianPhone,
    String? technicianAddress,
    String? resolutionNotes,
    DateTime? assignedAt,
    DateTime? resolvedAt,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? productName,
    String? productModel,
    String? adminVoiceNoteUrl,
    // Phase 3 fields
    DateTime? estimatedCompletionDate,
    DateTime? technicianArrivalTime,
    DateTime? serviceStartedAt,
    DateTime? completedAt,
    List<ServiceStatusUpdate>? statusUpdates,
    int? rating,
    String? feedbackComment,
    DateTime? feedbackSubmittedAt,
    bool? feedbackRequested,
  }) {
    return ServiceRequestModel(
      id: id,
      userId: userId,
      productId: productId,
      ticketNumber: ticketNumber,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      evidenceImages: evidenceImages ?? this.evidenceImages,
      audioRecordingUrl: audioRecordingUrl ?? this.audioRecordingUrl,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedProvider: assignedProvider ?? this.assignedProvider,
      technicianName: technicianName ?? this.technicianName,
      technicianPhone: technicianPhone ?? this.technicianPhone,
      technicianAddress: technicianAddress ?? this.technicianAddress,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      productName: productName ?? this.productName,
      productModel: productModel ?? this.productModel,
      adminVoiceNoteUrl: adminVoiceNoteUrl ?? this.adminVoiceNoteUrl,
      // Phase 3 fields
      estimatedCompletionDate: estimatedCompletionDate ?? this.estimatedCompletionDate,
      technicianArrivalTime: technicianArrivalTime ?? this.technicianArrivalTime,
      serviceStartedAt: serviceStartedAt ?? this.serviceStartedAt,
      completedAt: completedAt ?? this.completedAt,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      rating: rating ?? this.rating,
      feedbackComment: feedbackComment ?? this.feedbackComment,
      feedbackSubmittedAt: feedbackSubmittedAt ?? this.feedbackSubmittedAt,
      feedbackRequested: feedbackRequested ?? this.feedbackRequested,
    );
  }

  static String generateTicketNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '#REQ-${timestamp % 10000}';
  }

  // Common issue types
  static const List<String> issueTypes = [
    'Not Working',
    'Leaking Water',
    'Making Noise',
    'Overheating',
    'Display Not Working',
    'Remote Not Working',
    'Power Issue',
    'Performance Issue',
    'Physical Damage',
    'Installation Required',
    'Other',
  ];

  // Service providers
  static const List<String> serviceProviders = [
    'V-Guard Service Center',
    'Authorized Service Partner',
    'Third Party Technician',
  ];
  
  // Helper to check if feedback is pending
  bool get isFeedbackPending => 
      status == ServiceRequestStatus.completed && 
      rating == null && 
      feedbackRequested;
}
