import 'dart:typed_data';

import 'package:flutter/material.dart';

enum BikeType { road, mtb, gravel, touring, ebike }

enum FitnessLevel { beginner, intermediate, advanced, expert }

enum Difficulty { easy, moderate, challenging, expert }

enum RsvpStatus { none, joined, maybe, declined }

enum TerrainPref { flat, climbs }

extension BikeTypeX on BikeType {
  String get label => switch (this) {
        BikeType.road => 'Road',
        BikeType.mtb => 'MTB',
        BikeType.gravel => 'Gravel',
        BikeType.touring => 'Touring',
        BikeType.ebike => 'E-Bike',
      };

  IconData get icon => switch (this) {
        BikeType.road => Icons.directions_bike,
        BikeType.mtb => Icons.terrain,
        BikeType.gravel => Icons.alt_route,
        BikeType.touring => Icons.luggage,
        BikeType.ebike => Icons.electric_bike,
      };

  String get shortCode => switch (this) {
        BikeType.road => 'RD',
        BikeType.mtb => 'MTB',
        BikeType.gravel => 'GR',
        BikeType.touring => 'TR',
        BikeType.ebike => 'E',
      };
}

extension FitnessLevelX on FitnessLevel {
  String get label => switch (this) {
        FitnessLevel.beginner => 'Beginner',
        FitnessLevel.intermediate => 'Intermediate',
        FitnessLevel.advanced => 'Advanced',
        FitnessLevel.expert => 'Expert',
      };

  /// Fun nickname so levels are easier to understand.
  String get funLabel => switch (this) {
        FitnessLevel.beginner => 'Coffee-stop cruiser',
        FitnessLevel.intermediate => 'Weekend warrior',
        FitnessLevel.advanced => 'Climb crusher',
        FitnessLevel.expert => 'Pass hunter',
      };

  String get fullLabel => '$label — $funLabel';
}

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.moderate => 'Moderate',
        Difficulty.challenging => 'Challenging',
        Difficulty.expert => 'Expert',
      };

  String get emoji => switch (this) {
        Difficulty.easy => '🟢',
        Difficulty.moderate => '🔵',
        Difficulty.challenging => '🟠',
        Difficulty.expert => '🔴',
      };

  Color get color => switch (this) {
        Difficulty.easy => const Color(0xFF2E7D4F),
        Difficulty.moderate => const Color(0xFF2F6FED),
        Difficulty.challenging => const Color(0xFFE0872A),
        Difficulty.expert => const Color(0xFFC62828),
      };
}

extension TerrainPrefX on TerrainPref {
  String get label => switch (this) {
        TerrainPref.flat => 'Flat routes',
        TerrainPref.climbs => 'Mountain / climbs',
      };
}

class Ride {
  Ride({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.meetingPoint,
    required this.bikeType,
    required this.distanceKm,
    required this.elevationM,
    required this.participants,
    required this.riderLimit,
    required this.difficulty,
    required this.skillLevel,
    required this.groupId,
    required this.groupName,
    required this.coverGradient,
    required this.elevationProfile,
    required this.startLat,
    required this.startLng,
    this.organizerId,
    this.routeLatLngs = const [],
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final String meetingPoint;
  final BikeType bikeType;
  final double distanceKm;
  final int elevationM;
  final int participants;
  final int riderLimit;
  final Difficulty difficulty;
  final FitnessLevel skillLevel;
  final String groupId;
  final String groupName;
  final List<Color> coverGradient;
  final List<double> elevationProfile;
  final double startLat;
  final double startLng;

  /// User id of who offered the ride. Null for legacy demo rows without one.
  final String? organizerId;

  /// Route geometry as [lat, lng, lat, lng, ...] pairs. Empty = start pin only.
  final List<double> routeLatLngs;

  bool get hasRoute => routeLatLngs.length >= 4;

  bool get isPast => startsAt.isBefore(DateTime.now());
}

/// A photo memory attached to a completed ride.
class RidePhoto {
  RidePhoto({
    required this.id,
    required this.rideId,
    required this.uploaderId,
    required this.createdAt,
    this.caption,
    this.bytes,
    this.moodGradient,
  });

  final String id;
  final String rideId;
  final String uploaderId;
  final DateTime createdAt;
  final String? caption;

  /// User-picked image bytes (in-memory for the mock app).
  final Uint8List? bytes;

  /// Branded gradient used for seeded demo memories without real photos.
  final List<Color>? moodGradient;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

/// A chat message in a cycling group thread.
class GroupMessage {
  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

/// Public rider card used for co-riders and profile peeks.
class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.location,
    required this.bio,
    required this.bikeTypes,
    required this.fitnessLevel,
    required this.ridesJoined,
    required this.ridesOrganized,
    required this.reliabilityScore,
    required this.communityScore,
    required this.badges,
    this.accentColor = const Color(0xFF1A7A4C),
    this.tagline,
  });

  final String id;
  final String name;
  final String location;
  final String bio;
  final List<BikeType> bikeTypes;
  final FitnessLevel fitnessLevel;
  final int ridesJoined;
  final int ridesOrganized;
  final int reliabilityScore;
  final int communityScore;
  final List<String> badges;
  final Color accentColor;
  final String? tagline;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Aggregated shared riding stats with one companion.
class CompanionStats {
  const CompanionStats({
    required this.rider,
    required this.sharedRides,
    required this.sharedKm,
    required this.sharedElevationM,
    required this.longestRideKm,
    required this.biggestClimbM,
    required this.morningRides,
    required this.weekendRides,
    required this.hardRides,
  });

  final RiderProfile rider;
  final int sharedRides;
  final double sharedKm;
  final int sharedElevationM;
  final double longestRideKm;
  final int biggestClimbM;
  final int morningRides;
  final int weekendRides;
  final int hardRides;
}

enum CompanionRankMetric {
  sharedKm,
  sharedElevation,
  sharedRides,
  longestRide,
  biggestClimb,
  earlyBird,
  weekendWarrior,
  climbDuo,
}

extension CompanionRankMetricX on CompanionRankMetric {
  String get label => switch (this) {
        CompanionRankMetric.sharedKm => 'Most km together',
        CompanionRankMetric.sharedElevation => 'Most elevation together',
        CompanionRankMetric.sharedRides => 'Most rides together',
        CompanionRankMetric.longestRide => 'Longest shared ride',
        CompanionRankMetric.biggestClimb => 'Biggest climb together',
        CompanionRankMetric.earlyBird => 'Early-bird buddies',
        CompanionRankMetric.weekendWarrior => 'Weekend warriors',
        CompanionRankMetric.climbDuo => 'Climb crusher duo',
      };

  String get subtitle => switch (this) {
        CompanionRankMetric.sharedKm => 'Who rolled the most distance with you',
        CompanionRankMetric.sharedElevation => 'Who suffered the most vertical with you',
        CompanionRankMetric.sharedRides => 'Your most frequent co-riders',
        CompanionRankMetric.longestRide => 'Partners on your longest days',
        CompanionRankMetric.biggestClimb => 'Who climbed the steepest with you',
        CompanionRankMetric.earlyBird => 'Most rides starting before 8:00',
        CompanionRankMetric.weekendWarrior => 'Most Sat/Sun rides together',
        CompanionRankMetric.climbDuo => 'Most challenging+ rides together',
      };

  IconData get icon => switch (this) {
        CompanionRankMetric.sharedKm => Icons.route,
        CompanionRankMetric.sharedElevation => Icons.terrain,
        CompanionRankMetric.sharedRides => Icons.groups,
        CompanionRankMetric.longestRide => Icons.straighten,
        CompanionRankMetric.biggestClimb => Icons.trending_up,
        CompanionRankMetric.earlyBird => Icons.wb_sunny_outlined,
        CompanionRankMetric.weekendWarrior => Icons.weekend_outlined,
        CompanionRankMetric.climbDuo => Icons.landscape_outlined,
      };
}

class CyclingGroup {
  CyclingGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.isPrivate,
    required this.location,
    required this.upcomingRideIds,
    required this.coverGradient,
  });

