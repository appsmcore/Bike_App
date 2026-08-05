import 'package:latlong2/latlong.dart';

import 'models.dart';

/// A planned bike route with waypoints, geometry, and stats.
class PlannedRoute {
  const PlannedRoute({
    required this.waypoints,
    required this.geometry,
    required this.distanceKm,
    required this.elevationM,
    required this.elevationProfile,
    required this.bikeType,
    required this.flexibleRouting,
    required this.profileUsed,
  });

  final List<LatLng> waypoints;
  final List<LatLng> geometry;
  final double distanceKm;
  final int elevationM;
  final List<double> elevationProfile;
  final BikeType bikeType;
  final bool flexibleRouting;
  final String profileUsed;

  LatLng get start => waypoints.isNotEmpty ? waypoints.first : geometry.first;

  PlannedRoute copyWith({
    List<LatLng>? waypoints,
    List<LatLng>? geometry,
    double? distanceKm,
    int? elevationM,
    List<double>? elevationProfile,
    BikeType? bikeType,
    bool? flexibleRouting,
    String? profileUsed,
  }) {
    return PlannedRoute(
      waypoints: waypoints ?? this.waypoints,
      geometry: geometry ?? this.geometry,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationM: elevationM ?? this.elevationM,
      elevationProfile: elevationProfile ?? this.elevationProfile,
      bikeType: bikeType ?? this.bikeType,
      flexibleRouting: flexibleRouting ?? this.flexibleRouting,
      profileUsed: profileUsed ?? this.profileUsed,
    );
  }
}

/// Surface preference encoded for scoring ORS alternatives.
enum SurfacePreference {
  /// Cycleways first, quiet paved roads second, unpaved only if needed.
  pavedCycleNetwork,

  /// Unpaved tracks/paths first, asphalt only if needed to continue.
  unpavedPreferred,
}

SurfacePreference surfacePreferenceFor(
  BikeType bikeType, {
  required bool flexible,
}) {
  if (flexible) return SurfacePreference.pavedCycleNetwork;
  return switch (bikeType) {
    BikeType.road => SurfacePreference.pavedCycleNetwork,
    BikeType.mtb ||
    BikeType.gravel ||
    BikeType.touring ||
    BikeType.ebike =>
      SurfacePreference.unpavedPreferred,
  };
}

/// OpenRouteService cycling profile id.
String orsProfileFor(BikeType bikeType, {required bool flexible}) {
  if (flexible) return 'cycling-regular';
  return switch (bikeType) {
    BikeType.road => 'cycling-road',
    // Mountain profile is the closest public ORS profile to "prefer unpaved".
    BikeType.mtb ||
    BikeType.gravel ||
    BikeType.touring ||
    BikeType.ebike =>
      'cycling-mountain',
  };
}

String orsPreferenceFor({required bool flexible}) =>
    flexible ? 'shortest' : 'recommended';

/// GraphHopper custom_model for surface / road-class preference.
/// Requires `ch.disable: true` on the request.
Map<String, dynamic> graphHopperCustomModel(
  BikeType bikeType, {
  required bool flexible,
}) {
  if (flexible) {
    return {
      'distance_influence': 90,
      'priority': [
        {'if': 'road_class == STEPS', 'multiply_by': '0'},
      ],
    };
  }

  return switch (bikeType) {
    BikeType.road => {
        // Prefer cycleways; quiet streets OK; avoid busy + unpaved.
        'distance_influence': 70,
        'priority': [
          {'if': 'road_class == CYCLEWAY', 'multiply_by': '6'},
          {
            'if':
                'road_class == RESIDENTIAL || road_class == LIVING_STREET || road_class == SERVICE',
            'multiply_by': '1.4',
          },
          {
            'if': 'road_class == FOOTWAY || road_class == PEDESTRIAN',
            'multiply_by': '0.8',
          },
          {
            'if': 'road_class == PRIMARY || road_class == TRUNK || road_class == MOTORWAY',
            'multiply_by': '0.05',
          },
          {'if': 'road_class == SECONDARY', 'multiply_by': '0.15'},
          {'if': 'road_class == TERTIARY', 'multiply_by': '0.35'},
          {
            'if':
                'surface == UNPAVED || surface == GRAVEL || surface == DIRT || surface == GROUND || surface == COMPACTED || surface == FINE_GRAVEL || surface == SAND || surface == GRASS',
            'multiply_by': '0.08',
          },
          {'if': 'road_class == STEPS', 'multiply_by': '0'},
        ],
      },
    BikeType.mtb ||
    BikeType.gravel ||
    BikeType.touring ||
    BikeType.ebike =>
      {
        // Prefer unpaved tracks/paths; asphalt only if needed.
        'distance_influence': 60,
        'priority': [
          {
            'if':
                'surface == GRAVEL || surface == DIRT || surface == GROUND || surface == UNPAVED || surface == COMPACTED || surface == FINE_GRAVEL || surface == SAND || surface == GRASS',
            'multiply_by': '5',
          },
          {
            'if': 'road_class == TRACK || road_class == PATH',
            'multiply_by': '4',
          },
          {'if': 'road_class == CYCLEWAY', 'multiply_by': '1.2'},
          {
            'if': 'surface == ASPHALT || surface == CONCRETE || surface == PAVED',
            'multiply_by': '0.12',
          },
          {
            'if':
                'road_class == PRIMARY || road_class == SECONDARY || road_class == TRUNK || road_class == MOTORWAY',
            'multiply_by': '0.05',
          },
          {'if': 'road_class == TERTIARY', 'multiply_by': '0.2'},
          {'if': 'road_class == STEPS', 'multiply_by': '0'},
        ],
      },
  };
}

