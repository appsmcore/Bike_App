import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
import '../../features/rides/route_planner_screen.dart';
import '../../shared/widgets/ride_card.dart';
import '../../shared/widgets/rides_map_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _mapMode = false;

  Future<void> _planRouteThenOffer() async {
    final planned = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(builder: (_) => const RoutePlannerScreen()),
    );
    if (planned == null || !mounted) return;
    context.push('/create-ride', extra: planned);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final rides = state.recommendedRides;

    return Scaffold(
      floatingActionButton: _mapMode
          ? FloatingActionButton.extended(
              onPressed: _planRouteThenOffer,
              icon: const Icon(Icons.route),
              label: const Text('Plan route'),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push('/create-ride'),
              icon: const Icon(Icons.add_road),
              label: const Text('Offer a ride'),
            ),
      body: SafeArea(
        child: AdaptiveBody(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageGutter(context),
                    12,
                    AppLayout.pageGutter(context),
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PaceMatch',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Toggle theme',
                            onPressed: state.toggleTheme,
                            icon: const Icon(Icons.brightness_6_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recommended rides',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your groups first · ${state.profile.fitnessLevel.fullLabel}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('List'),
                            icon: Icon(Icons.view_agenda_outlined),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Map'),
                            icon: Icon(Icons.map_outlined),
                          ),
                        ],
                        selected: {_mapMode},
                        onSelectionChanged: (s) =>
                            setState(() => _mapMode = s.first),
                      ),
                      if (_mapMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Pins = start · Color = difficulty · Plan route to set path & climb',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        RidesMapView(
                          rides: rides,
                          height: 340,
                          onRideTap: (ride) =>
                              context.push('/home/ride/${ride.id}'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final d in Difficulty.values)
                              Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: d.color,
                                  radius: 6,
                                ),
                                label: Text(d.label),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_mapMode)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageGutter(context),
                    12,
                    AppLayout.pageGutter(context),
                    88,
                  ),
                  sliver: SliverList.separated(
                    itemCount: rides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      final mine = state.isMemberOf(ride.groupId);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mine &&
                              (index == 0 ||
                                  !state.isMemberOf(rides[index - 1].groupId)))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'From your groups',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.forest,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (!mine &&
                              index > 0 &&
                              state.isMemberOf(rides[index - 1].groupId) &&
                              !state.isMemberOf(ride.groupId))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                'More rides nearby',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          RideCard(
                            ride: ride,
                            rsvp: state.rsvpFor(ride.id),
                            onOpen: () => context.push('/home/ride/${ride.id}'),
                            onRsvp: (status) {
                              state.setRsvp(ride.id, status);
                              final msg = switch (status) {
                                RsvpStatus.joined => 'Joined ${ride.title}',
                                RsvpStatus.maybe => 'Marked Maybe',
                                RsvpStatus.declined => 'Declined',
                                RsvpStatus.none => 'RSVP cleared',
                              };
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(milliseconds: 1200),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageGutter(context),
                    8,
                    AppLayout.pageGutter(context),
                    88,
                  ),
                  sliver: SliverList.separated(
                    itemCount: rides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: ride.difficulty.color,
                          child: Icon(
                            ride.bikeType.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(ride.title),
                        subtitle: Text(
                          '${ride.bikeType.label} · ${ride.distanceKm.toInt()} km · ${ride.meetingPoint}',
                        ),
                        onTap: () => context.push('/home/ride/${ride.id}'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
