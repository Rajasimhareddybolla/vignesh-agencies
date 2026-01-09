import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onOTPDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_otp.length == 6) {
      _verifyOTP();
    }
  }

  void _onKeyPressed(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    if (_otp.length != 6) {
      setState(() => _errorMessage = 'Please enter complete OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();

      // Try bypass OTP first (accepts 123456 for any phone)
      final bypassSuccess = await authService.bypassOTPVerification(
        phoneNumber: widget.phoneNumber,
        otp: _otp,
      );

      if (bypassSuccess) {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      // If bypass failed (wrong OTP), try Firebase verification as fallback
      await authService.verifyOTP(
        verificationId: widget.verificationId,
        otp: _otp,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid OTP. Please enter 123456 to continue.';
      });
      // Clear OTP fields
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    await authService.sendOTP(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        _startResendTimer();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('OTP sent successfully!')));
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
      onAutoVerify: (credential) async {
        try {
          await authService.verifyOTP(
            verificationId: '',
            otp: credential.smsCode ?? '',
          );
          if (mounted) {
            context.go('/home');
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Verify OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Subtitle with phone number
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48,
                    height: 56,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 8,
                      right: index == 2 ? 16 : 0,
                    ),
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyPressed(event, index),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onOTPDigitChanged(value, index),
                      ),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.error),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
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
                      : const Text('Verify OTP'),
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: _resendCountdown == 0 ? _resendOTP : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend in ${_resendCountdown}s'
                          : 'Resend OTP',
                      style: TextStyle(
                        color: _resendCountdown > 0
                            ? AppTheme.textSecondaryLight
                            : AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
