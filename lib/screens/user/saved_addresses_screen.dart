import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _firestore = FirebaseFirestore.instance;

  void _showAddAddressSheet(
    BuildContext context, {
    Map<String, dynamic>? existingAddress,
    String? docId,
  }) {
    final nameController = TextEditingController(
      text: existingAddress?['name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: existingAddress?['phone'] ?? '',
    );
    final addressController = TextEditingController(
      text: existingAddress?['address'] ?? '',
    );
    final cityController = TextEditingController(
      text: existingAddress?['city'] ?? '',
    );
    final pincodeController = TextEditingController(
      text: existingAddress?['pincode'] ?? '',
    );
    String type = existingAddress?['type'] ?? 'Home';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docId == null ? 'Add New Address' : 'Edit Address',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator:
                      (v) => v?.length == 10 ? null : 'Enter valid phone',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (House No, Building, Street) *',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  maxLines: 2,
                  validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator:
                            (v) => v?.isNotEmpty == true ? null : 'Required',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: pincodeController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode *',
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v?.length == 6 ? null : 'Invalid Pin',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Address Type'),
                const SizedBox(height: 8),
                Row(
                  children:
                      ['Home', 'Work', 'Other'].map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: type == t,
                            onSelected: (selected) {
                              if (selected) {
                                type = t;
                                (context as Element).markNeedsBuild();
                              }
                            },
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final authService = context.read<AuthService>();
                        // Use resolved UID to support linked accounts (bypass mode)
                        final uid = await authService.getResolvedUserId();
                        final data = {
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'city': cityController.text.trim(),
                          'pincode': pincodeController.text.trim(),
                          'type': type,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (docId == null) {
                          data['createdAt'] = FieldValue.serverTimestamp();
                          await _firestore
                              .collection('users')
                              .doc(uid)
                              .collection('addresses')
                              .add(data);
                        } else {
                          await _firestore
                              .collection('users')
                              .doc(uid)
                              .collection('addresses')
                              .doc(docId)
                              .update(data);
                        }

                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      docId == null ? 'Save Address' : 'Update Address',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    if (authService.currentUser == null)
      return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Delivery Address'),
      ),
      body: FutureBuilder<String>(
        future: authService.getResolvedUserId(),
        builder: (context, uidSnapshot) {
          if (uidSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (uidSnapshot.hasError || !uidSnapshot.hasData) {
            return const Center(child: Text('Error loading user profile'));
          }

          final uid = uidSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .doc(uid)
                    .collection('addresses')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: Text('Error loading addresses'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: AppTheme.textSecondary(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No delivery address saved',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.textSecondary(context)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddAddressSheet(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Address'),
                      ),
                    ],
                  ),
                );
              }

              // Single address model - only show the first (most recent) address
              final doc = docs.first;
              final data = doc.data() as Map<String, dynamic>;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your delivery address',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border(context)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Default',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    () => _showAddAddressSheet(
                                      context,
                                      existingAddress: data,
                                      docId: doc.id,
                                    ),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            data['name'] ?? '',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['address'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          Text(
                            '${data['city'] ?? ''} - ${data['pincode'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: AppTheme.textSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['phone'] ?? '',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // No FAB when address exists - single address model
    );
  }
}
