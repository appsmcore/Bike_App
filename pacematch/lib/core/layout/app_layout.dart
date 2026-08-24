import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Phone / tablet / desktop width buckets (Material 3).
enum AppSizeClass { compact, medium, expanded }

class AppLayout {
  static const compactWidth = 600.0;
  static const mediumWidth = 840.0;
  static const formMaxWidth = 520.0;
  static const pageMaxWidth = 860.0;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static AppSizeClass sizeClassOf(BuildContext context) {
    final width = sizeOf(context).width;
    if (width < compactWidth) return AppSizeClass.compact;
    if (width < mediumWidth) return AppSizeClass.medium;
    return AppSizeClass.expanded;
  }

  static bool isCompact(BuildContext context) =>
      sizeClassOf(context) == AppSizeClass.compact;

  static bool isLandscape(BuildContext context) =>
      sizeOf(context).width > sizeOf(context).height;

  /// Side inset: tighter on small phones, roomier on tablets.
  static double pageGutter(BuildContext context) {
    final width = sizeOf(context).width;
    if (width < 360) return 12;
    if (width < compactWidth) return 20;
    if (width < mediumWidth) return 28;
    return 36;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 8,
    double extraBottom = 0,
  }) {
    final gutter = pageGutter(context);
    return EdgeInsets.fromLTRB(gutter, top, gutter, gutter + extraBottom);
  }

  static int columnsFor(
    BuildContext context, {
    int compact = 1,
    int medium = 2,
    int expanded = 3,
  }) {
    return switch (sizeClassOf(context)) {
      AppSizeClass.compact => compact,
      AppSizeClass.medium => medium,
      AppSizeClass.expanded => expanded,
    };
  }

  /// Caps system font scaling so layouts stay usable on phones.
  static TextScaler clampedTextScaler(BuildContext context) {
    return MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
  }
}

/// Full-bleed on phones; centered and width-capped on larger displays.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.pageMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = AppLayout.isCompact(context)
            ? constraints.maxWidth
            : maxWidth;
        final width = math.min(cap, constraints.maxWidth);
        // Fill available height so Expanded/ListView children get a viewport.
        final child = constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite
            ? SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: this.child,
              )
            : SizedBox(width: width, child: this.child);
        return Align(alignment: alignment, child: child);
      },
    );
  }
}

/// Choice tiles that grow to fill leftover height, or scroll if the
/// screen is too short (small phone + large text).
class FillChoiceGrid extends StatelessWidget {
  const FillChoiceGrid({
    super.key,
    required this.itemCount,
    required this.columns,
    required this.itemBuilder,
    this.spacing = 12,
    this.minItemHeight = 84,
  });

  final int itemCount;
  final int columns;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;
  final double minItemHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _rows();
        if (rows.isEmpty) return const SizedBox.shrink();

        final bounded =
            constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0;
        if (!bounded) {
          return _scrolling(context, rows);
        }

        final rowHeight =
            (constraints.maxHeight - spacing * (rows.length - 1)) / rows.length;
        if (rowHeight < minItemHeight) {
          return _scrolling(context, rows);
        }

        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < rows[r].length; c++) ...[
                      if (c > 0) SizedBox(width: spacing),
                      Expanded(child: itemBuilder(context, rows[r][c])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<List<int>> _rows() {
    final rows = <List<int>>[];
    final cols = columns.clamp(1, itemCount < 1 ? 1 : itemCount);
    for (var i = 0; i < itemCount; i += cols) {
      final end = (i + cols).clamp(0, itemCount);
      rows.add([for (var j = i; j < end; j++) j]);
    }
    return rows;
  }

  Widget _scrolling(BuildContext context, List<List<int>> rows) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (context, r) {
        return SizedBox(
          height: minItemHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(child: itemBuilder(context, rows[r][c])),
              ],
            ],
          ),
        );
      },
    );
  }
}