  final String id;
  final String name;
  final String description;
  int memberCount;
  final bool isPrivate;
  final String location;
  final List<String> upcomingRideIds;
  final List<Color> coverGradient;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.location,
    required this.bio,
    required this.bikeTypes,
    required this.fitnessLevel,
    required this.preferredDistanceMin,
    required this.preferredDistanceMax,
    required this.preferredElevationMin,
    required this.preferredElevationMax,
    required this.preferredTerrains,
    required this.preferredDays,
    required this.ridesJoined,
    required this.ridesOrganized,
    required this.reliabilityScore,
    required this.communityScore,
    required this.badges,
    this.bikePhotoBytes,
  });

  final String id;
  final String name;
  final String email;
  final String location;
  final String bio;
  final List<BikeType> bikeTypes;
  final FitnessLevel fitnessLevel;
  final double preferredDistanceMin;
  final double preferredDistanceMax;
  final int preferredElevationMin;
  final int preferredElevationMax;
  final List<TerrainPref> preferredTerrains;
  final List<String> preferredDays;
  final int ridesJoined;
  final int ridesOrganized;
  final int reliabilityScore;
  final int communityScore;
  final List<String> badges;
  final Uint8List? bikePhotoBytes;

  RiderProfile toPublicRider() => RiderProfile(
        id: id,
        name: name,
        location: location,
        bio: bio,
        bikeTypes: bikeTypes,
        fitnessLevel: fitnessLevel,
        ridesJoined: ridesJoined,
        ridesOrganized: ridesOrganized,
        reliabilityScore: reliabilityScore,
        communityScore: communityScore,
        badges: badges,
        tagline: 'That’s you',
      );

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? location,
    String? bio,
    List<BikeType>? bikeTypes,
    FitnessLevel? fitnessLevel,
    double? preferredDistanceMin,
    double? preferredDistanceMax,
    int? preferredElevationMin,
    int? preferredElevationMax,
    List<TerrainPref>? preferredTerrains,
    List<String>? preferredDays,
    int? ridesJoined,
    int? ridesOrganized,
    int? reliabilityScore,
    int? communityScore,
    List<String>? badges,
    Uint8List? bikePhotoBytes,
    bool clearBikePhoto = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      bikeTypes: bikeTypes ?? this.bikeTypes,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      preferredDistanceMin: preferredDistanceMin ?? this.preferredDistanceMin,
      preferredDistanceMax: preferredDistanceMax ?? this.preferredDistanceMax,
      preferredElevationMin: preferredElevationMin ?? this.preferredElevationMin,
      preferredElevationMax: preferredElevationMax ?? this.preferredElevationMax,
      preferredTerrains: preferredTerrains ?? this.preferredTerrains,
      preferredDays: preferredDays ?? this.preferredDays,
      ridesJoined: ridesJoined ?? this.ridesJoined,
      ridesOrganized: ridesOrganized ?? this.ridesOrganized,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      communityScore: communityScore ?? this.communityScore,
      badges: badges ?? this.badges,
      bikePhotoBytes:
          clearBikePhoto ? null : (bikePhotoBytes ?? this.bikePhotoBytes),
    );
  }
}
