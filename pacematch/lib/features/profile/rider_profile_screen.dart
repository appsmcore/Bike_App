import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/rider_widgets.dart';

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key, required this.riderId});

  final String riderId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rider = state.riderById(riderId);
    final theme = Theme.of(context);
    final isYou = riderId == state.currentUserId;

    if (rider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rider')),
        body: const Center(child: Text('Rider not found')),
      );
    }

    final shared = isYou ? const <Ride>[] : state.sharedPastRidesWith(riderId);
    final sharedKm =
        shared.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final sharedElev =
        shared.fold<int>(0, (sum, r) => sum + r.elevationM);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                rider.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      rider.accentColor,
                      rider.accentColor.withValues(alpha: 0.65),
                      AppColors.forestDeep,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 48),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    rider.tagline ?? rider.fitnessLevel.funLabel,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RiderAvatar(rider: rider, radius: 36, showRing: isYou),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rider.location, style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 4),
                            Text(
                              rider.fitnessLevel.fullLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.forest,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(rider.bio, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final bike in rider.bikeTypes)
                        Chip(
                          avatar: Icon(bike.icon, size: 16),
                          label: Text(bike.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Stats', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat('Joined', '${rider.ridesJoined}'),
                      const SizedBox(width: 10),
                      _MiniStat('Hosted', '${rider.ridesOrganized}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniStat('Reliability', '${rider.reliabilityScore}'),
                      const SizedBox(width: 10),
                      _MiniStat('Community', '${rider.communityScore}'),
                    ],
                  ),
                  if (!isYou && shared.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('Together with you', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '${shared.length} shared rides · ${sharedKm.round()} km · $sharedElev m elev',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (final ride in shared.take(5)) ...[
                      CompactRideTile(ride: ride),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Text('Badges', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final badge in rider.badges)
                        Chip(
                          avatar: const Icon(
                            Icons.military_tech_outlined,
                            size: 18,
                          ),
                          label: Text(badge),
                        ),
                    ],
                  ),
                  if (isYou) ...[
                    const SizedBox(height: 28),
                    FilledButton.tonal(
                      onPressed: () => context.go('/profile'),
                      child: const Text('Back to your profile'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
