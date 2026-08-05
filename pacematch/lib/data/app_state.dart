import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'fake_data.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  bool onboardingComplete = false;
  ThemeMode themeMode = ThemeMode.system;

  UserProfile profile = demoProfile;
  final Map<String, RsvpStatus> rsvps = {
    'ride-road-1': RsvpStatus.joined,
    'ride-gravel-1': RsvpStatus.joined,
    'ride-mtb-1': RsvpStatus.maybe,
  };
  final Set<String> joinedGroupIds = {'g1', 'g3'};

  late final List<Ride> _rides = createDemoRides();
  late final List<CyclingGroup> _groups = createDemoGroups();

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

  List<Ride> get rides => List.unmodifiable(_rides);
  List<CyclingGroup> get groups => List.unmodifiable(_groups);

  /// Your groups first, then others — by start time within each bucket.
  List<Ride> get recommendedRides {
    final mine = <Ride>[];
    final others = <Ride>[];
    for (final ride in _rides) {
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

  RsvpStatus rsvpFor(String rideId) => rsvps[rideId] ?? RsvpStatus.none;

  bool hasJoinedRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.joined;

  bool hasMaybeRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.maybe;

  void setRsvp(String rideId, RsvpStatus status) {
    if (status == RsvpStatus.none) {
      rsvps.remove(rideId);
    } else {
      rsvps[rideId] = status;
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

  List<Ride> filteredRides({
    BikeType? bikeType,
    Difficulty? difficulty,
    DateTime? day,
    DateTime? month,
  }) {
    return _rides.where((ride) {
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
    return filteredRides(day: day);
  }
}
