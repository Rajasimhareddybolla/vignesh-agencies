import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove any non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Add India country code if not present
    if (digits.length == 10) {
      return '+91$digits';
    } else if (digits.startsWith('91') && digits.length == 12) {
      return '+$digits';
    }
    return '+$digits';
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());

    // Skip Firebase OTP verification - go directly to OTP screen
    // User can enter 123456 to bypass OTP verification
    setState(() => _isLoading = false);
    context.pushNamed(
      'otp',
      queryParameters: {'vid': 'bypass-mode'},
      extra: phoneNumber,
    );

    // Show hint to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enter OTP: 123456 to continue'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo with gradient glow
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.25),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      color: Colors.white,
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuAFPuIQA5eAMCC5c8brWDu54LAH0blEDHaFQhIYQwYPmSPBGtx7HFKDb8SkfxF8VbFflF-S782oppfLJSw0okrYiIEJqZkJb8oE3UQemIIfuJVWbEWqFMVj1k6MPSLnQ8b40tnRU31Av046R4aFxmhMZ2xBKg4oJbDIptfsU8YzfT7YqNbaitvsDplIdnp0ULqB6O2ZTPR1hwbbUrt_d3nl4VyaIFgxG2LiVaySeNIlXY0O3q9hfN0N2FxAelS0MPrYkw9p0FlqQNI',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryLight,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.home_repair_service,
                              size: 64,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Title
                Text(
                  'District Service Hub',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Service management made simple',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Phone Number Input
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: 'Enter your 10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone_android),
                          prefixText: '+91 ',
                          prefixStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your mobile number';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10) {
                            return 'Please enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Send OTP Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendOTP,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send, size: 20),
                                    SizedBox(width: 8),
                                    Text('Send OTP'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Divider with "or"
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24),

                // Admin Login Link
                TextButton(
                  onPressed: () => context.pushNamed('admin-login'),
                  child: Text(
                    'Admin Login',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                  ),
                ),

                const SizedBox(height: 60),

                // Footer
                Text(
                  'POWERED BY V-GUARD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    color: AppTheme.textSecondaryLight.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
