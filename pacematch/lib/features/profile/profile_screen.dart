import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

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
          content: Text('Bike / ride photo updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final theme = Theme.of(context);
    final terrains = profile.preferredTerrains.map((t) => t.label).join(' · ');

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.forest,
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: theme.textTheme.headlineSmall),
                    Text(profile.email),
                    Text(profile.location, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(profile.bio),
          const SizedBox(height: 24),
          Text('Your bike / ride photo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Upload a photo of your bike — or you on the bike.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Material(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _pickBikePhoto(context, state),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outline),
                    image: profile.bikePhotoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(profile.bikePhotoBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profile.bikePhotoBytes == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 36),
                              SizedBox(height: 8),
                              Text('Tap to upload'),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: FilledButton.tonal(
                              onPressed: () => _pickBikePhoto(context, state),
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (profile.bikePhotoBytes != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => state.setBikePhoto(null),
              child: const Text('Remove photo'),
            ),
          ],
          const SizedBox(height: 24),
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
          Text('Stats', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(label: 'Joined', value: '${profile.ridesJoined}'),
              const SizedBox(width: 10),
              _StatCard(label: 'Organized', value: '${profile.ridesOrganized}'),
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
          const SizedBox(height: 24),
          Text('Badges', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final badge in profile.badges)
                Chip(
                  avatar: const Icon(Icons.military_tech_outlined, size: 18),
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
        ],
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
