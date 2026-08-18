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

  void _next(AppState state) {
    if (_index < 2) {
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      state.completeOnboarding();
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
                  onPressed: () => _next(state),
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

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: 'Riding preferences',
      subtitle: 'Distance, climb and when you like to ride.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fits = constraints.maxHeight >= 420;
          final distance = _sliderCard(context, isDistance: true);
          final elevation = _sliderCard(context, isDistance: false);
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
                SizedBox(height: 132, child: distance),
                const SizedBox(height: 12),
                SizedBox(height: 132, child: elevation),
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

  Widget _sliderCard(BuildContext context, {required bool isDistance}) {
    final theme = Theme.of(context);
    return _PrefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDistance
                ? 'Distance: ${state.draftDistance.start.round()}–${state.draftDistance.end.round()} km'
                : 'Elevation: ${state.draftElevation.start.round()}–${state.draftElevation.end.round()} m',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          RangeSlider(
            values: isDistance ? state.draftDistance : state.draftElevation,
            min: isDistance ? 10 : 0,
            max: isDistance ? 160 : 3500,
            divisions: isDistance ? 30 : 35,
            labels: RangeLabels(
              isDistance
                  ? '${state.draftDistance.start.round()}'
                  : '${state.draftElevation.start.round()}',
              isDistance
                  ? '${state.draftDistance.end.round()}'
                  : '${state.draftElevation.end.round()}',
            ),
            onChanged: isDistance
                ? state.setDraftDistance
                : state.setDraftElevation,
          ),
        ],
      ),
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
