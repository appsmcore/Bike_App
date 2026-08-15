import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final group = state.groupById(groupId);
    final theme = Theme.of(context);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Group not found')),
      );
    }

    final member = state.isMemberOf(group.id);
    final rides = group.upcomingRideIds
        .map(state.rideById)
        .whereType<Ride>()
        .toList();
    final latest = state.latestMessageForGroup(group.id);
    final latestSender =
        latest == null ? null : state.riderById(latest.senderId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(group.name),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: group.coverGradient),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Text(
                    '${group.memberCount} members · ${group.location}'
                    '${group.isPrivate ? ' · Private' : ''}',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => state.toggleGroupMembership(group.id),
                    child: Text(member ? 'Leave group' : 'Join group'),
                  ),
                  if (member) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/create-ride?groupId=${group.id}',
                      ),
                      icon: const Icon(Icons.add_road),
                      label: const Text('Offer a ride in this group'),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text('Group chat', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Material(
                    color: theme.cardTheme.color ??
                        (theme.brightness == Brightness.dark
                            ? AppColors.cardDark
                            : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/groups/${group.id}/chat'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.forest.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member ? 'Open group chat' : 'Preview chat',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    !member
                                        ? 'Join to read and send messages'
                                        : latest == null
                                            ? 'No messages yet — say hi'
                                            : '${latestSender?.name ?? 'Rider'}: ${latest.body}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.stone,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Upcoming rides', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  if (rides.isEmpty)
                    const Text('No upcoming rides yet.')
                  else
                    ...rides.map((ride) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ride.title),
                        subtitle: Text(
                          '${DateFormat('EEE, MMM d · HH:mm').format(ride.startsAt)} · '
                          '${ride.distanceKm.toInt()} km',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/home/ride/${ride.id}'),
                      );
                    }),
                  const SizedBox(height: 24),
                  Text('Members', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Member list placeholder — Alex, Giulia, Marco, Sara…',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
