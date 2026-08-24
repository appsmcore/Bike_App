import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  Future<void> _next(AppState state) async {
    if (_index == 0 && state.draftBikes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one bike type to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_index < 2) {
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      await state.completeOnboarding();
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final gutter = AppLayout.pageGutter(context);

    return Scaffold(
      body: SafeArea(
        child: AdaptiveBody(
          maxWidth: 720,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Set up PaceMatch',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text('${_index + 1}/3'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: LinearProgressIndicator(value: (_index + 1) / 3),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _BikeStep(state: state),
                    _FitnessStep(state: state),
                    _PrefsStep(state: state),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
                child: FilledButton(
                  onPressed: (_index == 0 && state.draftBikes.isEmpty)
                      ? null
                      : () => _next(state),
                  child: Text(_index == 2 ? 'Finish' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BikeStep extends StatelessWidget {
  const _BikeStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bikes = BikeType.values;
    final compact = AppLayout.isCompact(context);
    final landscape = AppLayout.isLandscape(context);
    final columns = compact
        ? (landscape ? 3 : 2)
        : AppLayout.columnsFor(context, compact: 2, medium: 3, expanded: 3);

    return _StepFrame(
      title: 'Which bikes do you ride?',
      subtitle: 'Pick one or more.',
      child: FillChoiceGrid(
        itemCount: bikes.length,
        columns: columns,
        itemBuilder: (context, index) {
          final bike = bikes[index];
          return _ChoiceCard(
            selected: state.draftBikes.contains(bike),
            onTap: () => state.toggleDraftBike(bike),
            child: _CardLabel(icon: bike.icon, title: bike.label),
          );
        },
      ),
    );
  }
}

class _FitnessStep extends StatelessWidget {
  const _FitnessStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final levels = FitnessLevel.values;
    final stacked =
        AppLayout.isCompact(context) && !AppLayout.isLandscape(context);

    return _StepFrame(
      title: 'Your fitness level',
      subtitle: 'Pick the vibe that fits you best.',
      child: FillChoiceGrid(
        itemCount: levels.length,
        columns: stacked ? 1 : 2,
        minItemHeight: stacked ? 76 : 88,
        itemBuilder: (context, index) {
          final level = levels[index];
          return _ChoiceCard(
            selected: state.draftFitness == level,
            onTap: () => state.setDraftFitness(level),
            child: _CardLabel(
              icon: level.icon,
              title: level.label,
              subtitle: level.funLabel,
              showCheck: true,
              selected: state.draftFitness == level,
            ),
          );
        },
      ),
    );
  }
}

class _PrefsStep extends StatelessWidget {
  const _PrefsStep({required this.state});
  final AppState state;

  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const distanceMaxKm = 250.0;
  static const elevationMaxM = 6000.0;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: 'Riding preferences',
      subtitle: 'How far — and how high — are you willing to go?',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fits = constraints.maxHeight >= 480;
          final distance = _MadnessRangeCard(
            icon: Icons.straighten,
            title: 'Distance',
            unit: 'km',
            values: state.draftDistance,
            min: 10,
            max: distanceMaxKm,
            divisions: 48,
            vibe: _distanceVibe(state.draftDistance.end),
            onChanged: state.setDraftDistance,
          );
          final elevation = _MadnessRangeCard(
            icon: Icons.terrain,
            title: 'Elevation',
            unit: 'm',
            values: state.draftElevation,
            min: 0,
            max: elevationMaxM,
            divisions: 60,
            vibe: _elevationVibe(state.draftElevation.end),
            onChanged: state.setDraftElevation,
          );
          final terrain = _chipCard(
            context,
            title: 'Terrain style',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final terrain in TerrainPref.values)
                  FilterChip(
                    label: Text(terrain.label),
                    selected: state.draftTerrains.contains(terrain),
                    onSelected: (_) => state.toggleDraftTerrain(terrain),
                  ),
              ],
            ),
          );
          final preferredDays = _chipCard(
            context,
            title: 'Preferred days',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in days)
                  FilterChip(
                    label: Text(day),
                    selected: state.draftDays.contains(day),
                    onSelected: (_) => state.toggleDraftDay(day),
                  ),
              ],
            ),
          );

          if (!fits) {
            return ListView(
              children: [
                SizedBox(height: 168, child: distance),
                const SizedBox(height: 12),
                SizedBox(height: 168, child: elevation),
                const SizedBox(height: 12),
                terrain,
                const SizedBox(height: 12),
                preferredDays,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: distance),
              const SizedBox(height: 12),
              Expanded(child: elevation),
              const SizedBox(height: 12),
              terrain,
              const SizedBox(height: 12),
              preferredDays,
            ],
          );
        },
      ),
    );
  }

  static _RideVibe _distanceVibe(double maxKm) {
    if (maxKm >= 230) {
      return const _RideVibe(
        label: 'Certified lunatic',
        detail: '250 km? Friends are drafting a missing-person poster.',
        heat: 1,
        icon: Icons.local_fire_department,
      );
    }
    if (maxKm >= 190) {
      return const _RideVibe(
        label: 'Slightly unhinged',
        detail: 'That is not a ride — that is a personal vendetta.',
        heat: 0.85,
        icon: Icons.psychology_alt,
      );
    }
    if (maxKm >= 150) {
      return const _RideVibe(
        label: 'Century menace',
        detail: 'Legs filed a formal complaint. You ignored it.',
        heat: 0.7,
        icon: Icons.bolt,
      );
    }
    if (maxKm >= 110) {
      return const _RideVibe(
        label: 'Serious engine',
        detail: 'Long enough to earn cake without looking suspicious.',
        heat: 0.5,
        icon: Icons.speed,
      );
    }
    if (maxKm >= 70) {
      return const _RideVibe(
        label: 'Weekend warrior',
        detail: 'Solid spin. Coffee stops still allowed.',
        heat: 0.3,
        icon: Icons.directions_bike,
      );
    }
    return const _RideVibe(
      label: 'Easy spinner',
      detail: 'Keep it chill — nobody is calling you crazy yet.',
      heat: 0.12,
      icon: Icons.coffee,
    );
  }

  static _RideVibe _elevationVibe(double maxM) {
    if (maxM >= 5200) {
      return const _RideVibe(
        label: 'Vertical psychopath',
        detail: '6000 m? Gravity has blocked your number.',
        heat: 1,
        icon: Icons.volcano,
      );
    }
    if (maxM >= 4000) {
      return const _RideVibe(
        label: 'Needs supervision',
        detail: 'Your knees just filed for early retirement.',
        heat: 0.85,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (maxM >= 2800) {
      return const _RideVibe(
        label: 'Alpine anarchist',
        detail: 'Pass hunting season is open. Forever.',
        heat: 0.7,
        icon: Icons.landscape,
      );
    }
    if (maxM >= 1600) {
      return const _RideVibe(
        label: 'Climb crusher',
        detail: 'Hills notice you and quietly panic.',
        heat: 0.5,
        icon: Icons.trending_up,
      );
    }
    if (maxM >= 700) {
      return const _RideVibe(
        label: 'Rolling loyalist',
        detail: 'A few kicks — nothing a gel pack cannot fix.',
        heat: 0.3,
        icon: Icons.terrain,
      );
    }
    return const _RideVibe(
      label: 'Flatland tourist',
      detail: 'Elevation? You prefer your suffering horizontal.',
      heat: 0.12,
      icon: Icons.horizontal_rule,
    );
  }

  Widget _chipCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return _PrefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RideVibe {
  const _RideVibe({
    required this.label,
    required this.detail,
    required this.heat,
    required this.icon,
  });

  final String label;
  final String detail;
  final double heat; // 0..1 how "crazy"
  final IconData icon;
}

class _MadnessRangeCard extends StatelessWidget {
  const _MadnessRangeCard({
    required this.icon,
    required this.title,
    required this.unit,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.vibe,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String unit;
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final _RideVibe vibe;
  final ValueChanged<RangeValues> onChanged;

  Color _heatColor(ColorScheme scheme) {
    return Color.lerp(
          scheme.primary,
          const Color(0xFFC62828),
          vibe.heat,
        ) ??
        scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heat = _heatColor(scheme);
    final start = values.start.round();
    final end = values.end.round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color.lerp(scheme.outline, heat, vibe.heat * 0.85)!,
          width: vibe.heat > 0.75 ? 2 : 1,
        ),
        boxShadow: vibe.heat > 0.7
            ? [
                BoxShadow(
                  color: heat.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: heat),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$start–$end $unit',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: heat,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: heat.withValues(alpha: 0.08 + vibe.heat * 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(vibe.icon, size: 18, color: heat),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vibe.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: heat,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vibe.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: heat,
              thumbColor: heat,
              overlayColor: heat.withValues(alpha: 0.12),
              inactiveTrackColor: heat.withValues(alpha: 0.18),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 9,
              ),
            ),
            child: RangeSlider(
              values: RangeValues(
                values.start.clamp(min, max),
                values.end.clamp(min, max),
              ),
              min: min,
              max: max,
              divisions: divisions,
              labels: RangeLabels('$start', '$end'),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = AppLayout.pageGutter(context);
    final short = AppLayout.sizeOf(context).height < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, short ? 12 : 16, gutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: short
                ? theme.textTheme.titleLarge
                : theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          SizedBox(height: short ? 12 : 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : theme.cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({
    required this.icon,
    required this.title,
    this.subtitle,
    this.showCheck = false,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool showCheck;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 96;
        final stacked =
            constraints.maxHeight >= 120 &&
            (subtitle == null || constraints.maxWidth < 280);
        final iconSize = tight ? 22.0 : (stacked ? 36.0 : 28.0);
        final pad = tight ? 12.0 : 16.0;

        final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
        final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        );

        final texts = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: stacked ? TextAlign.center : TextAlign.start,
              style: titleStyle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: stacked ? TextAlign.center : TextAlign.start,
                style: subtitleStyle,
              ),
            ],
          ],
        );

        final check = showCheck
            ? Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              )
            : null;

        return SizedBox.expand(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: stacked
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: iconSize,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      texts,
                      if (check != null) ...[const SizedBox(height: 8), check],
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: iconSize,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: texts),
                      if (check != null) check,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: child,
      ),
    );
  }
}
