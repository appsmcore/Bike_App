import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/elevation_math.dart';

/// Elevation profile with axis labels, climb summary, and a smooth curve.
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.points,
    this.climbM,
    this.distanceKm,
  });

  final List<double> points;
  final int? climbM;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = points.length >= 2;
    final minV = hasData ? points.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxV = hasData ? points.reduce((a, b) => a > b ? a : b) : 0.0;
    // Prefer stored cumulative climb; chart points alone under-count ups/downs.
    final climb = climbM ??
        (hasData ? ElevationMath.cumulativeAscent(points) : 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.forest.withValues(alpha: 0.06),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terrain, size: 18, color: AppColors.forest),
              const SizedBox(width: 6),
              Text(
                'Elevation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (hasData) ...[
                _MetricChip(label: 'Climb', value: '$climb m'),
                const SizedBox(width: 8),
                _MetricChip(label: 'Max', value: '${maxV.round()} m'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            width: double.infinity,
            child: hasData
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 44,
                        child: _YAxisLabels(
                          minM: minV,
                          maxM: maxV,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.stone,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: _ElevationPainter(
                                  points: points,
                                  lineColor: AppColors.forest,
                                  fillTop: AppColors.forest.withValues(alpha: 0.28),
                                  fillBottom:
                                      AppColors.forest.withValues(alpha: 0.02),
                                  gridColor: theme.colorScheme.outline
                                      .withValues(alpha: 0.55),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _XAxisLabels(
                              distanceKm: distanceKm,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.stone,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      'No elevation data',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.stone,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: AppColors.stone,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.forestDeep,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.minM,
    required this.maxM,
    required this.style,
  });

  final double minM;
  final double maxM;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final mid = (minM + maxM) / 2;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${maxM.round()}', style: style),
        Text('${mid.round()}', style: style),
        Text('${minM.round()}', style: style),
      ],
    );
  }
}

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.distanceKm, required this.style});

  final double? distanceKm;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final d = distanceKm;
    final mid = d == null ? '—' : '${(d / 2).toStringAsFixed(d >= 20 ? 0 : 1)} km';
    final end = d == null ? 'End' : '${d.toStringAsFixed(d >= 20 ? 0 : 1)} km';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Start', style: style),
        Text(mid, style: style),
        Text(end, style: style),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({
    required this.points,
    required this.lineColor,
    required this.fillTop,
    required this.fillBottom,
    required this.gridColor,
  });

  final List<double> points;
  final Color lineColor;
  final Color fillTop;
  final Color fillBottom;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    Offset at(int i) {
      final x = size.width * (i / (points.length - 1));
      // Leave vertical padding so peaks/valleys aren't clipped.
      final t = (points[i] - minV) / span;
      final y = size.height * (0.92 - t * 0.84);
      return Offset(x, y);
    }

    // Grid
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var g = 0; g < 3; g++) {
      final y = size.height * (0.08 + (g / 2) * 0.84);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final prev = at(i - 1);
      final curr = at(i);
      final cx = (prev.dx + curr.dx) / 2;
      line.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillTop, fillBottom],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // End dots
    final start = at(0);
    final end = at(points.length - 1);
    canvas.drawCircle(start, 3.5, Paint()..color = lineColor);
    canvas.drawCircle(end, 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillTop != fillTop;
}
