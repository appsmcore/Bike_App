import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
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
  final _meeting = TextEditingController(text: 'Bolzano Train Station');
  final _distance = TextEditingController(text: '50');
  final _elevation = TextEditingController(text: '800');
  final _limit = TextEditingController(text: '12');

  late DateTime _startsAt;
  BikeType _bike = BikeType.road;
  Difficulty _difficulty = Difficulty.moderate;
  FitnessLevel _skill = FitnessLevel.intermediate;
  String? _groupId;
  PlannedRoute? _plannedRoute;

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
    super.dispose();
  }

  void _applyPlannedRoute(PlannedRoute route) {
    _plannedRoute = route;
    _bike = route.bikeType;
    _distance.text = route.distanceKm.toStringAsFixed(
      route.distanceKm == route.distanceKm.roundToDouble() ? 0 : 1,
    );
    _elevation.text = '${route.elevationM}';
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
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  void _submit() {
    final state = context.read<AppState>();
    final groups = state.groups;
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a group first')),
      );
      return;
    }
    final groupId = _groupId ?? groups.first.id;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a ride title')),
      );
      return;
    }

    final planned = _plannedRoute;
    final ride = state.createRide(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? 'Join this PaceMatch ride!'
          : _description.text.trim(),
      startsAt: _startsAt,
      meetingPoint: _meeting.text.trim(),
      bikeType: _bike,
      distanceKm: double.tryParse(_distance.text) ?? 50,
      elevationM: int.tryParse(_elevation.text) ?? 800,
      riderLimit: int.tryParse(_limit.text) ?? 12,
      difficulty: _difficulty,
      skillLevel: _skill,
      groupId: groupId,
      startLat: planned?.start.latitude,
      startLng: planned?.start.longitude,
      elevationProfile: (planned != null && planned.elevationProfile.isNotEmpty)
          ? planned.elevationProfile
          : null,
      routeLatLngs: planned == null ? const [] : _flattenRoute(planned),
    );

    context.go('/home/ride/${ride.id}');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final memberGroups =
        state.groups.where((g) => state.isMemberOf(g.id)).toList();
    final options =
        memberGroups.isNotEmpty ? memberGroups : state.groups.toList();
    final selectedGroupId =
        (_groupId != null && options.any((g) => g.id == _groupId))
            ? _groupId
            : (options.isNotEmpty ? options.first.id : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Offer a ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Ride title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
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
          TextField(
            controller: _meeting,
            decoration: const InputDecoration(labelText: 'Meeting point'),
          ),
          const SizedBox(height: 12),
          if (options.isNotEmpty && selectedGroupId != null)
            DropdownButtonFormField<String>(
              key: ValueKey('group-$selectedGroupId'),
              initialValue: selectedGroupId,
              decoration: const InputDecoration(labelText: 'Group'),
              items: [
                for (final g in options)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BikeType>(
            key: ValueKey('bike-$_bike'),
            initialValue: _bike,
            decoration: const InputDecoration(labelText: 'Bike type'),
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
                  Text('Route', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _plannedRoute == null
                        ? 'Plan on the map — distance & climb are calculated from waypoints for your bike type.'
                        : '${_plannedRoute!.distanceKm.toStringAsFixed(1)} km · '
                            '${_plannedRoute!.elevationM} m · '
                            '${_plannedRoute!.waypoints.length} waypoints'
                            '${_plannedRoute!.flexibleRouting ? ' · any surface' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _openPlanner,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      _plannedRoute == null ? 'Plan route on map' : 'Edit route',
                    ),
                  ),
                  if (_plannedRoute != null &&
                      _plannedRoute!.geometry.length >= 2) ...[
                    const SizedBox(height: 12),
                    RoutePreviewMap(points: _plannedRoute!.geometry),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Difficulty>(
            key: ValueKey('diff-$_difficulty'),
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'Difficulty'),
            items: [
              for (final d in Difficulty.values)
                DropdownMenuItem(
                  value: d,
                  child: Text('${d.emoji} ${d.label}'),
                ),
            ],
            onChanged: (v) => setState(() => _difficulty = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FitnessLevel>(
            key: ValueKey('skill-$_skill'),
            initialValue: _skill,
            decoration: const InputDecoration(labelText: 'Skill level'),
            items: [
              for (final s in FitnessLevel.values)
                DropdownMenuItem(value: s, child: Text(s.fullLabel)),
            ],
            onChanged: (v) => setState(() => _skill = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distance,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Distance km',
                    helperText: _plannedRoute != null ? 'From map route' : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _elevation,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Elevation m',
                    helperText: _plannedRoute != null ? 'From map route' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rider limit'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              _groupId = selectedGroupId;
              _submit();
            },
            child: const Text('Publish ride'),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: create a group first if you want your own club rides.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
