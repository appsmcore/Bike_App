import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

List<LatLng> routePointsFromRide(Ride ride) {
  final pts = <LatLng>[];
  final raw = ride.routeLatLngs;
  for (var i = 0; i + 1 < raw.length; i += 2) {
    pts.add(LatLng(raw[i], raw[i + 1]));
  }
  return pts;
}

LatLngBounds boundsForPoints(List<LatLng> points, {LatLng? fallback}) {
  if (points.length >= 2) {
    return LatLngBounds.fromPoints(points);
  }
  final c = points.isNotEmpty
      ? points.first
      : (fallback ?? const LatLng(46.4983, 11.3548));
  return LatLngBounds(
    LatLng(c.latitude - 0.04, c.longitude - 0.05),
    LatLng(c.latitude + 0.04, c.longitude + 0.05),
  );
}

class RidesMapView extends StatefulWidget {
  const RidesMapView({
    super.key,
    required this.rides,
    required this.onRideTap,
    this.height,
    this.showRoutes = true,
  });

  final List<Ride> rides;
  final ValueChanged<Ride> onRideTap;
  final double? height;
  final bool showRoutes;

  @override
  State<RidesMapView> createState() => _RidesMapViewState();
}

class _RidesMapViewState extends State<RidesMapView> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent());
  }

  @override
  void didUpdateWidget(covariant RidesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rides.map((r) => r.id).join() !=
        widget.rides.map((r) => r.id).join()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitToContent() {
    if (!mounted || widget.rides.isEmpty) return;
    final all = <LatLng>[];
    for (final ride in widget.rides) {
      final route = routePointsFromRide(ride);
      if (route.isNotEmpty) {
        all.addAll(route);
      } else {
        all.add(LatLng(ride.startLat, ride.startLng));
      }
    }
    if (all.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: boundsForPoints(all),
          padding: const EdgeInsets.all(40),
          maxZoom: widget.rides.length == 1 ? 13.5 : 11.5,
        ),
      );
    } catch (_) {
      // Map not ready yet — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = widget.rides;
    final center = rides.isEmpty
        ? const LatLng(46.4983, 11.3548)
        : LatLng(rides.first.startLat, rides.first.startLng);

    final polylines = <Polyline>[];
    if (widget.showRoutes) {
      for (final ride in rides) {
        final pts = routePointsFromRide(ride);
        if (pts.length >= 2) {
          polylines.add(
            Polyline(
              points: pts,
              strokeWidth: rides.length == 1 ? 5 : 3.5,
              color: ride.difficulty.color.withValues(alpha: 0.85),
            ),
          );
        }
      }
    }

    return SizedBox(
      height: widget.height ?? 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 9.5,
            onMapReady: _fitToContent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pacematch.app',
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(
              markers: [
                for (final ride in rides)
                  Marker(
                    point: LatLng(ride.startLat, ride.startLng),
                    width: 52,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => widget.onRideTap(ride),
                      child: _RideMapPin(ride: ride),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RideMapPin extends StatelessWidget {
  const _RideMapPin({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: ride.difficulty.color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ride.bikeType.icon, size: 14, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                ride.bikeType.shortCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_drop_down, color: ride.difficulty.color, size: 22),
      ],
    );
  }
}

/// Non-interactive map cover for ride list cards (route or start pin).
class RideCardMapCover extends StatefulWidget {
  const RideCardMapCover({
    super.key,
    required this.ride,
    this.height = 168,
  });

  final Ride ride;
  final double height;

  @override
  State<RideCardMapCover> createState() => _RideCardMapCoverState();
}

class _RideCardMapCoverState extends State<RideCardMapCover> {
  final _mapController = MapController();

  List<LatLng> get _points {
    final pts = routePointsFromRide(widget.ride);
    if (pts.isEmpty) {
      return [LatLng(widget.ride.startLat, widget.ride.startLng)];
    }
    return pts;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void didUpdateWidget(covariant RideCardMapCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id ||
        oldWidget.ride.routeLatLngs.length != widget.ride.routeLatLngs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fit() {
    if (!mounted) return;
    final points = _points;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: boundsForPoints(
            points,
            fallback: LatLng(widget.ride.startLat, widget.ride.startLng),
          ),
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          maxZoom: 13.5,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final routeColor = widget.ride.difficulty.color;
    final start = LatLng(widget.ride.startLat, widget.ride.startLng);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: FlutterMap(
          key: ValueKey('ride-cover-${widget.ride.id}'),
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 11,
            initialCameraFit: CameraFit.bounds(
              bounds: boundsForPoints(points, fallback: start),
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              maxZoom: 13.5,
            ),
            onMapReady: _fit,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
            backgroundColor: widget.ride.coverGradient.last,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pacematch.app',
              retinaMode: true,
            ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.5,
                    color: Colors.white.withValues(alpha: 0.95),
                    borderStrokeWidth: 2.5,
                    borderColor: routeColor.withValues(alpha: 0.9),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: routeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact map showing a single planned / saved route polyline.
class RoutePreviewMap extends StatefulWidget {
  const RoutePreviewMap({
    super.key,
    required this.points,
    this.height = 160,
  });

  final List<LatLng> points;
  final double height;

  @override
  State<RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<RoutePreviewMap> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void didUpdateWidget(covariant RoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.length != widget.points.length ||
        (widget.points.isNotEmpty &&
            oldWidget.points.isNotEmpty &&
            oldWidget.points.first != widget.points.first)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fit() {
    if (!mounted || widget.points.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: boundsForPoints(widget.points),
          padding: const EdgeInsets.all(28),
          maxZoom: 13.5,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return SizedBox(height: widget.height);
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 11,
            initialCameraFit: points.length >= 2
                ? CameraFit.bounds(
                    bounds: boundsForPoints(points),
                    padding: const EdgeInsets.all(28),
                    maxZoom: 13.5,
                  )
                : null,
            onMapReady: _fit,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pacematch.app',
            ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.5,
                    color: AppColors.forest,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 28,
                  height: 28,
                  child: const _Dot(color: AppColors.forest),
                ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 28,
                    height: 28,
                    child: const _Dot(color: Color(0xFFC62828)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
