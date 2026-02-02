import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/agent_model.dart';
import '../../services/firestore_service.dart';

class AgentsManagementScreen extends StatelessWidget {
  const AgentsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Management')),
      body: StreamBuilder<List<AgentModel>>(
        stream: firestoreService.getAllAgents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final agents = snapshot.data ?? [];

          if (agents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 80,
                    color: AppTheme.textSecondary(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Agents Yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first service agent',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              return _AgentCard(agent: agent);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAgentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Agent'),
      ),
    );
  }

  void _showAgentDialog(BuildContext context, [AgentModel? agent]) {
    showDialog(
      context: context,
      builder: (context) => _AgentFormDialog(agent: agent),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentModel agent;

  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor:
              agent.isActive
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          child: Icon(
            Icons.person,
            color: agent.isActive ? AppTheme.primary : Colors.grey,
          ),
        ),
        title: Text(
          agent.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 14,
                  color: AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 4),
                Text(agent.phone),
              ],
            ),
            if (agent.specialization != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.work,
                    size: 14,
                    color: AppTheme.textSecondary(context),
                  ),
                  const SizedBox(width: 4),
                  Text(agent.specialization!),
                ],
              ),
            ],
            if (agent.lastAssignedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last assigned: ${DateFormat('MMM d, yyyy').format(agent.lastAssignedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        agent.isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(agent.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                _showAgentDialog(context, agent);
                break;
              case 'toggle':
                await firestoreService.toggleAgentStatus(
                  agent.id,
                  !agent.isActive,
                );
                break;
              case 'delete':
                _showDeleteConfirmation(context, agent);
                break;
            }
          },
        ),
      ),
    );
  }

  void _showAgentDialog(BuildContext context, AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => _AgentFormDialog(agent: agent),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AgentModel agent) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Agent'),
            content: Text('Are you sure you want to delete ${agent.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final firestoreService = context.read<FirestoreService>();
                  await firestoreService.deleteAgent(agent.id);
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

class _AgentFormDialog extends StatefulWidget {
  final AgentModel? agent;

  const _AgentFormDialog({this.agent});

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _emailController;
  late final TextEditingController _specializationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agent?.name);
    _phoneController = TextEditingController(text: widget.agent?.phone);
    _addressController = TextEditingController(text: widget.agent?.address);
    _emailController = TextEditingController(text: widget.agent?.email);
    _specializationController = TextEditingController(
      text: widget.agent?.specialization,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.agent == null ? 'Add Agent' : 'Edit Agent'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '919876543210',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization (Optional)',
                  prefixIcon: Icon(Icons.work),
                  hintText: 'e.g., Water Heater Expert',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveAgent, child: const Text('Save')),
      ],
    );
  }

  Future<void> _saveAgent() async {
    if (!_formKey.currentState!.validate()) return;

    final firestoreService = context.read<FirestoreService>();

    if (widget.agent == null) {
      // Add new agent
      final agent = AgentModel(
        id: '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        specialization:
            _specializationController.text.trim().isEmpty
                ? null
                : _specializationController.text.trim(),
        createdAt: DateTime.now(),
      );
      await firestoreService.addAgent(agent);
    } else {
      // Update existing agent
      final updatedAgent = widget.agent!.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        specialization:
            _specializationController.text.trim().isEmpty
                ? null
                : _specializationController.text.trim(),
      );
      await firestoreService.updateAgent(updatedAgent);
    }

    if (mounted) Navigator.pop(context);
  }
}
