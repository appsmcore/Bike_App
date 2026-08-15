import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/ride_memories.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickBikePhoto(BuildContext context, AppState state) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    state.setBikePhoto(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Featured bike photo updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addMemoryFromCompletedRide(BuildContext context) async {
    final state = context.read<AppState>();
    final rides = state.completedRides;
    if (rides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a ride first — memories unlock after you ride.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rideId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Which ride is this from?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final ride in rides.take(12))
                ListTile(
                  leading: Icon(ride.bikeType.icon, color: AppColors.forest),
                  title: Text(ride.title),
                  subtitle: Text(
                    '${ride.distanceKm.toInt()} km · ${ride.difficulty.label}',
                  ),
                  onTap: () => Navigator.pop(ctx, ride.id),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (rideId == null || !context.mounted) return;
    await showAddRidePhotosSheet(context, rideId: rideId);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final theme = Theme.of(context);
    final terrains = profile.preferredTerrains.map((t) => t.label).join(' · ');
    final memories = state.photosForUser(profile.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: state.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.forest,
                      backgroundImage: profile.bikePhotoBytes != null
                          ? MemoryImage(profile.bikePhotoBytes!)
                          : null,
                      child: profile.bikePhotoBytes == null
                          ? Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(profile.email),
                          Text(
                            profile.location,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _pickBikePhoto(context, state),
                    child: Text(
                      profile.bikePhotoBytes == null
                          ? 'Set featured bike photo'
                          : 'Change featured bike photo',
                    ),
                  ),
                ),
                Text(profile.bio),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ProfileMetric(
                      label: 'Rides',
                      value: '${profile.ridesJoined}',
                    ),
                    _ProfileMetric(
                      label: 'Memories',
                      value: '${memories.length}',
                    ),
                    _ProfileMetric(
                      label: 'Km',
                      value: '${state.lifetimeJoinedKm.round()}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ride memories',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add memory',
                      onPressed: () => _addMemoryFromCompletedRide(context),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      color: AppColors.forest,
                    ),
                  ],
                ),
                Text(
                  'Your post-ride gallery — tap a shot to open it.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (memories.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: RideMemoriesGrid(
                  photos: memories,
                  emptyTitle: 'Your gallery is empty',
                  emptySubtitle:
                      'After a ride, add photos from the ride page — or start here.',
                  onAddTap: () => _addMemoryFromCompletedRide(context),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = memories[index];
                    return RideMemoryThumb(
                      photo: photo,
                      onTap: () => openRideMemoryViewer(
                        context,
                        photos: memories,
                        initialIndex: index,
                      ),
                    );
                  },
                  childCount: memories.length,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('Fitness & bikes', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(profile.fitnessLevel.fullLabel)),
                    for (final bike in profile.bikeTypes)
                      Chip(
                        avatar: Icon(bike.icon, size: 16),
                        label: Text(bike.label),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance ${profile.preferredDistanceMin.toInt()}–${profile.preferredDistanceMax.toInt()} km\n'
                  'Elevation ${profile.preferredElevationMin}–${profile.preferredElevationMax} m\n'
                  'Terrain: $terrains\n'
                  'Days: ${profile.preferredDays.join(', ')}',
                ),
                const SizedBox(height: 24),
                Text('Your riding life', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _ProfileNavCard(
                  icon: Icons.history,
                  title: 'My rides',
                  subtitle:
                      '${state.completedRides.length} done · ${state.offeredRides.length} offered · ${state.upcomingJoinedRides.length} upcoming',
                  onTap: () => context.push('/profile/my-rides'),
                ),
                const SizedBox(height: 10),
                _ProfileNavCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Riding companions',
                  subtitle: () {
                    final top =
                        state.companionsRankedBy(CompanionRankMetric.sharedKm);
                    if (top.isEmpty) {
                      return 'Rank who you’ve shared the most km & climbs with';
                    }
                    return 'Top buddy: ${top.first.rider.name.split(' ').first}';
                  }(),
                  onTap: () => context.push('/profile/companions'),
                ),
                const SizedBox(height: 24),
                Text('Stats', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(label: 'Joined', value: '${profile.ridesJoined}'),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Organized',
                      value: '${profile.ridesOrganized}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard(
                      label: 'Reliability',
                      value: '${profile.reliabilityScore}',
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Community',
                      value: '${profile.communityScore}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard(
                      label: 'Lifetime km',
                      value: '${state.lifetimeJoinedKm.round()}',
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Lifetime elev',
                      value: '${state.lifetimeJoinedElevationM}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Badges', style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final badge in profile.badges)
                      Chip(
                        avatar:
                            const Icon(Icons.military_tech_outlined, size: 18),
                        label: Text(badge),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: state.logout,
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mock auth · Supabase wiring comes next',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProfileNavCard extends StatelessWidget {
  const _ProfileNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
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
                child: Icon(icon, color: AppColors.forest),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}
