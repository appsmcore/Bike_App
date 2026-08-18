import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/rider_widgets.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final completed = state.completedRides;
    final offered = state.offeredRides;
    final upcoming = state.upcomingJoinedRides;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My rides'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Completed'),
              Tab(text: 'Offered'),
              Tab(text: 'Upcoming'),
            ],
          ),
        ),
        body: AdaptiveBody(
          child: TabBarView(
            children: [
              _RideListTab(
                rides: completed,
                emptyTitle: 'No completed rides yet',
                emptyBody:
                    'Join a group ride and it’ll show up here after the start.',
                header: completed.isEmpty
                    ? null
                    : _HistoryHeader(
                        km: state.lifetimeJoinedKm,
                        elevationM: state.lifetimeJoinedElevationM,
                        rideCount: completed.length,
                      ),
                badgeFor: (ride) {
                  final n = state.photosForRide(ride.id).length;
                  final date = DateFormat('MMM d').format(ride.startsAt);
                  return n == 0 ? date : '$date · $n photos';
                },
              ),
              _RideListTab(
                rides: offered,
                emptyTitle: 'You haven’t offered a ride yet',
                emptyBody: 'Host a spin from Home → Offer a ride.',
                badgeFor: (ride) => ride.isPast ? 'Done' : 'Upcoming',
              ),
              _RideListTab(
                rides: upcoming,
                emptyTitle: 'Nothing confirmed yet',
                emptyBody: 'Hit Join on a ride to lock it into your calendar.',
                badgeFor: (ride) =>
                    DateFormat('EEE HH:mm').format(ride.startsAt),
              ),
            ],
          ),
        ),
        bottomNavigationBar: upcoming.isEmpty && completed.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Past rides unlock co-rider profiles and companion rankings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.stone,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.km,
    required this.elevationM,
    required this.rideCount,
  });

  final double km;
  final int elevationM;
  final int rideCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestDeep],
        ),
      ),
      child: Row(
        children:
            [
                  _HeroStat(label: 'Rides', value: '$rideCount'),
                  _HeroStat(label: 'Distance', value: '${km.round()} km'),
                  _HeroStat(label: 'Climb', value: '$elevationM m'),
                ]
                .map(
                  (w) => Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: Colors.white70,
                      ),
                      child: w,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(label),
      ],
    );
  }
}

class _RideListTab extends StatelessWidget {
  const _RideListTab({
    required this.rides,
    required this.emptyTitle,
    required this.emptyBody,
    required this.badgeFor,
    this.header,
  });

  final List<Ride> rides;
  final String emptyTitle;
  final String emptyBody;
  final String Function(Ride ride) badgeFor;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pedal_bike_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(emptyTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                emptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: AppLayout.pagePadding(context, top: 16, extraBottom: 16),
      children: [
        if (header != null) header!,
        for (final ride in rides) ...[
          CompactRideTile(ride: ride, badge: badgeFor(ride)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
