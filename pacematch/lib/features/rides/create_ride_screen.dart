import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
import '../../services/geocoding_service.dart';
import '../../shared/widgets/meeting_point_field.dart';
import '../../shared/widgets/rides_map_view.dart';
import 'route_planner_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({
    super.key,
    this.preselectedGroupId,
    this.initialRoute,
  });

  final String? preselectedGroupId;
  final PlannedRoute? initialRoute;

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _meeting = TextEditingController();
  final _distance = TextEditingController();
  final _elevation = TextEditingController();
  final _limit = TextEditingController(text: '12');
  final _geocoder = GeocodingService();

  late DateTime _startsAt;
  BikeType _bike = BikeType.road;
  Difficulty _difficulty = Difficulty.moderate;
  FitnessLevel _skill = FitnessLevel.intermediate;
  String? _groupId;
  PlannedRoute? _plannedRoute;
  LatLng? _meetingPoint;
  int _meetingResolveId = 0;

  bool get _hasPlannedRoute => _plannedRoute != null;

  @override
  void initState() {
    super.initState();
    final soon = DateTime.now().add(const Duration(days: 3));
    _startsAt = DateTime(soon.year, soon.month, soon.day, 8, 0);
    _groupId = widget.preselectedGroupId;
    final route = widget.initialRoute;
    if (route != null) {
      _applyPlannedRoute(route);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _meeting.dispose();
    _distance.dispose();
    _elevation.dispose();
    _limit.dispose();
    _geocoder.dispose();
    super.dispose();
  }

  void _applyPlannedRoute(PlannedRoute route) {
    _plannedRoute = route;
    _bike = route.bikeType;
    _distance.text = route.distanceKm.toStringAsFixed(
      route.distanceKm == route.distanceKm.roundToDouble() ? 0 : 1,
    );
    _elevation.text = '${route.elevationM}';
    _meetingPoint = route.start;
    _fillMeetingFromRouteStart(route.start);
  }

  void _clearPlannedRoute() {
    setState(() {
      _plannedRoute = null;
      _distance.clear();
      _elevation.clear();
    });
  }

  Future<void> _fillMeetingFromRouteStart(LatLng start) async {
    final id = ++_meetingResolveId;
    try {
      final label = await _geocoder.reverse(start);
      if (!mounted || id != _meetingResolveId) return;
      if (label == null || label.isEmpty) {
        _meeting.text =
            '${start.latitude.toStringAsFixed(5)}, ${start.longitude.toStringAsFixed(5)}';
      } else {
        _meeting.text = label;
      }
    } catch (_) {
      if (!mounted || id != _meetingResolveId) return;
      _meeting.text =
          '${start.latitude.toStringAsFixed(5)}, ${start.longitude.toStringAsFixed(5)}';
    }
  }

  Future<void> _openPlanner() async {
    final result = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePlannerScreen(
          initialBikeType: _bike,
          initialWaypoints: _plannedRoute?.waypoints ?? const <LatLng>[],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _applyPlannedRoute(result));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  List<double> _flattenRoute(PlannedRoute route) {
    final out = <double>[];
    for (final p in route.geometry) {
      out.add(p.latitude);
      out.add(p.longitude);
    }
    return out;
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a ride title')),
      );
      return;
    }
    if (_meeting.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting point')),
      );
      return;
    }

    final planned = _plannedRoute;
    final distanceKm = double.tryParse(_distance.text.trim());
    final elevationM = int.tryParse(_elevation.text.trim());
    if (distanceKm == null || distanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter distance (km)')),
      );
      return;
    }
    if (elevationM == null || elevationM < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter elevation (m)')),
      );
      return;
    }

    final start = planned?.start ?? _meetingPoint;

    try {
      final ride = await state.createRide(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? 'Join this PaceMatch ride!'
            : _description.text.trim(),
        startsAt: _startsAt,
        meetingPoint: _meeting.text.trim(),
        bikeType: _bike,
        distanceKm: distanceKm,
        elevationM: elevationM,
        riderLimit: int.tryParse(_limit.text) ?? 12,
        difficulty: _difficulty,
        skillLevel: _skill,
        groupId: _groupId,
        startLat: start?.latitude,
        startLng: start?.longitude,
        elevationProfile:
            (planned != null && planned.elevationProfile.isNotEmpty)
                ? planned.elevationProfile
                : null,
        routeLatLngs: planned == null ? const [] : _flattenRoute(planned),
      );
      if (!mounted) return;
      context.go('/home/ride/${ride.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save ride: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final memberGroups = state.groups
        .where((g) => state.isMemberOf(g.id))
        .toList();
    final options = memberGroups.isNotEmpty
        ? memberGroups
        : state.groups.toList();
    // Keep an optional group only if still valid; otherwise open ride (null).
    final selectedGroupId =
        (_groupId != null && options.any((g) => g.id == _groupId))
            ? _groupId
            : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Offer a ride')),
      body: AdaptiveBody(
        maxWidth: AppLayout.formMaxWidth,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppLayout.pagePadding(
                  context,
                  top: 16,
                  extraBottom: 12,
                ),
                children: [
                  TextField(
                    controller: _title,
                    decoration:
                        const InputDecoration(labelText: 'Ride title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & time'),
                    subtitle: Text(
                      '${_startsAt.day}.${_startsAt.month}.${_startsAt.year} '
                      '${_startsAt.hour.toString().padLeft(2, '0')}:'
                      '${_startsAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.event),
                    onTap: _pickDateTime,
                  ),
                  MeetingPointField(
                    controller: _meeting,
                    biasNear: _plannedRoute?.start ?? _meetingPoint,
                    readOnly: _hasPlannedRoute,
                    onPlaceSelected: (place) {
                      setState(() => _meetingPoint = place.point);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('group-${selectedGroupId ?? 'open'}'),
                    initialValue: selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Group (optional)',
                      helperText:
                          'Leave as Open ride if you are not in a club',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Open ride (no group)'),
                      ),
                      for (final g in options)
                        DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _groupId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BikeType>(
                    key: ValueKey('bike-$_bike'),
                    initialValue: _bike,
                    decoration:
                        const InputDecoration(labelText: 'Bike type'),
                    items: [
                      for (final b in BikeType.values)
                        DropdownMenuItem(value: b, child: Text(b.label)),
                    ],
                    onChanged: (v) => setState(() => _bike = v!),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _plannedRoute == null
                                ? 'Optional — plan on the map to lock distance & climb from the route. Meeting point is filled from the start.'
                                : '${_plannedRoute!.distanceKm.toStringAsFixed(1)} km · '
                                      '${_plannedRoute!.elevationM} m · '
                                      '${_plannedRoute!.waypoints.length} waypoints'
                                      '${_plannedRoute!.flexibleRouting ? ' · any surface' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _openPlanner,
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  _plannedRoute == null
                                      ? 'Plan route on map'
                                      : 'Edit route',
                                ),
                              ),
                              if (_plannedRoute != null)
                                TextButton.icon(
                                  onPressed: _clearPlannedRoute,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Clear route'),
                                ),
                            ],
                          ),
                          if (_plannedRoute != null &&
                              _plannedRoute!.geometry.length >= 2) ...[
                            const SizedBox(height: 12),
                            RoutePreviewMap(
                              points: _plannedRoute!.geometry,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Difficulty',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Same label & color as on the ride card',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in Difficulty.values)
                        ChoiceChip(
                          selected: _difficulty == d,
                          showCheckmark: false,
                          avatar: CircleAvatar(
                            backgroundColor: _difficulty == d
                                ? Colors.white
                                : d.color,
                            radius: 7,
                          ),
                          label: Text('${d.emoji} ${d.label}'),
                          labelStyle: TextStyle(
                            color: _difficulty == d ? Colors.white : d.color,
                            fontWeight: FontWeight.w700,
                          ),
                          selectedColor: d.color,
                          backgroundColor: d.color.withValues(alpha: 0.1),
                          side: BorderSide(
                            color: d.color.withValues(
                              alpha: _difficulty == d ? 0 : 0.55,
                            ),
                          ),
                          onSelected: (_) =>
                              setState(() => _difficulty = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Skill level',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Who this pace is for (separate from difficulty)',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FitnessLevel>(
                    key: ValueKey('skill-$_skill'),
                    initialValue: _skill,
                    decoration: const InputDecoration(
                      labelText: 'Skill level',
                    ),
                    items: [
                      for (final s in FitnessLevel.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(s.fullLabel),
                        ),
                    ],
                    onChanged: (v) => setState(() => _skill = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _distance,
                          readOnly: _hasPlannedRoute,
                          enableInteractiveSelection: !_hasPlannedRoute,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Distance km',
                            hintText:
                                _hasPlannedRoute ? null : 'Enter manually',
                            helperText: _hasPlannedRoute
                                ? 'Locked from map route'
                                : 'Editable until a route is planned',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _elevation,
                          readOnly: _hasPlannedRoute,
                          enableInteractiveSelection: !_hasPlannedRoute,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Elevation m',
                            hintText:
                                _hasPlannedRoute ? null : 'Enter manually',
                            helperText: _hasPlannedRoute
                                ? 'Locked from map route'
                                : 'Editable until a route is planned',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Rider limit'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can publish an open ride without joining a group. '
                    'Attach a group if you want a club ride.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Material(
              elevation: 6,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageGutter(context),
                    12,
                    AppLayout.pageGutter(context),
                    12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _groupId = selectedGroupId;
                        _submit();
                      },
                      child: const Text('Publish ride'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