/// ORS `options` object tuned per bike type.
Map<String, dynamic> orsOptionsFor(
  BikeType bikeType, {
  required bool flexible,
}) {
  if (flexible) {
    return {
      'avoid_features': ['steps'],
    };
  }

  return switch (bikeType) {
    BikeType.road => {
        'avoid_features': ['steps', 'ferries', 'fords'],
        'profile_params': {
          'weightings': {
            // Prefer gentler gradients → fewer steep road shortcuts.
            'steepness_difficulty': 0,
          },
        },
      },
    BikeType.mtb => {
        'avoid_features': ['steps', 'ferries'],
        'profile_params': {
          'weightings': {'steepness_difficulty': 3},
        },
      },
    BikeType.gravel || BikeType.touring || BikeType.ebike => {
        'avoid_features': ['steps', 'ferries'],
        'profile_params': {
          'weightings': {'steepness_difficulty': 2},
        },
      },
  };
}

String routingProfileLabel(BikeType bikeType, {required bool flexible}) {
  final profile = orsProfileFor(bikeType, flexible: flexible);
  final pref = orsPreferenceFor(flexible: flexible);
  return '$profile · $pref';
}

String surfaceHintFor(BikeType bikeType, {required bool flexible}) {
  if (flexible) {
    return 'Relaxed rules — shortest bike-network path (may use roads)';
  }
  return switch (bikeType) {
    BikeType.road =>
      'Cycleways strongly preferred · quiet streets OK · unpaved only if needed',
    BikeType.mtb ||
    BikeType.gravel ||
    BikeType.touring ||
    BikeType.ebike =>
      'Unpaved strongly preferred · asphalt only if no alternative',
  };
}

// --- ORS extra_info value codes ---------------------------------------------

/// Waytype: 1 state, 2 road, 3 street, 4 path, 5 track, 6 cycleway, 7 footway…
abstract final class OrsWaytype {
  static const stateRoad = 1;
  static const road = 2;
  static const street = 3;
  static const path = 4;
  static const track = 5;
  static const cycleway = 6;
  static const footway = 7;
  static const steps = 8;
  static const ferry = 9;
}

/// Surface: 1 paved, 2 unpaved, 3 asphalt, 4 concrete, 8 compacted, 10 gravel…
abstract final class OrsSurface {
  static const paved = 1;
  static const unpaved = 2;
  static const asphalt = 3;
  static const concrete = 4;
  static const cobblestone = 5;
  static const compacted = 8;
  static const fineGravel = 9;
  static const gravel = 10;
  static const dirt = 11;
  static const ground = 12;
  static const pavingStones = 14;
  static const sand = 15;
  static const grass = 17;
}

bool orsSurfaceIsPaved(int code) =>
    code == OrsSurface.paved ||
    code == OrsSurface.asphalt ||
    code == OrsSurface.concrete ||
    code == OrsSurface.cobblestone ||
    code == OrsSurface.pavingStones;

bool orsSurfaceIsUnpaved(int code) =>
    code == OrsSurface.unpaved ||
    code == OrsSurface.compacted ||
    code == OrsSurface.fineGravel ||
    code == OrsSurface.gravel ||
    code == OrsSurface.dirt ||
    code == OrsSurface.ground ||
    code == OrsSurface.sand ||
    code == OrsSurface.grass;

/// Score an ORS route candidate from extras summaries (higher = better fit).
///
/// Weights are intentionally strong so a slightly longer cycleway / unpaved
/// route beats a short car-road route when both appear as alternatives.
double scoreRouteForPreference({
  required SurfacePreference preference,
  required Map<int, double> waytypeAmountPct,
  required Map<int, double> surfaceAmountPct,
  required double distanceKm,
}) {
  var score = 0.0;

  double way(int code) => waytypeAmountPct[code] ?? 0;

  var pavedPct = 0.0;
  var unpavedPct = 0.0;
  for (final e in surfaceAmountPct.entries) {
    if (orsSurfaceIsPaved(e.key)) {
      pavedPct += e.value;
    } else if (orsSurfaceIsUnpaved(e.key)) {
      unpavedPct += e.value;
    }
  }

  switch (preference) {
    case SurfacePreference.pavedCycleNetwork:
      // Cycleways dominate — even a short detour should win vs parallel roads.
      score += way(OrsWaytype.cycleway) * 28;
      score += way(OrsWaytype.footway) * 2;
      // Quiet streets OK when no cycleway; never prefer busy roads.
      score += way(OrsWaytype.street) * 3;
      score -= way(OrsWaytype.road) * 6;
      score -= way(OrsWaytype.stateRoad) * 22;
      score -= way(OrsWaytype.steps) * 20;
      score -= way(OrsWaytype.ferry) * 10;
      // Unpaved only if needed.
      score -= way(OrsWaytype.track) * 8;
      score -= way(OrsWaytype.path) * 4;
      score += pavedPct * 10;
      score -= unpavedPct * 14;
      // Extra boost when most of the route is already on cycleways.
      if (way(OrsWaytype.cycleway) >= 40) score += 35;
    case SurfacePreference.unpavedPreferred:
      score += way(OrsWaytype.track) * 26;
      score += way(OrsWaytype.path) * 22;
      score += way(OrsWaytype.cycleway) * 3;
      score -= way(OrsWaytype.street) * 6;
      score -= way(OrsWaytype.road) * 12;
      score -= way(OrsWaytype.stateRoad) * 24;
      score -= way(OrsWaytype.steps) * 15;
      score += unpavedPct * 26;
      score -= pavedPct * 18;
      if (unpavedPct + way(OrsWaytype.track) + way(OrsWaytype.path) >= 40) {
        score += 30;
      }
  }

  // Weak distance term: surface/waytype quality matters more than a few km.
  score -= distanceKm * 0.08;
  return score;
}
