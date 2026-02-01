import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  UserModel? _user;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    if (authService.currentUser != null) {
      // Use resolved ID to get linked account data for bypass mode users
      final resolvedId = await authService.getResolvedUserId();
      final user = await firestoreService.getUser(resolvedId);
      if (user != null && mounted) {
        setState(() {
          _user = user;
          _nameController.text = user.displayName;
          _emailController.text = user.email;
          _phoneController.text = user.phone ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final storageService = context.read<StorageService>();

      String? photoUrl;

      if (_imageFile != null) {
        photoUrl = await storageService.uploadProfileImage(
          userId: _user!.id,
          imageFile: XFile(_imageFile!.path),
        );
      }

      await firestoreService.updateUserProfile(
        userId: _user!.id,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        photoUrl: photoUrl,
      );

      // FORCE REFRESH: If we are in bypass mode (editing a linked account),
      // the userModelStream (which listens to the proxy user) won't update
      // because the proxy doc didn't change. We must touch the proxy doc
      // to trigger the asyncMap and fetch the new linked data.
      final currentUser = context.read<AuthService>().currentUser;
      if (currentUser != null && currentUser.uid != _user!.id) {
        await firestoreService.updateUserProfile(
          userId: currentUser.uid,
          displayName:
              currentUser.displayName ??
              'User', // No-op change just to touch doc
          // We just want to trigger an update, actually updating lastLogin via a service method would be cleaner
          // but reuse existing method for now.
        );
        // Or better, just update a timestamp field directly if we had a method
        // But updateUserProfile updates 'lastLoginAt' internally! So calling it specifically updates the timestamp.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vignesh Agencies profile updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Avatar
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          image:
                              _imageFile != null
                                  ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                  : (_user?.photoUrl != null
                                      ? DecorationImage(
                                        image: NetworkImage(_user!.photoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                      : null),
                        ),
                        child:
                            _imageFile == null && _user?.photoUrl == null
                                ? Center(
                                  child: Text(
                                    _user?.displayName.isNotEmpty == true
                                        ? _user!.displayName[0].toUpperCase()
                                        : 'U',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Name Field
              Text('Full Name', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Email Field
              Text(
                'Email Address',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 24),

              // Phone Field (Read Only)
              Text(
                'Phone Number',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor:
                      Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade200
                          : Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.lock_outline, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number cannot be changed'),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Phone number is linked to your account and cannot be changed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
