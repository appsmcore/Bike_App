import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'fake_data.dart';
import 'models.dart';
import 'route_models.dart';

class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  bool onboardingComplete = false;
  ThemeMode themeMode = ThemeMode.system;

  UserProfile profile = demoProfile;
  final Map<String, RsvpStatus> rsvps = {
    'ride-road-1': RsvpStatus.joined,
    'ride-gravel-1': RsvpStatus.joined,
    'ride-mtb-1': RsvpStatus.maybe,
    'ride-past-1': RsvpStatus.joined,
    'ride-past-2': RsvpStatus.joined,
    'ride-past-3': RsvpStatus.joined,
    'ride-past-4': RsvpStatus.joined,
    'ride-past-5': RsvpStatus.joined,
    'ride-offered-1': RsvpStatus.joined,
    'ride-offered-2': RsvpStatus.joined,
  };
  final Set<String> joinedGroupIds = {'g1', 'g3'};

  late final List<Ride> _rides = createDemoRides();
  late final List<CyclingGroup> _groups = createDemoGroups();
  late final List<RiderProfile> _riders = createDemoRiders();
  late final Map<String, List<String>> _rideParticipantIds =
      createDemoRideParticipants();
  late final List<RidePhoto> _ridePhotos = createDemoRidePhotos();
  late final List<GroupMessage> _groupMessages = createDemoGroupMessages();
  final List<SavedRoute> _savedRoutes = [];

  // Onboarding draft
  final Set<BikeType> draftBikes = {BikeType.road};
  FitnessLevel draftFitness = FitnessLevel.intermediate;
  final Set<String> draftDays = {'Sat', 'Sun'};
  RangeValues draftDistance = const RangeValues(40, 100);
  RangeValues draftElevation = const RangeValues(200, 1500);
  final Set<TerrainPref> draftTerrains = {
    TerrainPref.flat,
    TerrainPref.climbs,
  };

  String get currentUserId => profile.id;

  List<Ride> get rides => List.unmodifiable(_rides);
  List<CyclingGroup> get groups => List.unmodifiable(_groups);
  List<RiderProfile> get riders => List.unmodifiable(_riders);
  List<SavedRoute> get savedRoutes => List.unmodifiable(_savedRoutes);

  /// Persist a planned route for later inspiration (not shown on home map).
  SavedRoute savePlannedRoute(
    PlannedRoute route, {
    String? name,
  }) {
    final stamp = DateTime.now();
    final label = (name == null || name.trim().isEmpty)
        ? '${route.bikeType.label} · ${route.distanceKm.toStringAsFixed(1)} km'
        : name.trim();
    final saved = SavedRoute(
      id: 'route-${stamp.millisecondsSinceEpoch}',
      name: label,
      createdAt: stamp,
      route: route,
      createdByUserId: currentUserId,
    );
    _savedRoutes.insert(0, saved);
    notifyListeners();
    return saved;
  }

  void deleteSavedRoute(String id) {
    _savedRoutes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  SavedRoute? savedRouteById(String id) {
    try {
      return _savedRoutes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Your groups first, then others — by start time within each bucket.
  /// Past rides are kept out of the home finder.
  List<Ride> get recommendedRides {
    final mine = <Ride>[];
    final others = <Ride>[];
    for (final ride in _rides) {
      if (ride.isPast) continue;
      if (joinedGroupIds.contains(ride.groupId)) {
        mine.add(ride);
      } else {
        others.add(ride);
      }
    }
    int byTime(Ride a, Ride b) => a.startsAt.compareTo(b.startsAt);
    mine.sort(byTime);
    others.sort(byTime);
    return [...mine, ...others];
  }

  Ride? rideById(String id) {
    try {
      return _rides.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  CyclingGroup? groupById(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  RiderProfile? riderById(String id) {
    if (id == currentUserId) return profile.toPublicRider();
    try {
      return _riders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  RsvpStatus rsvpFor(String rideId) => rsvps[rideId] ?? RsvpStatus.none;

  bool hasJoinedRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.joined;

  bool hasMaybeRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.maybe;

  /// Confirmed riders for a ride. Only available once you've joined.
  List<RiderProfile> confirmedRidersFor(String rideId, {bool includeSelf = true}) {
    if (!hasJoinedRsvp(rideId) && !isOrganizerOf(rideId)) {
      return const [];
    }
    final ids = _rideParticipantIds[rideId] ?? const <String>[];
    final riders = <RiderProfile>[];
    final seen = <String>{};

    if (includeSelf && hasJoinedRsvp(rideId)) {
      riders.add(profile.toPublicRider());
      seen.add(currentUserId);
    }

    for (final id in ids) {
      if (seen.contains(id)) continue;
      final rider = riderById(id);
      if (rider != null) {
        riders.add(rider);
        seen.add(id);
      }
    }

    final ride = rideById(rideId);
    final organizerId = ride?.organizerId;
    if (organizerId != null && !seen.contains(organizerId)) {
      final organizer = riderById(organizerId);
      if (organizer != null) {
        riders.insert(0, organizer);
      }
    }

    return riders;
  }

  bool canSeeParticipants(String rideId) =>
      hasJoinedRsvp(rideId) || isOrganizerOf(rideId);

  bool isOrganizerOf(String rideId) {
    final ride = rideById(rideId);
    return ride?.organizerId == currentUserId;
  }

  void setRsvp(String rideId, RsvpStatus status) {
    final previous = rsvpFor(rideId);
    if (status == RsvpStatus.none) {
      rsvps.remove(rideId);
    } else {
      rsvps[rideId] = status;
    }

    final list = _rideParticipantIds.putIfAbsent(rideId, () => <String>[]);
    if (status == RsvpStatus.joined && previous != RsvpStatus.joined) {
      if (!list.contains(currentUserId)) list.add(currentUserId);
    } else if (status != RsvpStatus.joined && previous == RsvpStatus.joined) {
      list.remove(currentUserId);
    }

    notifyListeners();
  }

  void toggleTheme() {
    themeMode = switch (themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    notifyListeners();
  }

  void login({String? email, String? name}) {
    isAuthenticated = true;
    if (email != null || name != null) {
      profile = profile.copyWith(
        email: email ?? profile.email,
        name: name ?? profile.name,
      );
    }
    notifyListeners();
  }

  void register({required String name, required String email}) {
    profile = profile.copyWith(name: name, email: email);
    isAuthenticated = true;
    onboardingComplete = false;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    onboardingComplete = false;
    rsvps.clear();
    notifyListeners();
  }

  void completeOnboarding() {
    if (draftTerrains.isEmpty) {
      draftTerrains.addAll({TerrainPref.flat, TerrainPref.climbs});
    }
    profile = profile.copyWith(
      bikeTypes: draftBikes.toList(),
      fitnessLevel: draftFitness,
      preferredDays: draftDays.toList(),
      preferredDistanceMin: draftDistance.start,
      preferredDistanceMax: draftDistance.end,
      preferredElevationMin: draftElevation.start.round(),
      preferredElevationMax: draftElevation.end.round(),
      preferredTerrains: draftTerrains.toList(),
    );
    onboardingComplete = true;
    notifyListeners();
  }

  void toggleDraftBike(BikeType type) {
    if (draftBikes.contains(type)) {
      if (draftBikes.length > 1) draftBikes.remove(type);
    } else {
      draftBikes.add(type);
    }
    notifyListeners();
  }

  void setDraftFitness(FitnessLevel level) {
    draftFitness = level;
    notifyListeners();
  }

  void toggleDraftDay(String day) {
    if (draftDays.contains(day)) {
      draftDays.remove(day);
    } else {
      draftDays.add(day);
    }
    notifyListeners();
  }

  void setDraftDistance(RangeValues values) {
    draftDistance = values;
    notifyListeners();
  }

  void setDraftElevation(RangeValues values) {
    draftElevation = values;
    notifyListeners();
  }

  void toggleDraftTerrain(TerrainPref terrain) {
    if (draftTerrains.contains(terrain)) {
      if (draftTerrains.length > 1) draftTerrains.remove(terrain);
    } else {
      draftTerrains.add(terrain);
    }
    notifyListeners();
  }

  void toggleGroupMembership(String groupId) {
    if (joinedGroupIds.contains(groupId)) {
      joinedGroupIds.remove(groupId);
    } else {
      joinedGroupIds.add(groupId);
    }
    notifyListeners();
  }

  bool isMemberOf(String groupId) => joinedGroupIds.contains(groupId);

  CyclingGroup createGroup({
    required String name,
    required String description,
    required String location,
    required bool isPrivate,
  }) {
    final id = 'g-${DateTime.now().millisecondsSinceEpoch}';
    final group = CyclingGroup(
      id: id,
      name: name,
      description: description,
      memberCount: 1,
      isPrivate: isPrivate,
      location: location,
      upcomingRideIds: [],
      coverGradient: const [Color(0xFF1A7A4C), Color(0xFF0F4D32)],
    );
    _groups.insert(0, group);
    joinedGroupIds.add(id);
    notifyListeners();
    return group;
  }

  Ride createRide({
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
    required String groupId,
    double? startLat,
    double? startLng,
    List<double>? elevationProfile,
    List<double> routeLatLngs = const [],
  }) {
    final group = groupById(groupId);
    final id = 'ride-${DateTime.now().millisecondsSinceEpoch}';
    final ride = Ride(
      id: id,
      title: title,
      description: description,
      startsAt: startsAt,
      meetingPoint: meetingPoint,
      bikeType: bikeType,
      distanceKm: distanceKm,
      elevationM: elevationM,
      participants: 1,
      riderLimit: riderLimit,
      difficulty: difficulty,
      skillLevel: skillLevel,
      groupId: groupId,
      groupName: group?.name ?? 'Open ride',
      organizerId: currentUserId,
      coverGradient: group?.coverGradient ??
          const [Color(0xFF1A7A4C), Color(0xFF0B3D28)],
      elevationProfile: elevationProfile ?? _syntheticProfile(elevationM),
      startLat: startLat ?? 46.4983,
      startLng: startLng ?? 11.3548,
      routeLatLngs: routeLatLngs,
    );
    _rides.insert(0, ride);
    group?.upcomingRideIds.insert(0, id);
    rsvps[id] = RsvpStatus.joined;
    _rideParticipantIds[id] = [currentUserId];
    profile = profile.copyWith(ridesOrganized: profile.ridesOrganized + 1);
    if (group != null && !joinedGroupIds.contains(groupId)) {
      joinedGroupIds.add(groupId);
    }
    notifyListeners();
    return ride;
  }

  List<double> _syntheticProfile(int elevationM) {
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

  void setBikePhoto(Uint8List? bytes) {
    profile = bytes == null
        ? profile.copyWith(clearBikePhoto: true)
        : profile.copyWith(bikePhotoBytes: bytes);
    notifyListeners();
  }

  List<RidePhoto> get ridePhotos => List.unmodifiable(_ridePhotos);

  List<RidePhoto> photosForRide(String rideId) {
    final list =
        _ridePhotos.where((p) => p.rideId == rideId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<RidePhoto> photosForUser(String userId) {
    final list =
        _ridePhotos.where((p) => p.uploaderId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Whether the current user can attach memories to this ride.
  bool canAddPhotosToRide(String rideId) {
    final ride = rideById(rideId);
    if (ride == null || !ride.isPast) return false;
    return hasJoinedRsvp(rideId) || isOrganizerOf(rideId);
  }

  void addRidePhotos({
    required String rideId,
    required List<Uint8List> images,
    String? caption,
  }) {
    if (images.isEmpty || !canAddPhotosToRide(rideId)) return;
    final now = DateTime.now();
    for (var i = 0; i < images.length; i++) {
      _ridePhotos.insert(
        0,
        RidePhoto(
          id: 'photo-${now.millisecondsSinceEpoch}-$i',
          rideId: rideId,
          uploaderId: currentUserId,
          createdAt: now.add(Duration(milliseconds: i)),
          caption: i == 0 ? caption : null,
          bytes: images[i],
        ),
      );
    }
    notifyListeners();
  }

  void removeRidePhoto(String photoId) {
    _ridePhotos.removeWhere(
      (p) => p.id == photoId && p.uploaderId == currentUserId,
    );
    notifyListeners();
  }

  /// Chronological messages for a group chat (oldest first).
  List<GroupMessage> messagesForGroup(String groupId) {
    final list =
        _groupMessages.where((m) => m.groupId == groupId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  GroupMessage? latestMessageForGroup(String groupId) {
    final messages = messagesForGroup(groupId);
    if (messages.isEmpty) return null;
    return messages.last;
  }

  /// Members can post to the group thread.
  GroupMessage? sendGroupMessage(String groupId, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || !isMemberOf(groupId) || groupById(groupId) == null) {
      return null;
    }
    final message = GroupMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: currentUserId,
      body: trimmed,
      createdAt: DateTime.now(),
    );
    _groupMessages.add(message);
    notifyListeners();
    return message;
  }

  List<Ride> filteredRides({
    BikeType? bikeType,
    Difficulty? difficulty,
    DateTime? day,
    DateTime? month,
    bool includePast = false,
  }) {
    return _rides.where((ride) {
      if (!includePast && ride.isPast) return false;
      if (bikeType != null && ride.bikeType != bikeType) return false;
      if (difficulty != null && ride.difficulty != difficulty) return false;
      if (day != null) {
        final sameDay = ride.startsAt.year == day.year &&
            ride.startsAt.month == day.month &&
            ride.startsAt.day == day.day;
        if (!sameDay) return false;
      }
      if (month != null) {
        if (ride.startsAt.year != month.year ||
            ride.startsAt.month != month.month) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aMine = joinedGroupIds.contains(a.groupId);
        final bMine = joinedGroupIds.contains(b.groupId);
        if (aMine != bMine) return aMine ? -1 : 1;
        return a.startsAt.compareTo(b.startsAt);
      });
  }

  List<Ride> ridesOnDay(DateTime day) {
    return filteredRides(day: day, includePast: true);
  }

  /// Past rides you joined (completed).
  List<Ride> get completedRides {
    final list = _rides
        .where((r) => r.isPast && hasJoinedRsvp(r.id))
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return list;
  }

  /// Rides you offered / organized.
  List<Ride> get offeredRides {
    final list = _rides
        .where((r) => r.organizerId == currentUserId)
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return list;
  }

  /// Upcoming rides you've confirmed.
  List<Ride> get upcomingJoinedRides {
    final list = _rides
        .where((r) => !r.isPast && hasJoinedRsvp(r.id))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  double get lifetimeJoinedKm =>
      completedRides.fold(0.0, (sum, r) => sum + r.distanceKm);

  int get lifetimeJoinedElevationM =>
      completedRides.fold(0, (sum, r) => sum + r.elevationM);

  List<Ride> _sharedPastRidesWith(String riderId) {
    return completedRides.where((ride) {
      final others = _rideParticipantIds[ride.id] ?? const <String>[];
      return others.contains(riderId) || ride.organizerId == riderId;
    }).toList();
  }

  List<CompanionStats> get companionStats {
    final byRider = <String, CompanionStats>{};

    for (final ride in completedRides) {
      final ids = <String>{
        ...(_rideParticipantIds[ride.id] ?? const <String>[]),
        if (ride.organizerId != null) ride.organizerId!,
      }..remove(currentUserId);

      final isMorning = ride.startsAt.hour < 8;
      final isWeekend = ride.startsAt.weekday == DateTime.saturday ||
          ride.startsAt.weekday == DateTime.sunday;
      final isHard = ride.difficulty == Difficulty.challenging ||
          ride.difficulty == Difficulty.expert;

      for (final id in ids) {
        final rider = riderById(id);
        if (rider == null) continue;
        final existing = byRider[id];
        if (existing == null) {
          byRider[id] = CompanionStats(
            rider: rider,
            sharedRides: 1,
            sharedKm: ride.distanceKm,
            sharedElevationM: ride.elevationM,
            longestRideKm: ride.distanceKm,
            biggestClimbM: ride.elevationM,
            morningRides: isMorning ? 1 : 0,
            weekendRides: isWeekend ? 1 : 0,
            hardRides: isHard ? 1 : 0,
          );
        } else {
          byRider[id] = CompanionStats(
            rider: rider,
            sharedRides: existing.sharedRides + 1,
            sharedKm: existing.sharedKm + ride.distanceKm,
            sharedElevationM: existing.sharedElevationM + ride.elevationM,
            longestRideKm: ride.distanceKm > existing.longestRideKm
                ? ride.distanceKm
                : existing.longestRideKm,
            biggestClimbM: ride.elevationM > existing.biggestClimbM
                ? ride.elevationM
                : existing.biggestClimbM,
            morningRides: existing.morningRides + (isMorning ? 1 : 0),
            weekendRides: existing.weekendRides + (isWeekend ? 1 : 0),
            hardRides: existing.hardRides + (isHard ? 1 : 0),
          );
        }
      }
    }

    return byRider.values.toList();
  }

  List<CompanionStats> companionsRankedBy(CompanionRankMetric metric) {
    final list = List<CompanionStats>.from(companionStats);
    int valueOf(CompanionStats c) => switch (metric) {
          CompanionRankMetric.sharedKm => c.sharedKm.round(),
          CompanionRankMetric.sharedElevation => c.sharedElevationM,
          CompanionRankMetric.sharedRides => c.sharedRides,
          CompanionRankMetric.longestRide => c.longestRideKm.round(),
          CompanionRankMetric.biggestClimb => c.biggestClimbM,
          CompanionRankMetric.earlyBird => c.morningRides,
          CompanionRankMetric.weekendWarrior => c.weekendRides,
          CompanionRankMetric.climbDuo => c.hardRides,
        };

    list.removeWhere((c) => valueOf(c) <= 0);
    list.sort((a, b) {
      final cmp = valueOf(b).compareTo(valueOf(a));
      if (cmp != 0) return cmp;
      return a.rider.name.compareTo(b.rider.name);
    });
    return list;
  }

  String companionMetricLabel(CompanionStats stats, CompanionRankMetric metric) {
    return switch (metric) {
      CompanionRankMetric.sharedKm => '${stats.sharedKm.round()} km',
      CompanionRankMetric.sharedElevation => '${stats.sharedElevationM} m',
      CompanionRankMetric.sharedRides => '${stats.sharedRides} rides',
      CompanionRankMetric.longestRide => '${stats.longestRideKm.round()} km',
      CompanionRankMetric.biggestClimb => '${stats.biggestClimbM} m',
      CompanionRankMetric.earlyBird => '${stats.morningRides} early starts',
      CompanionRankMetric.weekendWarrior => '${stats.weekendRides} weekends',
      CompanionRankMetric.climbDuo => '${stats.hardRides} hard days',
    };
  }

  /// Shared past rides with a companion (for rider profile).
  List<Ride> sharedPastRidesWith(String riderId) => _sharedPastRidesWith(riderId);
}
