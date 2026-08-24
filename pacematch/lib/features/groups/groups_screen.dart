import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../data/app_state.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.syncing
                ? null
                : () => context.read<AppState>().refreshSharedData(),
            icon: state.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-group'),
        icon: const Icon(Icons.group_add),
        label: const Text('New group'),
      ),
      body: AdaptiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<AppState>().refreshSharedData(),
          child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppLayout.pageGutter(context),
            8,
            AppLayout.pageGutter(context),
            88,
          ),
          itemCount: state.groups.isEmpty ? 1 : state.groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (state.groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  state.syncError != null
                      ? 'Could not load groups.\n${state.syncError}\n\n'
                          'Did you run the latest Supabase SQL migration?'
                      : state.usesBackendAuth
                          ? 'No shared groups yet.\nCreate a public group so friends can join.'
                          : 'No groups yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }
            final group = state.groups[index];
            final member = state.isMemberOf(group.id);
            return Material(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/groups/${group.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        gradient: LinearGradient(colors: group.coverGradient),
                      ),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        group.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${group.location} · ${group.memberCount} members'
                            '${group.isPrivate ? ' · Private' : ' · Public'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(group.description),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Chip(
                                label: Text(member ? 'Joined' : 'Not a member'),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
