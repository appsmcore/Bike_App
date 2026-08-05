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

  /// Route geometry as [lat, lng, lat, lng, ...] pairs. Empty = start pin only.
  final List<double> routeLatLngs;

  bool get hasRoute => routeLatLngs.length >= 4;
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

  UserProfile copyWith({
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
