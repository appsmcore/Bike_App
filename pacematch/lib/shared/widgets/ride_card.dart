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
    final dateLabel = DateFormat('EEE, MMM d · HH:mm').format(ride.startsAt);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RideCardMapCover(ride: ride, height: 168),
                  // Readable text over map tiles
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.55),
                          (ride.coverGradient.last).withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill(text: ride.bikeType.label),
                            const SizedBox(width: 8),
                            _Pill(
                              text:
                                  '${ride.difficulty.emoji} ${ride.difficulty.label}',
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          ride.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.groupName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
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
                        label: '${ride.participants}/${ride.riderLimit}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RsvpButtonRow(current: rsvp, onChanged: onRsvp),
                ],
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
