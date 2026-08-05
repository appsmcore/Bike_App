import 'dart:math' as math;

/// Shared elevation helpers — filters DEM/GPS noise that otherwise inflates climb.
abstract final class ElevationMath {
  /// Moving-average smooth (window odd, >= 3).
  static List<double> smooth(List<double> raw, {int window = 5}) {
    if (raw.length < 3) return List<double>.from(raw);
    final w = window.isOdd ? window : window + 1;
    final half = w ~/ 2;
    final out = <double>[];
    for (var i = 0; i < raw.length; i++) {
      var sum = 0.0;
      var n = 0;
      for (var j = i - half; j <= i + half; j++) {
        if (j < 0 || j >= raw.length) continue;
        sum += raw[j];
        n++;
      }
      out.add(sum / n);
    }
    return out;
  }

  /// Cumulative ascent in meters after smoothing.
  /// Ignores tiny ups (DEM noise) below [minStepM].
  static int ascentMeters(
    List<double> elevations, {
    double minStepM = 4,
    int smoothWindow = 5,
  }) {
    if (elevations.length < 2) return 0;
    final s = smooth(elevations, window: smoothWindow);
    var gain = 0.0;
    for (var i = 1; i < s.length; i++) {
      final d = s[i] - s[i - 1];
      if (d > minStepM) gain += d;
    }
    return gain.round();
  }

  /// Reject absurd climb numbers (e.g. 34000 m from noisy samples).
  static int sanitizeAscent({
    required int ascentM,
    required double distanceKm,
    List<double>? elevations,
  }) {
    if (ascentM <= 0) {
      if (elevations != null && elevations.length >= 2) {
        return sanitizeAscent(
          ascentM: ascentMeters(elevations),
          distanceKm: distanceKm,
        );
      }
      return 0;
    }

    // Hard physical-ish caps for bike routes.
    final byDistance = distanceKm <= 0
        ? 6000
        : (distanceKm * 180).round().clamp(200, 8000); // ~18% avg grade max
    final capped = math.min(ascentM, byDistance);

    // If API value looks insane vs recomputed profile, prefer recomputed.
    if (elevations != null && elevations.length >= 2) {
      final recomputed = ascentMeters(elevations);
      if (ascentM > 5000 || ascentM > recomputed * 3 + 200) {
        return sanitizeAscent(
          ascentM: recomputed,
          distanceKm: distanceKm,
        );
      }
    }

    return capped;
  }

  static List<double> profilePoints(List<double> elevations, {int max = 48}) {
    if (elevations.isEmpty) return const [];
    final s = smooth(elevations, window: 5);
    if (s.length <= max) return s;
    final out = <double>[];
    final step = (s.length - 1) / (max - 1);
    for (var i = 0; i < max; i++) {
      final idx = (i * step).round().clamp(0, s.length - 1);
      out.add(s[idx]);
    }
    return out;
  }
}
