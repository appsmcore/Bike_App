import 'dart:math' as math;

/// Elevation helpers.
///
/// Climb = **cumulative ascent** (sum of every uphill segment), NOT net
/// elevation change (end − start) and NOT max − min on the chart.
abstract final class ElevationMath {
  /// Moving-average smooth (window odd, >= 3).
  static List<double> smooth(List<double> raw, {int window = 5}) {
    if (raw.length < 3 || window <= 1) return List<double>.from(raw);
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

  /// Sum of all uphill meters along [elevations] (after light smoothing).
  ///
  /// Use the **full** sample list from the router/DEM — never a heavily
  /// downsampled chart series, or intermediate climbs disappear.
  static int cumulativeAscent(
    List<double> elevations, {
    int smoothWindow = 5,
  }) {
    if (elevations.length < 2) return 0;
    final s = smooth(elevations, window: smoothWindow);
    var gain = 0.0;
    for (var i = 1; i < s.length; i++) {
      final d = s[i] - s[i - 1];
      // Count every uphill step; smoothing already removes DEM jitter.
      if (d > 0) gain += d;
    }
    return gain.round();
  }

  /// Pick climb for a route: prefer router ascent, else full-sample sum.
  static int resolveClimb({
    required int apiAscentM,
    required double distanceKm,
    List<double>? fullElevations,
  }) {
    final fromSamples = (fullElevations != null && fullElevations.length >= 2)
        ? cumulativeAscent(fullElevations)
        : 0;

    int chosen;
    if (apiAscentM > 0 && fromSamples > 0) {
      // Router ascent is computed on the full path — trust it when sane.
      // If samples show clearly more climb (API missing downs/ups), take max.
      if (apiAscentM > 8000 && apiAscentM > fromSamples * 2.5) {
        chosen = fromSamples;
      } else {
        chosen = math.max(apiAscentM, fromSamples);
      }
    } else if (apiAscentM > 0) {
      chosen = apiAscentM;
    } else {
      chosen = fromSamples;
    }

    return _capAbsurd(chosen, distanceKm);
  }

  static int _capAbsurd(int ascentM, double distanceKm) {
    if (ascentM <= 0) return 0;
    // ~25% average grade over the whole distance is already extreme for bikes.
    final maxReasonable = distanceKm <= 0
        ? 8000
        : (distanceKm * 250).round().clamp(300, 12000);
    return math.min(ascentM, maxReasonable);
  }

  /// Chart series only (for drawing). Do not use this for climb totals.
  static List<double> profilePoints(List<double> elevations, {int max = 64}) {
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
