import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../data/app_state.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController(text: 'Bolzano');
  bool _private = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    final group = context.read<AppState>().createGroup(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty
          ? 'A new PaceMatch group'
          : _description.text.trim(),
      location: _location.text.trim().isEmpty
          ? 'South Tyrol'
          : _location.text.trim(),
      isPrivate: _private,
    );
    context.go('/groups/${group.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: AdaptiveBody(
        maxWidth: AppLayout.formMaxWidth,
        child: ListView(
          padding: AppLayout.pagePadding(context, top: 16, extraBottom: 12),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private group'),
              subtitle: const Text('New members need approval (demo only)'),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Create group')),
          ],
        ),
      ),
    );
  }
}
