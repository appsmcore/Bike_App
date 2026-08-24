import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
import '../../features/rides/route_planner_screen.dart';
import '../../shared/widgets/ride_card.dart';
import '../../shared/widgets/rides_map_view.dart';

enum _DistanceBand { any, short, medium, long }

enum _ElevationBand { any, flat, rolling, alpine }

enum _WhenBand { any, today, tomorrow, weekend }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _mapMode = false;
  final Set<BikeType> _bikeFilters = {};
  Difficulty? _difficulty;
  _DistanceBand _distance = _DistanceBand.any;
  _ElevationBand _elevation = _ElevationBand.any;
  _WhenBand _when = _WhenBand.any;
  bool _myGroupsOnly = false;
  bool _fitForYou = false;
  bool _spotsLeftOnly = false;

  int get _activeFilterCount {
    var n = _bikeFilters.length;
    if (_difficulty != null) n++;
    if (_distance != _DistanceBand.any) n++;
    if (_elevation != _ElevationBand.any) n++;
    if (_when != _WhenBand.any) n++;
    if (_myGroupsOnly) n++;
    if (_fitForYou) n++;
    if (_spotsLeftOnly) n++;
    return n;
  }

  bool get _hasFilters => _activeFilterCount > 0;

  void _clearFilters() {
    setState(() {
      _bikeFilters.clear();
      _difficulty = null;
      _distance = _DistanceBand.any;
      _elevation = _ElevationBand.any;
      _when = _WhenBand.any;
      _myGroupsOnly = false;
      _fitForYou = false;
      _spotsLeftOnly = false;
    });
  }

  void _toggleBike(BikeType type) {
    setState(() {
      if (_bikeFilters.contains(type)) {
        _bikeFilters.remove(type);
      } else {
        _bikeFilters.add(type);
      }
    });
  }

  List<Ride> _applyFilters(AppState state, List<Ride> source) {
    final profile = state.profile;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return source.where((ride) {
      if (_bikeFilters.isNotEmpty && !_bikeFilters.contains(ride.bikeType)) {
        return false;
      }
      if (_difficulty != null && ride.difficulty != _difficulty) return false;
      if (_myGroupsOnly && !state.isMemberOf(ride.groupId)) return false;
      if (_spotsLeftOnly && ride.participants >= ride.riderLimit) return false;

      switch (_distance) {
        case _DistanceBand.any:
          break;
        case _DistanceBand.short:
          if (ride.distanceKm >= 40) return false;
        case _DistanceBand.medium:
          if (ride.distanceKm < 40 || ride.distanceKm > 80) return false;
        case _DistanceBand.long:
          if (ride.distanceKm <= 80) return false;
      }

      switch (_elevation) {
        case _ElevationBand.any:
          break;
        case _ElevationBand.flat:
          if (ride.elevationM >= 500) return false;
        case _ElevationBand.rolling:
          if (ride.elevationM < 500 || ride.elevationM > 1500) return false;
        case _ElevationBand.alpine:
          if (ride.elevationM <= 1500) return false;
      }

      final day = DateTime(
        ride.startsAt.year,
        ride.startsAt.month,
        ride.startsAt.day,
      );
      switch (_when) {
        case _WhenBand.any:
          break;
        case _WhenBand.today:
          if (day != today) return false;
        case _WhenBand.tomorrow:
          if (day != tomorrow) return false;
        case _WhenBand.weekend:
          final wd = ride.startsAt.weekday;
          if (wd != DateTime.saturday && wd != DateTime.sunday) return false;
      }

      if (_fitForYou) {
        final bikesOk = profile.bikeTypes.isEmpty ||
            profile.bikeTypes.contains(ride.bikeType);
        final distOk = ride.distanceKm >= profile.preferredDistanceMin &&
            ride.distanceKm <= profile.preferredDistanceMax;
        final elevOk = ride.elevationM >= profile.preferredElevationMin &&
            ride.elevationM <= profile.preferredElevationMax;
        final skillOk =
            ride.skillLevel.index <= profile.fitnessLevel.index + 1;
        if (!(bikesOk && distOk && elevOk && skillOk)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<_DayBucket> _groupByDay(List<Ride> rides) {
    final map = <DateTime, List<Ride>>{};
    for (final ride in rides) {
      final key = DateTime(
        ride.startsAt.year,
        ride.startsAt.month,
        ride.startsAt.day,
      );
      map.putIfAbsent(key, () => []).add(ride);
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final key in keys) _DayBucket(day: key, rides: map[key]!),
    ];
  }

  String _dayTitle(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == tomorrow) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(day);
  }

  Future<void> _planRouteThenOffer() async {
    final planned = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(builder: (_) => const RoutePlannerScreen()),
    );
    if (planned == null || !mounted) return;
    context.push('/create-ride', extra: planned);
  }

  Future<void> _openMoreFilters() async {
    final result = await showModalBottomSheet<_FilterDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MoreFiltersSheet(
        draft: _FilterDraft(
          difficulty: _difficulty,
          distance: _distance,
          elevation: _elevation,
          when: _when,
          myGroupsOnly: _myGroupsOnly,
          fitForYou: _fitForYou,
          spotsLeftOnly: _spotsLeftOnly,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _difficulty = result.difficulty;
      _distance = result.distance;
      _elevation = result.elevation;
      _when = result.when;
      _myGroupsOnly = result.myGroupsOnly;
      _fitForYou = result.fitForYou;
      _spotsLeftOnly = result.spotsLeftOnly;
    });
  }

  void _onRsvp(AppState state, Ride ride, RsvpStatus status) {
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
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final gutter = AppLayout.pageGutter(context);
    final filtered = _applyFilters(state, state.recommendedRides);
    final buckets = _groupByDay(filtered);

    return Scaffold(
      floatingActionButton: _mapMode
          ? FloatingActionButton.extended(
              heroTag: 'home-fab-plan-route',
              onPressed: _planRouteThenOffer,
              icon: const Icon(Icons.route),
              label: const Text('Plan route'),
            )
          : FloatingActionButton.extended(
              heroTag: 'home-fab-offer-ride',
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
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
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
                            tooltip: 'Refresh rides',
                            onPressed: state.syncing
                                ? null
                                : () => state.refreshSharedData(),
                            icon: state.syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                          IconButton(
                            tooltip: 'Toggle theme',
                            onPressed: state.toggleTheme,
                            icon: const Icon(Icons.brightness_6_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find a ride',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 14),
                      _BikeTypeFilterRow(
                        selected: _bikeFilters,
                        onToggle: _toggleBike,
                      ),
                      const SizedBox(height: 10),
                      _QuickFilterRow(
                        when: _when,
                        fitForYou: _fitForYou,
                        myGroupsOnly: _myGroupsOnly,
                        spotsLeftOnly: _spotsLeftOnly,
                        activeCount: _activeFilterCount,
                        onWhen: (v) => setState(() {
                          _when = _when == v ? _WhenBand.any : v;
                        }),
                        onFitForYou: () =>
                            setState(() => _fitForYou = !_fitForYou),
                        onMyGroups: () =>
                            setState(() => _myGroupsOnly = !_myGroupsOnly),
                        onSpotsLeft: () =>
                            setState(() => _spotsLeftOnly = !_spotsLeftOnly),
                        onMore: _openMoreFilters,
                        onClear: _hasFilters ? _clearFilters : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        filtered.isEmpty
                            ? 'No rides match these filters'
                            : '${filtered.length} ride${filtered.length == 1 ? '' : 's'}'
                                '${buckets.length > 1 ? ' · ${buckets.length} days' : ''}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.stone,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_mapMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Pins = start · Stripe color = bike type',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        RidesMapView(
                          rides: filtered,
                          height: 340,
                          onRideTap: (ride) =>
                              context.push('/home/ride/${ride.id}'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final b in BikeType.values)
                              Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: b.color,
                                  radius: 6,
                                ),
                                label: Text(b.label),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_mapMode)
                if (buckets.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFilterState(onClear: _clearFilters),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 88),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final bucket = buckets[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == buckets.length - 1 ? 0 : 22,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayHeader(
                                  title: _dayTitle(bucket.day),
                                  count: bucket.rides.length,
                                ),
                                const SizedBox(height: 10),
                                for (var i = 0;
                                    i < bucket.rides.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(height: 14),
                                  RideCard(
                                    ride: bucket.rides[i],
                                    rsvp: state.rsvpFor(bucket.rides[i].id),
                                    onOpen: () => context.push(
                                      '/home/ride/${bucket.rides[i].id}',
                                    ),
                                    onRsvp: (status) => _onRsvp(
                                      state,
                                      bucket.rides[i],
                                      status,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                        childCount: buckets.length,
                      ),
                    ),
                  )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 88),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ride = filtered[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: ride.bikeType.color,
                          child: Icon(
                            ride.bikeType.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(ride.title),
                        subtitle: Text(
                          '${DateFormat('EEE HH:mm').format(ride.startsAt)} · '
                          '${ride.distanceKm.toInt()} km · ${ride.meetingPoint}',
                        ),
                        trailing: Text(
                          ride.bikeType.shortCode,
                          style: TextStyle(
                            color: ride.bikeType.color,
                            fontWeight: FontWeight.w800,
                          ),
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

class _DayBucket {
  const _DayBucket({required this.day, required this.rides});
  final DateTime day;
  final List<Ride> rides;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BikeTypeFilterRow extends StatelessWidget {
  const _BikeTypeFilterRow({
    required this.selected,
    required this.onToggle,
  });

  final Set<BikeType> selected;
  final ValueChanged<BikeType> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BikeType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final bike = BikeType.values[index];
          final isOn = selected.contains(bike);
          return FilterChip(
            selected: isOn,
            showCheckmark: false,
            avatar: Icon(
              bike.icon,
              size: 16,
              color: isOn ? Colors.white : bike.color,
            ),
            label: Text(bike.label),
            labelStyle: TextStyle(
              color: isOn ? Colors.white : bike.color,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: bike.color,
            backgroundColor: bike.color.withValues(alpha: 0.1),
            side: BorderSide(
              color: bike.color.withValues(alpha: isOn ? 0 : 0.55),
            ),
            onSelected: (_) => onToggle(bike),
          );
        },
      ),
    );
  }
}

class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow({
    required this.when,
    required this.fitForYou,
    required this.myGroupsOnly,
    required this.spotsLeftOnly,
    required this.activeCount,
    required this.onWhen,
    required this.onFitForYou,
    required this.onMyGroups,
    required this.onSpotsLeft,
    required this.onMore,
    required this.onClear,
  });

  final _WhenBand when;
  final bool fitForYou;
  final bool myGroupsOnly;
  final bool spotsLeftOnly;
  final int activeCount;
  final ValueChanged<_WhenBand> onWhen;
  final VoidCallback onFitForYou;
  final VoidCallback onMyGroups;
  final VoidCallback onSpotsLeft;
  final VoidCallback onMore;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune, size: 16),
            label: Text(
              activeCount > 0 ? 'More filters ($activeCount)' : 'More filters',
            ),
            onPressed: onMore,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Today'),
            selected: when == _WhenBand.today,
            onSelected: (_) => onWhen(_WhenBand.today),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Tomorrow'),
            selected: when == _WhenBand.tomorrow,
            onSelected: (_) => onWhen(_WhenBand.tomorrow),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Weekend'),
            selected: when == _WhenBand.weekend,
            onSelected: (_) => onWhen(_WhenBand.weekend),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.person_outline, size: 16),
            label: const Text('Fit for you'),
            selected: fitForYou,
            onSelected: (_) => onFitForYou(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.groups_outlined, size: 16),
            label: const Text('My groups'),
            selected: myGroupsOnly,
            onSelected: (_) => onMyGroups(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.event_seat_outlined, size: 16),
            label: const Text('Spots left'),
            selected: spotsLeftOnly,
            onSelected: (_) => onSpotsLeft(),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ],
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 44,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('Nothing matches', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Try another bike type, day, or clear filters to see the full board.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDraft {
  const _FilterDraft({
    required this.difficulty,
    required this.distance,
    required this.elevation,
    required this.when,
    required this.myGroupsOnly,
    required this.fitForYou,
    required this.spotsLeftOnly,
  });

  final Difficulty? difficulty;
  final _DistanceBand distance;
  final _ElevationBand elevation;
  final _WhenBand when;
  final bool myGroupsOnly;
  final bool fitForYou;
  final bool spotsLeftOnly;
}

class _MoreFiltersSheet extends StatefulWidget {
  const _MoreFiltersSheet({required this.draft});
  final _FilterDraft draft;

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late Difficulty? _difficulty = widget.draft.difficulty;
  late _DistanceBand _distance = widget.draft.distance;
  late _ElevationBand _elevation = widget.draft.elevation;
  late _WhenBand _when = widget.draft.when;
  late bool _myGroupsOnly = widget.draft.myGroupsOnly;
  late bool _fitForYou = widget.draft.fitForYou;
  late bool _spotsLeftOnly = widget.draft.spotsLeftOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More filters', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Narrow the board when lots of rides are live.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text('When', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    _WhenBand.any: 'Any day',
                    _WhenBand.today: 'Today',
                    _WhenBand.tomorrow: 'Tomorrow',
                    _WhenBand.weekend: 'This weekend',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _when == entry.key,
                      onSelected: (_) => setState(() => _when = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Difficulty', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: _difficulty == null,
                    onSelected: (_) => setState(() => _difficulty = null),
                  ),
                  for (final d in Difficulty.values)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: d.color,
                        radius: 6,
                      ),
                      label: Text(d.label),
                      selected: _difficulty == d,
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Distance', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    _DistanceBand.any: 'Any',
                    _DistanceBand.short: 'Under 40 km',
                    _DistanceBand.medium: '40–80 km',
                    _DistanceBand.long: '80+ km',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _distance == entry.key,
                      onSelected: (_) => setState(() => _distance = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Elevation', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    _ElevationBand.any: 'Any',
                    _ElevationBand.flat: 'Flat <500 m',
                    _ElevationBand.rolling: 'Rolling 500–1500 m',
                    _ElevationBand.alpine: 'Alpine 1500+ m',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _elevation == entry.key,
                      onSelected: (_) =>
                          setState(() => _elevation = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Smart cuts', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fit for you'),
                subtitle: const Text(
                  'Matches your bikes, distance, climb & fitness',
                ),
                value: _fitForYou,
                onChanged: (v) => setState(() => _fitForYou = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('My groups only'),
                value: _myGroupsOnly,
                onChanged: (v) => setState(() => _myGroupsOnly = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Spots still open'),
                value: _spotsLeftOnly,
                onChanged: (v) => setState(() => _spotsLeftOnly = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _difficulty = null;
                        _distance = _DistanceBand.any;
                        _elevation = _ElevationBand.any;
                        _when = _WhenBand.any;
                        _myGroupsOnly = false;
                        _fitForYou = false;
                        _spotsLeftOnly = false;
                      }),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _FilterDraft(
                          difficulty: _difficulty,
                          distance: _distance,
                          elevation: _elevation,
                          when: _when,
                          myGroupsOnly: _myGroupsOnly,
                          fitForYou: _fitForYou,
                          spotsLeftOnly: _spotsLeftOnly,
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
