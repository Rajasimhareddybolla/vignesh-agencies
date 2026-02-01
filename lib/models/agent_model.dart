import 'package:cloud_firestore/cloud_firestore.dart';

class AgentModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String? email;
  final String? specialization; // e.g., "Water Heater Expert", "AC Technician"
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastAssignedAt;

  AgentModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.email,
    this.specialization,
    this.isActive = true,
    required this.createdAt,
    this.lastAssignedAt,
  });

  factory AgentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AgentModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      email: data['email'],
      specialization: data['specialization'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastAssignedAt: (data['lastAssignedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'specialization': specialization,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastAssignedAt':
          lastAssignedAt != null ? Timestamp.fromDate(lastAssignedAt!) : null,
    };
  }

  AgentModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? email,
    String? specialization,
    bool? isActive,
    DateTime? lastAssignedAt,
  }) {
    return AgentModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      specialization: specialization ?? this.specialization,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastAssignedAt: lastAssignedAt ?? this.lastAssignedAt,
    );
  }
}
