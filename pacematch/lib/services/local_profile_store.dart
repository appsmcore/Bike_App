import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Persists onboarding choices + profile prefs on device (per account).
class LocalProfileStore {
  LocalProfileStore._();

  static const _prefix = 'pacematch.profile.v2.';
  static const _lastEmailKey = 'pacematch.last_email.v2';
  static const _legacyPrefix = 'pacematch.profile.v1.';

  static String _idKey(String userId) => '${_prefix}id.${userId.trim()}';

  static String _emailKey(String email) =>
      '${_prefix}email.${email.trim().toLowerCase()}';

  static Future<SavedProfilePrefs?> load({
    String? userId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final candidates = <String>[];

    final id = userId?.trim();
    if (id != null && id.isNotEmpty) {
      candidates.add(_idKey(id));
      // Legacy keys (v1).
      candidates.add('$_legacyPrefix$id');
    }

    final mail = email?.trim().toLowerCase();
    if (mail != null && mail.isNotEmpty) {
      candidates.add(_emailKey(mail));
      candidates.add('${_legacyPrefix}email:$mail');
      // Old buggy interpolation used raw email twice.
      candidates.add('$_legacyPrefix$mail:$mail');
    }

    for (final key in candidates) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final parsed = _decode(raw);
      if (parsed != null) {
        if (kDebugMode) {
          debugPrint('LocalProfileStore.load hit key=$key complete=${parsed.onboardingComplete}');
        }
        return parsed;
      }
    }

    if (kDebugMode) {
      debugPrint(
        'LocalProfileStore.load miss userId=$userId email=$email keys=$candidates',
      );
    }
    return null;
  }

  static Future<void> save({
    required UserProfile profile,
    required bool onboardingComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = SavedProfilePrefs.fromProfile(
      profile,
      onboardingComplete: onboardingComplete,
    ).toJson();
    final encoded = jsonEncode(payload);

    final id = profile.id.trim();
    if (id.isNotEmpty) {
      await prefs.setString(_idKey(id), encoded);
    }

    final mail = profile.email.trim().toLowerCase();
    if (mail.isNotEmpty) {
      await prefs.setString(_emailKey(mail), encoded);
      await prefs.setString(_lastEmailKey, mail);
    }

    if (kDebugMode) {
      debugPrint(
        'LocalProfileStore.save id=$id email=$mail complete=$onboardingComplete',
      );
    }
  }

  static Future<void> clear({String? userId, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = userId?.trim();
    if (id != null && id.isNotEmpty) {
      await prefs.remove(_idKey(id));
      await prefs.remove('$_legacyPrefix$id');
    }
    final mail = email?.trim().toLowerCase();
    if (mail != null && mail.isNotEmpty) {
      await prefs.remove(_emailKey(mail));
      await prefs.remove('${_legacyPrefix}email:$mail');
      await prefs.remove('$_legacyPrefix$mail:$mail');
    }
  }

  static SavedProfilePrefs? _decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SavedProfilePrefs.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

class SavedProfilePrefs {
  const SavedProfilePrefs({
    required this.onboardingComplete,
    required this.bikeTypes,
    required this.fitnessLevel,
    required this.preferredDays,
    required this.preferredDistanceMin,
    required this.preferredDistanceMax,
    required this.preferredElevationMin,
    required this.preferredElevationMax,
    required this.preferredTerrains,
    this.name,
    this.email,
    this.location,
    this.bio,
  });

  final bool onboardingComplete;
  final List<BikeType> bikeTypes;
  final FitnessLevel fitnessLevel;
  final List<String> preferredDays;
  final double preferredDistanceMin;
  final double preferredDistanceMax;
  final int preferredElevationMin;
  final int preferredElevationMax;
  final List<TerrainPref> preferredTerrains;
  final String? name;
  final String? email;
  final String? location;
  final String? bio;

  factory SavedProfilePrefs.fromProfile(
    UserProfile profile, {
    required bool onboardingComplete,
  }) {
    return SavedProfilePrefs(
      onboardingComplete: onboardingComplete,
      bikeTypes: List<BikeType>.from(profile.bikeTypes),
      fitnessLevel: profile.fitnessLevel,
      preferredDays: List<String>.from(profile.preferredDays),
      preferredDistanceMin: profile.preferredDistanceMin,
      preferredDistanceMax: profile.preferredDistanceMax,
      preferredElevationMin: profile.preferredElevationMin,
      preferredElevationMax: profile.preferredElevationMax,
      preferredTerrains: List<TerrainPref>.from(profile.preferredTerrains),
      name: profile.name,
      email: profile.email,
      location: profile.location,
      bio: profile.bio,
    );
  }

  factory SavedProfilePrefs.fromJson(Map<String, dynamic> json) {
    BikeType parseBike(String name) => BikeType.values.firstWhere(
          (b) => b.name == name,
          orElse: () => BikeType.road,
        );
    FitnessLevel parseFitness(String name) => FitnessLevel.values.firstWhere(
          (f) => f.name == name,
          orElse: () => FitnessLevel.intermediate,
        );
    TerrainPref parseTerrain(String name) => TerrainPref.values.firstWhere(
          (t) => t.name == name,
          orElse: () => TerrainPref.flat,
        );

    return SavedProfilePrefs(
      onboardingComplete: json['onboardingComplete'] == true,
      bikeTypes: [
        for (final name in (json['bikeTypes'] as List? ?? const []))
          parseBike('$name'),
      ],
      fitnessLevel: parseFitness('${json['fitnessLevel'] ?? 'intermediate'}'),
      preferredDays: [
        for (final day in (json['preferredDays'] as List? ?? const [])) '$day',
      ],
      preferredDistanceMin:
          (json['preferredDistanceMin'] as num?)?.toDouble() ?? 40,
      preferredDistanceMax:
          (json['preferredDistanceMax'] as num?)?.toDouble() ?? 100,
      preferredElevationMin:
          (json['preferredElevationMin'] as num?)?.round() ?? 200,
      preferredElevationMax:
          (json['preferredElevationMax'] as num?)?.round() ?? 1500,
      preferredTerrains: [
        for (final name in (json['preferredTerrains'] as List? ?? const []))
          parseTerrain('$name'),
      ],
      name: json['name'] as String?,
      email: json['email'] as String?,
      location: json['location'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'onboardingComplete': onboardingComplete,
        'bikeTypes': [for (final b in bikeTypes) b.name],
        'fitnessLevel': fitnessLevel.name,
        'preferredDays': preferredDays,
        'preferredDistanceMin': preferredDistanceMin,
        'preferredDistanceMax': preferredDistanceMax,
        'preferredElevationMin': preferredElevationMin,
        'preferredElevationMax': preferredElevationMax,
        'preferredTerrains': [for (final t in preferredTerrains) t.name],
        'name': name,
        'email': email,
        'location': location,
        'bio': bio,
      };
}
