import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import 'rides_map_view.dart';

class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.ride,
    required this.rsvp,
    required this.onOpen,
    required this.onRsvp,
  });

  final Ride ride;
  final RsvpStatus rsvp;
  final VoidCallback onOpen;
  final ValueChanged<RsvpStatus> onRsvp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bikeColor = ride.bikeType.color;
    final timeLabel = DateFormat('HH:mm').format(ride.startsAt);
    final spotsLeft = (ride.riderLimit - ride.participants).clamp(0, 999);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 7, color: bikeColor),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 148,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RideCardMapCover(ride: ride, height: 148),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.12),
                                  Colors.black.withValues(alpha: 0.45),
                                  bikeColor.withValues(alpha: 0.92),
                                ],
                                stops: const [0.0, 0.42, 1.0],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _BikeTypeBadge(bikeType: ride.bikeType),
                                    const SizedBox(width: 8),
                                    _DifficultyBadge(
                                      difficulty: ride.difficulty,
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  ride.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ride.groupName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: bikeColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (spotsLeft <= 3 && spotsLeft > 0)
                                Text(
                                  '$spotsLeft spots left',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFFC62828),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ride.meetingPoint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.stone,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Skill · ${ride.skillLevel.label}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.stone,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _Stat(
                                icon: Icons.route,
                                label: '${ride.distanceKm.toInt()} km',
                              ),
                              _Stat(
                                icon: Icons.terrain,
                                label: '${ride.elevationM} m',
                              ),
                              _Stat(
                                icon: Icons.groups,
                                label:
                                    '${ride.participants}/${ride.riderLimit}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RsvpButtonRow(current: rsvp, onChanged: onRsvp),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});
  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: difficulty.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(difficulty.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            difficulty.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BikeTypeBadge extends StatelessWidget {
  const _BikeTypeBadge({required this.bikeType});
  final BikeType bikeType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bikeType.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: bikeType.color.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bikeType.icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            bikeType.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class RsvpButtonRow extends StatelessWidget {
  const RsvpButtonRow({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final RsvpStatus current;
  final ValueChanged<RsvpStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RsvpChip(
            label: 'Join',
            selected: current == RsvpStatus.joined,
            color: AppColors.forest,
            onTap: () => onChanged(
              current == RsvpStatus.joined ? RsvpStatus.none : RsvpStatus.joined,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RsvpChip(
            label: 'Maybe',
            selected: current == RsvpStatus.maybe,
            color: const Color(0xFFC48A2A),
            onTap: () => onChanged(
              current == RsvpStatus.maybe ? RsvpStatus.none : RsvpStatus.maybe,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RsvpChip(
            label: 'Decline',
            selected: current == RsvpStatus.declined,
            color: const Color(0xFF8B4B4B),
            onTap: () => onChanged(
              current == RsvpStatus.declined
                  ? RsvpStatus.none
                  : RsvpStatus.declined,
            ),
          ),
        ),
      ],
    );
  }
}

class _RsvpChip extends StatelessWidget {
  const _RsvpChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.stone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
