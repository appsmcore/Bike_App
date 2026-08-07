import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

class RiderAvatar extends StatelessWidget {
  const RiderAvatar({
    super.key,
    required this.rider,
    this.radius = 22,
    this.showRing = false,
  });

  final RiderProfile rider;
  final double radius;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: rider.accentColor,
      child: Text(
        rider.initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );

    if (!showRing) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lime, width: 2),
      ),
      child: avatar,
    );
  }
}

class RiderTile extends StatelessWidget {
  const RiderTile({
    super.key,
    required this.rider,
    this.subtitle,
    this.trailing,
    this.isOrganizer = false,
    this.isYou = false,
    this.onTap,
  });

  final RiderProfile rider;
  final String? subtitle;
  final Widget? trailing;
  final bool isOrganizer;
  final bool isYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = <String>[
      if (isYou) 'You',
      if (isOrganizer) 'Host',
      if (rider.tagline != null && !isYou) rider.tagline!,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: RiderAvatar(rider: rider, showRing: isYou),
      title: Text(
        rider.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty)
            Text(
              tags.join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            subtitle ??
                '${rider.fitnessLevel.label} · ${rider.location}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
    );
  }
}

class CompactRideTile extends StatelessWidget {
  const CompactRideTile({
    super.key,
    required this.ride,
    this.badge,
    this.onTap,
  });

  final Ride ride;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push('/home/ride/${ride.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: ride.coverGradient),
                ),
                child: Icon(ride.bikeType.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ride.distanceKm.toInt()} km · ${ride.elevationM} m · ${ride.groupName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(badge!, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
