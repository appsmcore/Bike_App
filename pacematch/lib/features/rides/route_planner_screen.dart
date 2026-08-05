import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/routing_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
import '../../services/routing_service.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({
    super.key,
    this.initialBikeType = BikeType.road,
    this.initialWaypoints = const [],
  });

  final BikeType initialBikeType;
  final List<LatLng> initialWaypoints;

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _mapController = MapController();
  final _routing = RoutingService();

  late BikeType _bikeType;
  bool _flexible = false;
  final List<LatLng> _waypoints = [];
  List<LatLng> _geometry = [];
  PlannedRoute? _route;
  bool _routingBusy = false;
  bool _elevationBusy = false;
  bool _rerouteQueued = false;
  String? _error;
  int _routeRequestId = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bikeType = widget.initialBikeType;
    _waypoints.addAll(widget.initialWaypoints);
    if (!RoutingConfig.hasAnyRoutingKey) {
      _error =
          'Missing API keys. Add GH_API_KEY / ORS_API_KEY to pacematch/.env '
          '(same file as the route playground), then restart the app.';
    } else if (_waypoints.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestRoute());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _routing.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (_routingBusy) return;
    setState(() {
      _waypoints.add(point);
      _error = null;
    });
    _scheduleRoute();
  }

  void _undoWaypoint() {
    if (_waypoints.isEmpty || _routingBusy) return;
    setState(() {
      _waypoints.removeLast();
      if (_waypoints.length < 2) {
        _geometry = [];
        _route = null;
      }
      _error = null;
    });
    if (_waypoints.length >= 2) {
      _scheduleRoute();
    }
  }

  void _clearAll() {
    _debounce?.cancel();
    _routeRequestId++;
    setState(() {
      _waypoints.clear();
      _geometry = [];
      _route = null;
      _error = null;
      _routingBusy = false;
      _elevationBusy = false;
      _rerouteQueued = false;
    });
  }

  void _scheduleRoute() {
    _debounce?.cancel();
    if (_waypoints.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 450), _requestRoute);
  }

  Future<void> _requestRoute() async {
    if (_waypoints.length < 2) return;
    if (_routingBusy) {
      _rerouteQueued = true;
      return;
    }

    final requestId = ++_routeRequestId;
    final waypoints = List<LatLng>.from(_waypoints);
    final bikeType = _bikeType;
    final flexible = _flexible;

    setState(() {
      _routingBusy = true;
      _error = null;
    });

    try {
      final result = await _routing.route(
        waypoints: waypoints,
        bikeType: bikeType,
        flexibleRouting: flexible,
      );
      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _route = result;
        _geometry = result.geometry;
        _routingBusy = false;
        _elevationBusy = true;
      });

      // Elevation in background — must not block the map.
      unawaited(_enrichElevation(requestId, result));
    } catch (e) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routingBusy = false;
        _elevationBusy = false;
        _error = e is RoutingException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
        _geometry = [];
        _route = null;
      });
    } finally {
      if (_rerouteQueued && mounted && requestId == _routeRequestId) {
        _rerouteQueued = false;
        _scheduleRoute();
      }
    }
  }

  Future<void> _enrichElevation(int requestId, PlannedRoute base) async {
    try {
      final withElev = await _routing.withElevation(base);
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _route = withElev;
        _elevationBusy = false;
      });
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() => _elevationBusy = false);
    }
  }

  void _onBikeChanged(BikeType? value) {
    if (value == null) return;
    setState(() => _bikeType = value);
    _scheduleRoute();
  }

  void _onFlexibleChanged(bool value) {
    setState(() => _flexible = value);
    _scheduleRoute();
  }

  void _confirm() {
    final route = _route;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan a valid route first')),
      );
      return;
    }
    Navigator.of(context).pop(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _waypoints.isNotEmpty
        ? _waypoints.last
        : const LatLng(46.4983, 11.3548);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan route'),
        actions: [
          TextButton(
            onPressed: _waypoints.isEmpty ? null : _clearAll,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<BikeType>(
                    key: ValueKey('planner-bike-$_bikeType'),
                    initialValue: _bikeType,
                    decoration: const InputDecoration(
                      labelText: 'Bike type',
                      isDense: true,
                    ),
                    items: [
                      for (final b in BikeType.values)
                        DropdownMenuItem(value: b, child: Text(b.label)),
                    ],
                    onChanged: _onBikeChanged,
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Allow any surface'),
                    subtitle: Text(
                      surfaceHintFor(_bikeType, flexible: _flexible),
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _flexible,
                    onChanged: _onFlexibleChanged,
                  ),
                  Text(
                    'Tap the map to add waypoints · ${_waypoints.length} points',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 11.5,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pacematch.app',
                    ),
                    if (_geometry.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _geometry,
                            strokeWidth: 5,
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < _waypoints.length; i++)
                          Marker(
                            point: _waypoints[i],
                            width: 36,
                            height: 36,
                            child: _WaypointPin(
                              index: i,
                              isStart: i == 0,
                              isEnd: i == _waypoints.length - 1 &&
                                  _waypoints.length > 1,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_routingBusy)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Calculating route…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'undo-wp',
                        tooltip: 'Undo last waypoint',
                        onPressed: _waypoints.isEmpty ? null : _undoWaypoint,
                        child: const Icon(Icons.undo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 8,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Distance',
                            value: _route == null
                                ? '—'
                                : '${_route!.distanceKm.toStringAsFixed(1)} km',
                          ),
                        ),
                        Expanded(
                          child: _StatTile(
                            label: 'Climb',
                            value: _route == null
                                ? '—'
                                : _elevationBusy && _route!.elevationM == 0
                                    ? '…'
                                    : '${_route!.elevationM} m',
                          ),
                        ),
                        Expanded(
                          child: _StatTile(
                            label: 'Engine',
                            value: _route?.profileUsed ??
                                (RoutingConfig.hasGhApiKey
                                    ? 'graphhopper'
                                    : routingProfileLabel(
                                        _bikeType,
                                        flexible: _flexible,
                                      )),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _route == null || _routingBusy ? null : _confirm,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm route & back to offer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaypointPin extends StatelessWidget {
  const _WaypointPin({
    required this.index,
    required this.isStart,
    required this.isEnd,
  });

  final int index;
  final bool isStart;
  final bool isEnd;

  @override
  Widget build(BuildContext context) {
    final color = isStart
        ? AppColors.forest
        : isEnd
            ? const Color(0xFFC62828)
            : AppColors.ink;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
