import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../models/referral_model.dart';

/// A reusable status badge widget that displays product, service request, or referral status
/// with consistent styling across the app.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  /// Factory constructor for ProductStatus
  factory StatusBadge.productStatus(
    ProductStatus status, {
    bool isExpiringSoon = false,
  }) {
    Color bg;
    Color text;
    IconData? icon;
    String label;

    switch (status) {
      case ProductStatus.active:
        if (isExpiringSoon) {
          bg = AppTheme.warningLight;
          text = AppTheme.warning;
          icon = Icons.warning;
          label = 'Expiring Soon';
        } else {
          bg = AppTheme.successLight;
          text = AppTheme.success;
          label = 'Active Warranty';
        }
        break;
      case ProductStatus.pendingValidation:
        bg = AppTheme.primary.withAlpha(25);
        text = AppTheme.primary;
        icon = Icons.hourglass_empty;
        label = 'Pending Validation';
        break;
      case ProductStatus.expired:
        bg = AppTheme.neutralLight;
        text = AppTheme.neutral;
        icon = Icons.history;
        label = 'Warranty Expired';
        break;
      case ProductStatus.rejected:
        bg = AppTheme.errorLight;
        text = AppTheme.error;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      default:
        bg = AppTheme.neutralLight;
        text = AppTheme.neutral;
        label = status.displayName;
    }

    return StatusBadge(
      text: label,
      backgroundColor: bg,
      textColor: text,
      icon: icon,
    );
  }

  /// Factory constructor for ServiceRequestStatus
  factory StatusBadge.serviceStatus(ServiceRequestStatus status) {
    Color bg;
    Color text;
    IconData? icon;

    switch (status) {
      case ServiceRequestStatus.pending:
        bg = AppTheme.warningLight;
        text = AppTheme.warning;
        icon = Icons.schedule;
        break;
      case ServiceRequestStatus.assigned:
        bg = AppTheme.primary.withAlpha(25);
        text = AppTheme.primary;
        icon = Icons.person_outline;
        break;
      case ServiceRequestStatus.inProgress:
        bg = AppTheme.primary.withAlpha(38);
        text = AppTheme.primaryDark;
        icon = Icons.build_circle_outlined;
        break;
      case ServiceRequestStatus.resolved:
        bg = AppTheme.successLight;
        text = AppTheme.success;
        icon = Icons.check_circle_outline;
        break;
      case ServiceRequestStatus.completed:
        bg = AppTheme.success;
        text = Colors.white;
        icon = Icons.verified;
        break;
      case ServiceRequestStatus.escalated:
        bg = AppTheme.errorLight;
        text = AppTheme.error;
        icon = Icons.priority_high;
        break;
      case ServiceRequestStatus.cancelled:
        bg = AppTheme.neutralLight;
        text = AppTheme.neutral;
        icon = Icons.cancel_outlined;
        break;
    }

    return StatusBadge(
      text: status.displayName,
      backgroundColor: bg,
      textColor: text,
      icon: icon,
    );
  }

  /// Factory constructor for ReferralStatus
  factory StatusBadge.referralStatus(ReferralStatus status) {
    Color bg;
    Color text;

    switch (status) {
      case ReferralStatus.pending:
        bg = AppTheme.warningLight;
        text = AppTheme.warning;
        break;
      case ReferralStatus.approved:
        bg = Colors.blue.withOpacity(0.1);
        text = Colors.blue;
        break;
      case ReferralStatus.purchased:
        bg = AppTheme.successLight;
        text = AppTheme.success;
        break;
      case ReferralStatus.paid:
        bg = AppTheme.primary.withAlpha(25);
        text = AppTheme.primary;
        break;
    }

    return StatusBadge(
      text: status.displayName,
      backgroundColor: bg,
      textColor: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
