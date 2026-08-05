import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

class RidesMapView extends StatelessWidget {
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

  List<LatLng> _routePoints(Ride ride) {
    final pts = <LatLng>[];
    final raw = ride.routeLatLngs;
    for (var i = 0; i + 1 < raw.length; i += 2) {
      pts.add(LatLng(raw[i], raw[i + 1]));
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final center = rides.isEmpty
        ? const LatLng(46.4983, 11.3548)
        : LatLng(rides.first.startLat, rides.first.startLng);

    final polylines = <Polyline>[];
    if (showRoutes) {
      for (final ride in rides) {
        final pts = _routePoints(ride);
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
      height: height ?? 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 9.5,
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
                      onTap: () => onRideTap(ride),
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

/// Compact map showing a single planned / saved route polyline.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({
    super.key,
    required this.points,
    this.height = 160,
  });

  final List<LatLng> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 11,
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
