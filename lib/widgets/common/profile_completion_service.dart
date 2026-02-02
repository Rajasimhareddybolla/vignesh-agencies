import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

/// Service for checking and prompting profile completion
class ProfileCompletionService {
  /// Check if user profile is complete for checkout/registration
  static bool isProfileComplete(UserModel? user) {
    if (user == null) return false;
    
    // Check required fields
    final hasName = user.displayName.isNotEmpty && 
                   user.displayName != 'User' && 
                   user.displayName != 'New User';
    final hasPhone = user.phone != null && user.phone!.isNotEmpty;
    
    return hasName && hasPhone;
  }

  /// Show profile completion dialog if needed
  /// Returns true if profile is complete or user completed it, false if they cancelled
  static Future<bool> checkAndPromptCompletion(
    BuildContext context,
    AuthService authService, {
    required String action, // e.g., "place your order" or "register your appliance"
  }) async {
    final userModel = await authService.getUserModel();
    
    if (isProfileComplete(userModel)) {
      return true; // Profile is already complete
    }

    // Show profile completion dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProfileCompletionDialog(
        user: userModel,
        action: action,
      ),
    );

    return result ?? false;
  }
}

class _ProfileCompletionDialog extends StatefulWidget {
  final UserModel? user;
  final String action;

  const _ProfileCompletionDialog({
    required this.user,
    required this.action,
  });

  @override
  State<_ProfileCompletionDialog> createState() => _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<_ProfileCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user?.displayName != 'User' && widget.user?.displayName != 'New User'
          ? widget.user?.displayName
          : '',
    );
    _emailController = TextEditingController(text: widget.user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.updateUserProfile(
        displayName: _nameController.text.trim(),
      );
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppTheme.warning,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Complete Your Profile',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please complete your profile to ${widget.action}. This helps us serve you better.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email (Optional)',
                hintText: 'For order receipts & updates',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Phone: ${widget.user?.phone ?? 'Verified'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.success,
                  ),
                ),
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppTheme.success,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Skip for Now'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & Continue'),
        ),
      ],
    );
  }
}
