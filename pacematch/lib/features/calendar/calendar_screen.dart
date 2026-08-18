import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  BikeType? _bikeFilter;
  Difficulty? _difficultyFilter;

  static const _joinedDayGreenLight = Color(0xFFD8F0C8);
  static const _joinedDayGreenDark = Color(0xFF2A4A32);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      final daysInMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        0,
      ).day;
      final day = _selectedDay.day.clamp(1, daysInMonth);
      _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = DateTime(now.year, now.month, now.day);
      _visibleMonth = DateTime(now.year, now.month);
    });
  }

  List<DateTime?> get _monthCells {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    // Monday-based: weekday 1=Mon ... 7=Sun
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  List<Ride> _ridesOnDay(AppState state, DateTime day) {
    return state.filteredRides(
      bikeType: _bikeFilter,
      difficulty: _difficultyFilter,
      day: day,
    );
  }

  Future<void> _openDaySheet(AppState state, DateTime day) async {
    setState(() => _selectedDay = day);
    final rides = _ridesOnDay(state, day);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final height = MediaQuery.sizeOf(context).height * 0.62;
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  DateFormat('EEEE, MMM d').format(day),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: rides.isEmpty
                    ? Center(
                        child: Text(
                          'No rides on this day',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: rides.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ride = rides[index];
                          final rsvp = state.rsvpFor(ride.id);
                          final joined = rsvp == RsvpStatus.joined;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: joined
                                    ? AppColors.forest
                                    : theme.colorScheme.outline,
                                width: joined ? 2 : 1,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: ride.difficulty.color,
                              child: Icon(
                                ride.bikeType.icon,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            title: Text(ride.title),
                            subtitle: Text(
                              '${ride.bikeType.label} · ${ride.distanceKm.toInt()} km · '
                              '${DateFormat('HH:mm').format(ride.startsAt)}'
                              '${rsvp != RsvpStatus.none ? ' · ${rsvp.name}' : ''}'
                              '\n${ride.meetingPoint}',
                            ),
                            isThreeLine: true,
                            trailing: joined
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.forest,
                                  )
                                : rsvp == RsvpStatus.maybe
                                ? const Icon(
                                    Icons.help_outline,
                                    color: Color(0xFFC48A2A),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/home/ride/${ride.id}');
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final joinedDayColor = theme.brightness == Brightness.dark
        ? _joinedDayGreenDark
        : _joinedDayGreenLight;
    final monthRides = state.filteredRides(
      bikeType: _bikeFilter,
      difficulty: _difficultyFilter,
      month: _visibleMonth,
    );
    final cells = _monthCells;
    final rowCount = (cells.length / 7).ceil();

    List<Ride> ridesForDay(DateTime day) => monthRides
        .where(
          (r) =>
              r.startsAt.year == day.year &&
              r.startsAt.month == day.month &&
              r.startsAt.day == day.day,
        )
        .toList();

    bool dayHasJoined(DateTime day) =>
        ridesForDay(day).any((r) => state.hasJoinedRsvp(r.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Ride calendar')),
      body: AdaptiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(onPressed: _goToToday, child: const Text('Today')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final label in [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ])
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 4.0;
                    final cellWidth = (constraints.maxWidth - spacing * 6) / 7;
                    final cellHeight =
                        (constraints.maxHeight - spacing * (rowCount - 1)) /
                        rowCount;
                    final aspectRatio =
                        cellWidth / cellHeight.clamp(1.0, double.infinity);

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cells.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: aspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final day = cells[index];
                        if (day == null) return const SizedBox.shrink();

                        final now = DateTime.now();
                        final isToday =
                            day.year == now.year &&
                            day.month == now.month &&
                            day.day == now.day;
                        final selected =
                            day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;
                        final joined = dayHasJoined(day);
                        final dayRides = ridesForDay(day);
                        final bikeTypes = <BikeType>{
                          for (final ride in dayRides) ride.bikeType,
                        }.toList();

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openDaySheet(state, day),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: joined
                                    ? joinedDayColor
                                    : selected
                                    ? AppColors.forest.withValues(alpha: 0.12)
                                    : null,
                                border: Border.all(
                                  color: isToday
                                      ? AppColors.forest
                                      : selected
                                      ? AppColors.forest.withValues(alpha: 0.7)
                                      : theme.colorScheme.outline.withValues(
                                          alpha: 0.35,
                                        ),
                                  width: isToday || selected ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: isToday
                                          ? const BoxDecoration(
                                              color: AppColors.forest,
                                              shape: BoxShape.circle,
                                            )
                                          : null,
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              isToday || selected || joined
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isToday
                                              ? Colors.white
                                              : joined
                                              ? AppColors.forestDeep
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (bikeTypes.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Wrap(
                                            spacing: 1,
                                            runSpacing: 1,
                                            alignment: WrapAlignment.center,
                                            children: [
                                              for (final bike in bikeTypes.take(
                                                3,
                                              ))
                                                Icon(
                                                  bike.icon,
                                                  size: 12,
                                                  color: AppColors.forest,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Today', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 14),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: joinedDayColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.forest.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Joined', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 14),
                  Icon(BikeType.road.icon, size: 14, color: AppColors.forest),
                  const SizedBox(width: 4),
                  Text('Ride types', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(_bikeFilter?.label ?? 'Bike type'),
                    selected: _bikeFilter != null,
                    onSelected: (_) async {
                      final value = await showModalBottomSheet<BikeType?>(
                        context: context,
                        builder: (context) => _FilterSheet<BikeType>(
                          title: 'Bike type',
                          values: BikeType.values,
                          labelOf: (v) => v.label,
                          selected: _bikeFilter,
                        ),
                      );
                      if (!mounted) return;
                      setState(() => _bikeFilter = value);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(_difficultyFilter?.label ?? 'Difficulty'),
                    selected: _difficultyFilter != null,
                    onSelected: (_) async {
                      final value = await showModalBottomSheet<Difficulty?>(
                        context: context,
                        builder: (context) => _FilterSheet<Difficulty>(
                          title: 'Difficulty',
                          values: Difficulty.values,
                          labelOf: (v) => '${v.emoji} ${v.label}',
                          selected: _difficultyFilter,
                        ),
                      );
                      if (!mounted) return;
                      setState(() => _difficultyFilter = value);
                    },
                  ),
                  const SizedBox(width: 8),
                  if (_bikeFilter != null || _difficultyFilter != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _bikeFilter = null;
                        _difficultyFilter = null;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet<T> extends StatelessWidget {
  const _FilterSheet({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.selected,
  });

  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            title: const Text('Any'),
            onTap: () => Navigator.pop(context, null),
          ),
          for (final value in values)
            ListTile(
              title: Text(labelOf(value)),
              selected: value == selected,
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    );
  }
}
