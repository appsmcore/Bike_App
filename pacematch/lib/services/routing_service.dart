import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config/routing_config.dart';
import '../data/models.dart';
import '../data/route_models.dart';
import 'elevation_math.dart';

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RoutingService {
  RoutingService({
    http.Client? client,
    String? ghApiKey,
    String? orsApiKey,
  })  : _client = client ?? http.Client(),
        _ghApiKey = (ghApiKey ?? RoutingConfig.ghApiKey).trim(),
        _orsApiKey = (orsApiKey ?? RoutingConfig.orsApiKey).trim();

  final http.Client _client;
  final String _ghApiKey;
  final String _orsApiKey;
  bool _closed = false;

  static const _ghUrl = 'https://graphhopper.com/api/1/route';
  static const _orsBase = 'https://api.openrouteservice.org/v2/directions';
  static const _elevationUrl = 'https://api.open-meteo.com/v1/elevation';

  static const _routeTimeout = Duration(seconds: 25);
  static const _elevationTimeout = Duration(seconds: 8);
  static const _maxGeometryPoints = 280;

  bool get hasGhKey => _ghApiKey.isNotEmpty;
  bool get hasOrsKey => _orsApiKey.isNotEmpty;

  /// Prefers GraphHopper (custom surface rules), falls back to ORS.
  Future<PlannedRoute> route({
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
  }) async {
    if (_closed) throw RoutingException('Routing service closed');
    if (waypoints.length < 2) {
      throw RoutingException('Add at least two waypoints');
    }
    if (!hasGhKey && !hasOrsKey) {
      throw RoutingException(
        'Missing routing API key. For better cycleways use GraphHopper: '
        'flutter run --dart-define=GH_API_KEY=your_key '
        '(or ORS_API_KEY as fallback)',
      );
    }

    if (hasGhKey) {
      try {
        return await _routeGraphHopper(
          waypoints: waypoints,
          bikeType: bikeType,
          flexibleRouting: flexibleRouting,
        );
      } catch (e) {
        if (!hasOrsKey) {
          throw e is RoutingException
              ? e
              : RoutingException(e.toString().replaceFirst('Exception: ', ''));
        }
        // Fall through to ORS only if GraphHopper failed entirely.
      }
    }

    return _routeOrsWithFallback(
      waypoints: waypoints,
      bikeType: bikeType,
      flexibleRouting: flexibleRouting,
    );
  }

  Future<PlannedRoute> withElevation(PlannedRoute route) async {
    if (_closed) return route;

    // Always sanitize provider climb — dense DEM samples can inflate to tens of km.
    if (route.elevationM > 0 && route.elevationProfile.isNotEmpty) {
      return _withSanitizedElevation(
        route,
        rawElevations: route.elevationProfile,
        preferredAscentM: route.elevationM,
      );
    }

    try {
      final elevation = await _elevationFor(route.geometry);
      if (elevation.ascentM <= 0 && elevation.profile.isEmpty) {
        return _withSanitizedElevation(
          route,
          rawElevations: route.elevationProfile,
          preferredAscentM: route.elevationM,
        );
      }
      return _withSanitizedElevation(
        route,
        rawElevations: elevation.profile.isNotEmpty
            ? elevation.profile
            : route.elevationProfile,
        preferredAscentM:
            route.elevationM > 0 ? route.elevationM : elevation.ascentM,
      );
    } catch (_) {
      return _withSanitizedElevation(
        route,
        rawElevations: route.elevationProfile,
        preferredAscentM: route.elevationM,
      );
    }
  }

  PlannedRoute _withSanitizedElevation(
    PlannedRoute route, {
    required List<double> rawElevations,
    required int preferredAscentM,
  }) {
    final full =
        rawElevations.isNotEmpty ? rawElevations : route.elevationProfile;
    final profile = ElevationMath.profilePoints(full, max: 64);
    final display =
        profile.isNotEmpty ? profile : route.elevationProfile;
    // Cumulative climb from full samples / API — not from chart points.
    final ascent = ElevationMath.resolveClimb(
      apiAscentM: preferredAscentM,
      distanceKm: route.distanceKm,
      fullElevations: full,
    );
    return route.copyWith(
      elevationM: ascent,
      elevationProfile: display,
    );
  }

  Future<PlannedRoute> _routeGraphHopper({
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
  }) async {
    // Paid plans: custom_model + ch.disable enforce surface/cycleway rules.
    // Free plans reject flexible mode — fall back to plain bike profile.
    try {
      return await _postGraphHopper(
        waypoints: waypoints,
        bikeType: bikeType,
        flexibleRouting: flexibleRouting,
        useCustomModel: true,
      );
    } on RoutingException catch (e) {
      final msg = e.message.toLowerCase();
      final freeTierBlocked = msg.contains('flexible mode') ||
          msg.contains('custom_model') ||
          msg.contains('free package') ||
          msg.contains('free packages');
      if (!freeTierBlocked) rethrow;

      final plain = await _postGraphHopper(
        waypoints: waypoints,
        bikeType: bikeType,
        flexibleRouting: flexibleRouting,
        useCustomModel: false,
      );
      return plain.copyWith(
        profileUsed:
            'graphhopper · bike (free tier — custom rules need paid plan)',
      );
    }
  }

  Future<PlannedRoute> _postGraphHopper({
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
    required bool useCustomModel,
  }) async {
    final uri = Uri.parse(_ghUrl).replace(queryParameters: {'key': _ghApiKey});
    final body = <String, dynamic>{
      'profile': 'bike',
      'points': [
        for (final p in waypoints) [p.longitude, p.latitude],
      ],
      'locale': 'en',
      'instructions': false,
      'elevation': true,
      'points_encoded': false,
    };

    if (useCustomModel) {
      body['ch.disable'] = true;
      body['custom_model'] = graphHopperCustomModel(
        bikeType,
        flexible: flexibleRouting,
      );
    }

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_routeTimeout);

    if (response.statusCode != 200) {
      throw RoutingException(_ghError(response));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final paths = json['paths'] as List<dynamic>?;
    if (paths == null || paths.isEmpty) {
      throw RoutingException('No route found for these waypoints');
    }

    final path = paths.first as Map<String, dynamic>;
    final distanceM = _readDouble(path['distance']) ?? 0;
    final ascent = _readDouble(path['ascend']) ?? _readDouble(path['ascent']) ?? 0;
    final points = _parseGhPoints(path['points']);
    if (points.length < 2) {
      throw RoutingException('Route geometry too short');
    }

    final simplified = simplifyGeometry(points, _maxGeometryPoints);
    final elevations = _parseGhElevations(path['points']);
    final distanceKm = double.parse((distanceM / 1000).toStringAsFixed(1));
    final profilePoints = ElevationMath.profilePoints(elevations, max: 64);
    // GraphHopper `ascend` is cumulative; also sum full elev samples as backup.
    final ascentM = ElevationMath.resolveClimb(
      apiAscentM: ascent.round(),
      distanceKm: distanceKm,
      fullElevations: elevations,
    );

    final label = useCustomModel
        ? (flexibleRouting
            ? 'graphhopper · any-surface'
            : 'graphhopper · ${bikeType.name}')
        : 'graphhopper · bike';

    return PlannedRoute(
      waypoints: List.unmodifiable(waypoints),
      geometry: List.unmodifiable(simplified),
      distanceKm: distanceKm,
      elevationM: ascentM,
      elevationProfile: profilePoints,
      bikeType: bikeType,
      flexibleRouting: flexibleRouting,
      profileUsed: label,
    );
  }

  List<LatLng> _parseGhPoints(dynamic pointsField) {
    final coords = _ghCoordinates(pointsField);
    return [
      for (final c in coords)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
  }

  List<double> _parseGhElevations(dynamic pointsField) {
    final coords = _ghCoordinates(pointsField);
    final elev = <double>[];
    for (final c in coords) {
      if (c.length > 2) elev.add((c[2] as num).toDouble());
    }
    return elev;
  }

  List<List<dynamic>> _ghCoordinates(dynamic pointsField) {
    if (pointsField is Map<String, dynamic>) {
      final coords = pointsField['coordinates'];
      if (coords is List) {
        return coords.cast<List<dynamic>>();
      }
    }
    if (pointsField is List) {
      return pointsField.cast<List<dynamic>>();
    }
    return const [];
  }

  String _ghError(http.Response response) {
    final body = response.body.trim();
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final msg = json['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            return 'GraphHopper API key invalid ($msg)';
          }
          return msg;
        }
      }
    } catch (_) {}
    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'GraphHopper API key invalid';
    }
    if (body.isNotEmpty && body.length < 280) return body;
    return 'GraphHopper routing failed (${response.statusCode})';
  }

  Future<PlannedRoute> _routeOrsWithFallback({
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
  }) async {
    final profile = orsProfileFor(bikeType, flexible: flexibleRouting);
    final preference = orsPreferenceFor(flexible: flexibleRouting);

    try {
      return await _routeOrs(
        waypoints: waypoints,
        bikeType: bikeType,
        flexibleRouting: flexibleRouting,
        profile: profile,
        preference: preference,
        requestAlternatives: !flexibleRouting,
      );
    } on RoutingException {
      if (!flexibleRouting) {
        return _routeOrs(
          waypoints: waypoints,
          bikeType: bikeType,
          flexibleRouting: flexibleRouting,
          profile: profile,
          preference: preference,
          requestAlternatives: false,
        );
      }
      rethrow;
    }
  }

  Future<PlannedRoute> _routeOrs({
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
    required String profile,
    required String preference,
    required bool requestAlternatives,
  }) async {
    final uri = Uri.parse('$_orsBase/$profile/geojson');
    final body = <String, dynamic>{
      'coordinates': [
        for (final p in waypoints) [p.longitude, p.latitude],
      ],
      'elevation': true,
      'instructions': false,
      'preference': preference,
      'units': 'm',
      'geometry_simplify': false,
      'continue_straight': false,
      'extra_info': ['surface', 'waytype'],
      'options': orsOptionsFor(bikeType, flexible: flexibleRouting),
    };

    if (requestAlternatives) {
      body['alternative_routes'] = {
        'target_count': 3,
        'share_factor': 0.4,
        'weight_factor': 2.0,
      };
    }

    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': _orsApiKey,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept':
                'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(_routeTimeout);

    if (response.statusCode != 200) {
      throw RoutingException(_orsError(response));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final features = json['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw RoutingException('No route found for these waypoints');
    }

    final surfacePref = surfacePreferenceFor(
      bikeType,
      flexible: flexibleRouting,
    );
    final chosen = _pickBestFeature(
      features.cast<Map<String, dynamic>>(),
      surfacePref,
    );

    return _plannedFromFeature(
      chosen,
      waypoints: waypoints,
      bikeType: bikeType,
      flexibleRouting: flexibleRouting,
      profileUsed: '$profile · $preference',
    );
  }

  Map<String, dynamic> _pickBestFeature(
    List<Map<String, dynamic>> features,
    SurfacePreference preference,
  ) {
    if (features.length == 1) return features.first;

    Map<String, dynamic>? best;
    var bestScore = double.negativeInfinity;

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final summary = props['summary'] as Map<String, dynamic>?;
      final distanceM = _readDouble(summary?['distance']) ??
          _readDouble(props['distance']) ??
          0;
      final extras = props['extras'] as Map<String, dynamic>? ?? {};
      final wayAmounts = _extraAmountMap(extras, const ['waytypes', 'waytype']);
      final surfaceAmounts =
          _extraAmountMap(extras, const ['surfaces', 'surface']);

      final score = scoreRouteForPreference(
        preference: preference,
        waytypeAmountPct: wayAmounts,
        surfaceAmountPct: surfaceAmounts,
        distanceKm: distanceM / 1000,
      );

      if (score > bestScore) {
        bestScore = score;
        best = feature;
      }
    }

    return best ?? features.first;
  }

  Map<int, double> _extraAmountMap(
    Map<String, dynamic> extras,
    List<String> keys,
  ) {
    Map<String, dynamic>? block;
    for (final key in keys) {
      final v = extras[key];
      if (v is Map<String, dynamic>) {
        block = v;
        break;
      }
    }
    if (block == null) return {};

    final summary = block['summary'] as List<dynamic>? ?? const [];
    final out = <int, double>{};
    for (final entry in summary) {
      if (entry is! Map) continue;
      final value = entry['value'];
      final amount = _readDouble(entry['amount']) ?? 0;
      final code = value is num
          ? value.round()
          : int.tryParse(value?.toString() ?? '');
      if (code == null) continue;
      out[code] = (out[code] ?? 0) + amount;
    }
    return out;
  }

  PlannedRoute _plannedFromFeature(
    Map<String, dynamic> feature, {
    required List<LatLng> waypoints,
    required BikeType bikeType,
    required bool flexibleRouting,
    required String profileUsed,
  }) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final coords = geometry?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) {
      throw RoutingException('Route geometry too short');
    }

    final points = <LatLng>[];
    final elevations = <double>[];
    for (final c in coords) {
      final pair = c as List<dynamic>;
      points.add(
        LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      );
      if (pair.length > 2) {
        elevations.add((pair[2] as num).toDouble());
      }
    }

    final simplified = simplifyGeometry(points, _maxGeometryPoints);
    final summary = props['summary'] as Map<String, dynamic>?;
    final segments = props['segments'] as List<dynamic>?;

    final distanceM = _readDouble(summary?['distance']) ??
        _readDouble(props['distance']) ??
        0;
    final distanceKm = double.parse((distanceM / 1000).toStringAsFixed(1));
    final rawAscent = _readDouble(summary?['ascent']) ??
        _readDouble(props['ascent']) ??
        _ascentFromSegments(segments) ??
        0;

    final profilePoints = ElevationMath.profilePoints(elevations, max: 64);
    final ascentM = ElevationMath.resolveClimb(
      apiAscentM: rawAscent.round(),
      distanceKm: distanceKm,
      fullElevations: elevations,
    );

    return PlannedRoute(
      waypoints: List.unmodifiable(waypoints),
      geometry: List.unmodifiable(simplified),
      distanceKm: distanceKm,
      elevationM: ascentM,
      elevationProfile: profilePoints,
      bikeType: bikeType,
      flexibleRouting: flexibleRouting,
      profileUsed: profileUsed,
    );
  }

  double? _ascentFromSegments(List<dynamic>? segments) {
    if (segments == null || segments.isEmpty) return null;
    var sum = 0.0;
    var found = false;
    for (final s in segments) {
      final map = s as Map<String, dynamic>;
      final a = _readDouble(map['ascent']);
      if (a != null) {
        sum += a;
        found = true;
      }
    }
    return found ? sum : null;
  }

  double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _orsError(http.Response response) {
    final body = response.body.trim();
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map) {
          final msg = error['message']?.toString();
          if (msg != null && msg.isNotEmpty) {
            if (response.statusCode == 401 || response.statusCode == 403) {
              return 'ORS API key invalid or missing ($msg)';
            }
            if (response.statusCode == 429) {
              return 'ORS rate limit reached — try again later';
            }
            return msg;
          }
        }
        if (error is String && error.isNotEmpty) return error;
      }
    } catch (_) {}

    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'ORS API key invalid or missing';
    }
    if (body.isNotEmpty && body.length < 280) return body;
    return 'Routing failed (${response.statusCode})';
  }

  Future<({int ascentM, List<double> profile})> _elevationFor(
    List<LatLng> points,
  ) async {
    // Denser samples → better cumulative climb (not just start/end relief).
    final samples = simplifyGeometry(points, 120);
    if (samples.length < 2) {
      return (ascentM: 0, profile: <double>[]);
    }

    final lat = samples.map((p) => p.latitude.toStringAsFixed(5)).join(',');
    final lon = samples.map((p) => p.longitude.toStringAsFixed(5)).join(',');
    final uri = Uri.parse(_elevationUrl).replace(queryParameters: {
      'latitude': lat,
      'longitude': lon,
    });

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_elevationTimeout);

    if (response.statusCode != 200) {
      return (ascentM: 0, profile: <double>[]);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final elev = (json['elevation'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const <double>[];

    if (elev.length < 2) {
      return (ascentM: 0, profile: <double>[]);
    }

    return (
      ascentM: ElevationMath.cumulativeAscent(elev),
      profile: ElevationMath.profilePoints(elev, max: 64),
    );
  }

  void dispose() {
    _closed = true;
    _client.close();
  }
}

List<LatLng> simplifyGeometry(List<LatLng> points, int maxPoints) {
  if (points.length <= maxPoints) return List<LatLng>.from(points);
  final out = <LatLng>[];
  final step = (points.length - 1) / (maxPoints - 1);
  for (var i = 0; i < maxPoints; i++) {
    final idx = (i * step).round().clamp(0, points.length - 1);
    out.add(points[idx]);
  }
  return out;
}
