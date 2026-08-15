import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/elevation_profile_chart.dart';
import '../../shared/widgets/ride_card.dart';
import '../../shared/widgets/ride_memories.dart';
import '../../shared/widgets/rider_widgets.dart';
import '../../shared/widgets/rides_map_view.dart';

class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ride = state.rideById(rideId);
    final theme = Theme.of(context);

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride')),
        body: const Center(child: Text('Ride not found')),
      );
    }

    final rsvp = state.rsvpFor(ride.id);
    final fromMyGroup = state.isMemberOf(ride.groupId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 16,
                end: 16,
              ),
              title: Text(
                ride.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: ride.coverGradient,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 52),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '${ride.difficulty.emoji} ${ride.difficulty.label} · ${ride.bikeType.label}',
                    style: const TextStyle(color: Colors.white70),
                  ),
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
                  if (fromMyGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Chip(
                        avatar: const Icon(Icons.groups, size: 16),
                        label: const Text('From your group'),
                        backgroundColor:
                            AppColors.forest.withValues(alpha: 0.12),
                      ),
                    ),
                  Text(
                    DateFormat('EEEE, MMM d · HH:mm').format(ride.startsAt),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(ride.meetingPoint, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    ride.groupName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(ride.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip('${ride.distanceKm.toInt()} km'),
                      _InfoChip('${ride.elevationM} m elev'),
                      _InfoChip(ride.skillLevel.fullLabel),
                      _InfoChip(
                        '${ride.participants}/${ride.riderLimit} riders',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    ride.hasRoute ? 'Route' : 'Start location',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  RidesMapView(
                    rides: [ride],
                    height: ride.hasRoute ? 260 : 200,
                    onRideTap: (_) {},
                  ),
                  const SizedBox(height: 28),
                  ElevationProfileChart(
                    points: ride.elevationProfile,
                    climbM: ride.elevationM,
                    distanceKm: ride.distanceKm,
                  ),
                  const SizedBox(height: 28),
                  _RideMemoriesSection(ride: ride),
                  const SizedBox(height: 28),
                  Text('Your RSVP', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  RsvpButtonRow(
                    current: rsvp,
                    onChanged: (status) => state.setRsvp(ride.id, status),
                  ),
                  const SizedBox(height: 28),
                  _ConfirmedRidersSection(rideId: ride.id),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.push('/groups/${ride.groupId}'),
                    child: const Text('View group'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideMemoriesSection extends StatelessWidget {
  const _RideMemoriesSection({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final photos = state.photosForRide(ride.id);
    final canAdd = state.canAddPhotosToRide(ride.id);

    if (!ride.isPast && photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Ride memories', style: theme.textTheme.titleLarge),
            ),
            if (photos.isNotEmpty)
              Text(
                '${photos.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          canAdd
              ? 'Share a snapshot from the day — it lands on your profile feed.'
              : photos.isEmpty
                  ? 'Memories appear here after the ride.'
                  : 'Tap a photo to open the gallery.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (canAdd || photos.isNotEmpty)
          RideMemoriesStrip(
            photos: photos,
            onAddTap: canAdd
                ? () => showAddRidePhotosSheet(context, rideId: ride.id)
                : null,
          )
        else
          Text(
            'No photos for this ride yet.',
            style: theme.textTheme.bodyMedium,
          ),
        if (canAdd) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showAddRidePhotosSheet(context, rideId: ride.id),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(photos.isEmpty ? 'Add photos' : 'Add more photos'),
          ),
        ],
      ],
    );
  }
}

class _ConfirmedRidersSection extends StatelessWidget {
  const _ConfirmedRidersSection({required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final canSee = state.canSeeParticipants(rideId);
    final riders = state.confirmedRidersFor(rideId);
    final ride = state.rideById(rideId);
    final organizerId = ride?.organizerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text("Who's riding", style: theme.textTheme.titleLarge),
            ),
            if (canSee && riders.isNotEmpty)
              Text(
                '${riders.length} confirmed',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!canSee) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profiles unlock when you join',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirm with Join to see who’s coming and open their profiles.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ] else if (riders.isEmpty) ...[
          Text(
            'You’re the first one in — invite the crew.',
            style: theme.textTheme.bodyMedium,
          ),
        ] else ...[
          Text(
            'Tap a rider to open their profile.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final rider in riders)
            RiderTile(
              rider: rider,
              isYou: rider.id == state.currentUserId,
              isOrganizer: rider.id == organizerId,
              onTap: () => context.push('/profile/rider/${rider.id}'),
            ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
