import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import 'auth_service.dart';

/// Loads and writes shared groups / rides via Supabase.
class BackendSyncService {
  BackendSyncService._();

  static bool get isAvailable =>
      AuthService.isConfigured && AuthService.hasSession;

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

  static Future<SharedCatalog> fetchCatalog() async {
    if (!isAvailable) {
      throw StateError('Supabase session required');
    }

    final groupsRaw = await _client
        .from('groups')
        .select('id, name, description, visibility, location_name, created_by, created_at')
        .order('created_at', ascending: false);

    final membersRaw = await _client
        .from('group_members')
        .select('group_id, user_id, status');

    final ridesRaw = await _client
        .from('rides')
        .select(
          'id, group_id, organizer_id, title, description, starts_at, '
          'meeting_point_name, bike_category, rider_limit, skill_level, '
          'status, distance_km, elevation_gain_m, difficulty, '
          'elevation_profile, route_latlngs, start_lat, start_lng, created_at',
        )
        .order('starts_at', ascending: true);

    final rsvpsRaw = await _client
        .from('ride_rsvps')
        .select('ride_id, user_id, status');

    final memberCount = <String, int>{};
    final myGroups = <String>{};
    final uid = _uid;
    for (final row in membersRaw as List) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['status'] != 'active') continue;
      final gid = map['group_id'] as String;
      memberCount[gid] = (memberCount[gid] ?? 0) + 1;
      if (uid != null && map['user_id'] == uid) {
        myGroups.add(gid);
      }
    }

    final groupNameById = <String, String>{};
    final groups = <CyclingGroup>[];
    for (final row in groupsRaw as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String;
      final name = (map['name'] as String?) ?? 'Group';
      groupNameById[id] = name;
      final upcoming = <String>[];
      groups.add(
        CyclingGroup(
          id: id,
          name: name,
          description: (map['description'] as String?) ?? '',
          memberCount: memberCount[id] ?? 0,
          isPrivate: map['visibility'] == 'private',
          location: (map['location_name'] as String?) ?? '',
          upcomingRideIds: upcoming,
          coverGradient: const [Color(0xFF1A7A4C), Color(0xFF0F4D32)],
        ),
      );
    }

    final joinedCount = <String, int>{};
    final participants = <String, List<String>>{};
    final myRsvps = <String, RsvpStatus>{};
    for (final row in rsvpsRaw as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final rideId = map['ride_id'] as String;
      final userId = map['user_id'] as String;
      final status = _parseRsvp(map['status'] as String?);
      if (status == RsvpStatus.joined) {
        joinedCount[rideId] = (joinedCount[rideId] ?? 0) + 1;
        participants.putIfAbsent(rideId, () => <String>[]).add(userId);
      }
      if (uid != null && userId == uid && status != RsvpStatus.none) {
        myRsvps[rideId] = status;
      }
    }

    final rides = <Ride>[];
    for (final row in ridesRaw as List) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['status'] != null && map['status'] != 'published') continue;
      final id = map['id'] as String;
      final groupId = map['group_id'] as String? ?? '';
      final elevProfile = _toDoubleList(map['elevation_profile']);
      final route = _toDoubleList(map['route_latlngs']);
      final elev = (map['elevation_gain_m'] as num?)?.round() ?? 0;
      rides.add(
        Ride(
          id: id,
          title: (map['title'] as String?) ?? 'Ride',
          description: (map['description'] as String?) ?? '',
          startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
          meetingPoint: (map['meeting_point_name'] as String?) ?? '',
          bikeType: _parseBike(map['bike_category'] as String?),
          distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
          elevationM: elev,
          participants: joinedCount[id] ?? 0,
          riderLimit: (map['rider_limit'] as num?)?.round() ?? 12,
          difficulty: _parseDifficulty(map['difficulty'] as String?),
          skillLevel: _parseFitness(map['skill_level'] as String?),
          groupId: groupId,
          groupName: groupNameById[groupId] ?? 'Open ride',
          organizerId: map['organizer_id'] as String?,
          coverGradient: const [Color(0xFF1A7A4C), Color(0xFF0B3D28)],
          elevationProfile: elevProfile.isNotEmpty
              ? elevProfile
              : _syntheticProfile(elev),
          startLat: (map['start_lat'] as num?)?.toDouble() ?? 46.4983,
          startLng: (map['start_lng'] as num?)?.toDouble() ?? 11.3548,
          routeLatLngs: route,
        ),
      );
    }

    for (final g in groups) {
      g.upcomingRideIds
        ..clear()
        ..addAll(
          rides
              .where((r) => r.groupId == g.id && !r.isPast)
              .map((r) => r.id),
        );
    }

    return SharedCatalog(
      groups: groups,
      rides: rides,
      joinedGroupIds: myGroups,
      rsvps: myRsvps,
      rideParticipantIds: participants,
    );
  }

  static Future<CyclingGroup> createGroup({
    required String name,
    required String description,
    required String location,
    required bool isPrivate,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    // Ensure a profile row exists (FK on groups.created_by → profiles).
    await _client.from('profiles').upsert({
      'id': uid,
      'display_name': _client.auth.currentUser?.email?.split('@').first ?? 'Rider',
    });

    final inserted = await _client
        .from('groups')
        .insert({
          'name': name.trim(),
          'description': description.trim(),
          'location_name': location.trim(),
          'visibility': isPrivate ? 'private' : 'public',
          'created_by': uid,
        })
        .select()
        .single();

    final id = inserted['id'] as String;
    await _client.from('group_members').upsert({
      'group_id': id,
      'user_id': uid,
      'role': 'owner',
      'status': 'active',
    });

    return CyclingGroup(
      id: id,
      name: name.trim(),
      description: description.trim(),
      memberCount: 1,
      isPrivate: isPrivate,
      location: location.trim(),
      upcomingRideIds: [],
      coverGradient: const [Color(0xFF1A7A4C), Color(0xFF0F4D32)],
    );
  }

  static Future<Ride> createRide({
    required String title,
    required String description,
    required DateTime startsAt,
    required String meetingPoint,
    required BikeType bikeType,
    required double distanceKm,
    required int elevationM,
    required int riderLimit,
    required Difficulty difficulty,
    required FitnessLevel skillLevel,
    String? groupId,
    required String groupName,
    required List<Color> coverGradient,
    required List<double> elevationProfile,
    required double startLat,
    required double startLng,
    required List<double> routeLatLngs,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    final resolvedGroupId =
        (groupId == null || groupId.isEmpty) ? null : groupId;

    final inserted = await _client
        .from('rides')
        .insert({
          'group_id': resolvedGroupId,
          'organizer_id': uid,
          'title': title.trim(),
          'description': description.trim(),
          'starts_at': startsAt.toUtc().toIso8601String(),
          'meeting_point_name': meetingPoint.trim(),
          'bike_category': bikeType.name,
          'rider_limit': riderLimit,
          'skill_level': skillLevel.name,
          'status': 'published',
          'distance_km': distanceKm,
          'elevation_gain_m': elevationM,
          'difficulty': difficulty.name,
          'elevation_profile': elevationProfile,
          'route_latlngs': routeLatLngs,
          'start_lat': startLat,
          'start_lng': startLng,
        })
        .select()
        .single();

    final id = inserted['id'] as String;
    await _client.from('ride_rsvps').upsert({
      'ride_id': id,
      'user_id': uid,
      'status': 'joined',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return Ride(
      id: id,
      title: title.trim(),
      description: description.trim(),
      startsAt: startsAt,
      meetingPoint: meetingPoint.trim(),
      bikeType: bikeType,
      distanceKm: distanceKm,
      elevationM: elevationM,
      participants: 1,
      riderLimit: riderLimit,
      difficulty: difficulty,
      skillLevel: skillLevel,
      groupId: resolvedGroupId ?? '',
      groupName: groupName,
      organizerId: uid,
      coverGradient: coverGradient,
      elevationProfile: elevationProfile,
      startLat: startLat,
      startLng: startLng,
      routeLatLngs: routeLatLngs,
    );
  }

  static Future<void> setMembership({
    required String groupId,
    required bool join,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (join) {
      await _client.from('group_members').upsert({
        'group_id': groupId,
        'user_id': uid,
        'role': 'member',
        'status': 'active',
      });
    } else {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', uid);
    }
  }

  static Future<void> setRsvp({
    required String rideId,
    required RsvpStatus status,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (status == RsvpStatus.none) {
      await _client
          .from('ride_rsvps')
          .delete()
          .eq('ride_id', rideId)
          .eq('user_id', uid);
      return;
    }
    await _client.from('ride_rsvps').upsert({
      'ride_id': rideId,
      'user_id': uid,
      'status': switch (status) {
        RsvpStatus.joined => 'joined',
        RsvpStatus.maybe => 'maybe',
        RsvpStatus.declined => 'declined',
        RsvpStatus.none => 'declined',
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static BikeType _parseBike(String? raw) {
    return BikeType.values.firstWhere(
      (b) => b.name == raw,
      orElse: () => BikeType.road,
    );
  }

  static Difficulty _parseDifficulty(String? raw) {
    if (raw == null || raw.trim().isEmpty) return Difficulty.moderate;
    final key = raw.trim().toLowerCase();
    return Difficulty.values.firstWhere(
      (d) => d.name == key || d.label.toLowerCase() == key,
      orElse: () => Difficulty.moderate,
    );
  }

  static FitnessLevel _parseFitness(String? raw) {
    return FitnessLevel.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => FitnessLevel.intermediate,
    );
  }

  static RsvpStatus _parseRsvp(String? raw) {
    return switch (raw) {
      'joined' => RsvpStatus.joined,
      'maybe' => RsvpStatus.maybe,
      'declined' => RsvpStatus.declined,
      'waitlist' => RsvpStatus.maybe,
      _ => RsvpStatus.none,
    };
  }

  static List<double> _toDoubleList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final e in value)
        if (e is num) e.toDouble(),
    ];
  }

  static List<double> _syntheticProfile(int elevationM) {
    final base = (elevationM * 0.2).clamp(50, 800).toDouble();
    final peak = elevationM.toDouble().clamp(100, 3000).toDouble();
    return <double>[
      base,
      base + (peak - base) * 0.35,
      peak * 0.85,
      peak,
      peak * 0.7,
      base + (peak - base) * 0.4,
      base,
    ];
  }
}

class SharedCatalog {
  const SharedCatalog({
    required this.groups,
    required this.rides,
    required this.joinedGroupIds,
    required this.rsvps,
    required this.rideParticipantIds,
  });

  final List<CyclingGroup> groups;
  final List<Ride> rides;
  final Set<String> joinedGroupIds;
  final Map<String, RsvpStatus> rsvps;
  final Map<String, List<String>> rideParticipantIds;
}
