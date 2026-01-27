import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../models/promo_notification_model.dart';
import '../../services/notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _discountController = TextEditingController();
  final _notificationService = NotificationService();

  String _selectedType = 'offer';
  bool _isSending = false;
  late AnimationController _headerController;

  final List<Map<String, dynamic>> _templates = [
    {
      'name': '🪔 Diwali Offer',
      'type': 'festival',
      'title': '🪔 Happy Diwali! Special Offer',
      'body':
          'Celebrate with 20% OFF on all Vignesh Agencies products! Limited time offer.',
      'discount': 20.0,
    },
    {
      'name': '🎄 Christmas Sale',
      'type': 'festival',
      'title': '🎄 Christmas Special Sale!',
      'body':
          'Celebrate the season with 15% OFF on all products. Merry Christmas!',
      'discount': 15.0,
    },
    {
      'name': '🔧 Service Reminder',
      'type': 'reminder',
      'title': '🔧 Service Reminder',
      'body':
          'Your appliance is due for routine maintenance. Book a service now!',
      'discount': null,
    },
    {
      'name': '⚠️ Warranty Expiry',
      'type': 'reminder',
      'title': '⚠️ Warranty Expiring Soon',
      'body': 'Your product warranty is expiring soon. Renew now and save 15%!',
      'discount': 15.0,
    },
    {
      'name': '🆕 New Product',
      'type': 'announcement',
      'title': '🆕 New Product Launch!',
      'body': 'Check out our new range of energy-efficient appliances.',
      'discount': null,
    },
    {
      'name': '💰 Flash Sale',
      'type': 'offer',
      'title': '💰 Flash Sale - 24 Hours Only!',
      'body': 'Hurry! Get 25% OFF on all products. Offer ends tonight!',
      'discount': 25.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _discountController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  void _applyTemplate(Map<String, dynamic> template) {
    HapticFeedback.selectionClick();
    setState(() {
      _titleController.text = template['title'];
      _bodyController.text = template['body'];
      _selectedType = template['type'];
      if (template['discount'] != null) {
        _discountController.text = template['discount'].toString();
      } else {
        _discountController.clear();
      }
    });
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      final notification = PromoNotification(
        id: '',
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        type: _selectedType,
        discountPercent:
            _discountController.text.isNotEmpty
                ? double.tryParse(_discountController.text)
                : null,
        createdAt: DateTime.now(),
        // Ensure broadcast notifications don't have specific targets (null implies all)
        targetUserIds: null,
      );

      await _notificationService.sendPromoNotification(notification);

      if (!mounted) return;

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Notification sent to all Vignesh Agencies users!'),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Clear form
      _titleController.clear();
      _bodyController.clear();
      _discountController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerController,
              child: _buildHeader(context),
            ),
          ),

          // Templates
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Quick Templates',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_templates.length}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _TemplateChip(
                            label: template['name'],
                            onTap: () => _applyTemplate(template),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Form
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose Notification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _TypeButton(
                            label: 'Offer',
                            icon: Icons.local_offer,
                            isSelected: _selectedType == 'offer',
                            onTap:
                                () => setState(() => _selectedType = 'offer'),
                          ),
                          _TypeButton(
                            label: 'Festival',
                            icon: Icons.celebration,
                            isSelected: _selectedType == 'festival',
                            onTap:
                                () =>
                                    setState(() => _selectedType = 'festival'),
                          ),
                          _TypeButton(
                            label: 'Reminder',
                            icon: Icons.notifications_active,
                            isSelected: _selectedType == 'reminder',
                            onTap:
                                () =>
                                    setState(() => _selectedType = 'reminder'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title Field
                    _PremiumTextField(
                      controller: _titleController,
                      label: 'Notification Title',
                      hint: 'e.g., 🪔 Diwali Special Offer!',
                      icon: Icons.title,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),

                    const SizedBox(height: 16),

                    // Body Field
                    _PremiumTextField(
                      controller: _bodyController,
                      label: 'Notification Body',
                      hint: 'Enter the notification message...',
                      icon: Icons.message,
                      maxLines: 3,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),

                    const SizedBox(height: 16),

                    // Discount Field
                    _PremiumTextField(
                      controller: _discountController,
                      label: 'Discount % (Optional)',
                      hint: 'e.g., 20',
                      icon: Icons.percent,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 32),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: _PremiumSendButton(
                        isLoading: _isSending,
                        onPressed: _sendNotification,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(gradient: AppTheme.adminGradient),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Notification',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Broadcast promotional offers to all users',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      isSelected ? Colors.white : AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textSecondaryLight),
            filled: true,
            fillColor: AppTheme.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumSendButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _PremiumSendButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isLoading
                    ? [
                      AppTheme.accent1.withAlpha(150),
                      AppTheme.primary.withAlpha(150),
                    ]
                    : [AppTheme.accent1, AppTheme.primary],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isLoading
                  ? []
                  : [
                    BoxShadow(
                      color: AppTheme.accent1.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
        ),
        child: Center(
          child:
              isLoading
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Send to All Users',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
