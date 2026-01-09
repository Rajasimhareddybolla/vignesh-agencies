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
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v?.length == 10 ? null : 'Enter valid phone',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (House No, Building, Street)',
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
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (v) =>
                            v?.isNotEmpty == true ? null : 'Required',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: pincodeController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
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
                  children: ['Home', 'Work', 'Other'].map((t) {
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
                        final uid = authService.currentUser!.uid;
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
        title: const Text('Saved Addresses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(authService.currentUser!.uid)
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
                    color: AppTheme.textSecondaryLight.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No addresses saved',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
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
                          child: Text(
                            data['type'] ?? 'Home',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showAddAddressSheet(
                                context,
                                existingAddress: data,
                                docId: doc.id,
                              );
                            } else if (value == 'delete') {
                              await doc.reference.delete();
                            }
                          },
                          child: const Icon(
                            Icons.more_vert,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['name'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(data['address'] ?? ''),
                    Text('${data['city'] ?? ''} - ${data['pincode'] ?? ''}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppTheme.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data['phone'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAddressSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
