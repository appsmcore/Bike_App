import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A place suggestion from Nominatim (OpenStreetMap).
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.point,
  });

  final String label;
  final LatLng point;
}

/// Forward / reverse geocoding via Nominatim (no API key).
///
/// Respects Nominatim usage policy: identifiable User-Agent, modest rate.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'PaceMatch/0.1 (group cycling; contact via GitHub appsmcore/Bike_App)',
  };

  void dispose() => _client.close();

  /// Address / place autocomplete. Returns up to [limit] suggestions.
  Future<List<PlaceSuggestion>> search(
    String query, {
    int limit = 6,
    LatLng? near,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final params = <String, String>{
      'q': q,
      'format': 'json',
      'addressdetails': '0',
      'limit': '$limit',
    };
    if (near != null) {
      // Bias toward South Tyrol / current map area when available.
      params['viewbox'] =
          '${near.longitude - 0.6},${near.latitude + 0.4},${near.longitude + 0.6},${near.latitude - 0.4}';
      params['bounded'] = '0';
    }

    final uri = Uri.parse('$_base/search').replace(queryParameters: params);
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];

    final list = jsonDecode(res.body);
    if (list is! List) return const [];

    final out = <PlaceSuggestion>[];
    for (final item in list) {
      if (item is! Map) continue;
      final display = (item['display_name'] as String?)?.trim();
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (display == null || display.isEmpty || lat == null || lon == null) {
        continue;
      }
      out.add(PlaceSuggestion(label: display, point: LatLng(lat, lon)));
    }
    return out;
  }

  /// Human-readable label for a coordinate (meeting point from route start).
  Future<String?> reverse(LatLng point) async {
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'format': 'json',
      'zoom': '18',
      'addressdetails': '1',
    });
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body);
    if (json is! Map) return null;

    final address = json['address'];
    if (address is Map) {
      final short = _shortLabel(Map<String, dynamic>.from(address));
      if (short != null) return short;
    }

    final display = (json['display_name'] as String?)?.trim();
    return (display != null && display.isNotEmpty) ? display : null;
  }

  String? _shortLabel(Map<String, dynamic> a) {
    final name = (a['amenity'] ??
            a['tourism'] ??
            a['building'] ??
            a['shop'] ??
            a['leisure'] ??
            a['railway'] ??
            a['highway'])
        ?.toString();
    final road = (a['road'] ?? a['pedestrian'] ?? a['path'])?.toString();
    final house = a['house_number']?.toString();
    final city = (a['city'] ??
            a['town'] ??
            a['village'] ??
            a['municipality'] ??
            a['hamlet'])
        ?.toString();

    final street = [
      if (road != null && road.isNotEmpty) road,
      if (house != null && house.isNotEmpty) house,
    ].join(' ');

    if (name != null && name.isNotEmpty && city != null && city.isNotEmpty) {
      return '$name, $city';
    }
    if (street.isNotEmpty && city != null && city.isNotEmpty) {
      return '$street, $city';
    }
    if (name != null && name.isNotEmpty) return name;
    if (street.isNotEmpty) return street;
    if (city != null && city.isNotEmpty) return city;
    return null;
  }
}
