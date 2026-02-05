import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

class AdminFeedbackScreen extends StatelessWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('User Feedback')),
      body: StreamBuilder<List<ServiceRequestModel>>(
        stream: firestoreService.getAllServiceRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allRequests = snapshot.data ?? [];
          // Filter requests that have a rating
          final feedbackRequests =
              allRequests.where((r) => r.rating != null).toList();

          // Sort by feedback submission date if available, else recently modified
          feedbackRequests.sort((a, b) {
            final aTime = a.feedbackSubmittedAt ?? a.completedAt ?? a.createdAt;
            final bTime = b.feedbackSubmittedAt ?? b.completedAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });

          if (feedbackRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: AppTheme.textSecondary(context).withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No feedback received yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feedbackRequests.length,
            itemBuilder: (context, index) {
              final request = feedbackRequests[index];
              return _FeedbackCard(request: request);
            },
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _FeedbackCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                request.ticketNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStarRating(request.rating ?? 0),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.feedbackComment ?? 'No comment provided.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person,
                size: 14,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Text(
                request.customerName ?? 'Unknown User',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.calendar_today,
                size: 14,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Text(
                request.feedbackSubmittedAt != null
                    ? DateFormat(
                      'MMM d, yyyy',
                    ).format(request.feedbackSubmittedAt!)
                    : 'N/A',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }
}
