import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Set up PaceMatch', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text('${_index + 1}/3'),
                ],
              ),
            ),
            LinearProgressIndicator(value: (_index + 1) / 3),
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
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () => _next(state),
                child: Text(_index == 2 ? 'Finish' : 'Continue'),
              ),
            ),
          ],
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Which bikes do you ride?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Pick one or more.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final bike in BikeType.values)
              FilterChip(
                avatar: Icon(bike.icon, size: 16),
                label: Text(bike.label),
                selected: state.draftBikes.contains(bike),
                onSelected: (_) => state.toggleDraftBike(bike),
              ),
          ],
        ),
      ],
    );
  }
}

class _FitnessStep extends StatelessWidget {
  const _FitnessStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Your fitness level',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Pick the vibe that fits you best.'),
        const SizedBox(height: 16),
        for (final level in FitnessLevel.values)
          ListTile(
            title: Text(level.label),
            subtitle: Text(level.funLabel),
            selected: state.draftFitness == level,
            trailing: state.draftFitness == level
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.circle_outlined),
            onTap: () => state.setDraftFitness(level),
          ),
      ],
    );
  }
}

class _PrefsStep extends StatelessWidget {
  const _PrefsStep({required this.state});
  final AppState state;

  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Riding preferences',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Distance: ${state.draftDistance.start.round()}–${state.draftDistance.end.round()} km',
        ),
        RangeSlider(
          values: state.draftDistance,
          min: 10,
          max: 160,
          divisions: 30,
          labels: RangeLabels(
            '${state.draftDistance.start.round()}',
            '${state.draftDistance.end.round()}',
          ),
          onChanged: state.setDraftDistance,
        ),
        const SizedBox(height: 8),
        Text(
          'Elevation: ${state.draftElevation.start.round()}–${state.draftElevation.end.round()} m',
        ),
        RangeSlider(
          values: state.draftElevation,
          min: 0,
          max: 3500,
          divisions: 35,
          labels: RangeLabels(
            '${state.draftElevation.start.round()}',
            '${state.draftElevation.end.round()}',
          ),
          onChanged: state.setDraftElevation,
        ),
        const SizedBox(height: 12),
        const Text('Terrain style (pick one or both)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final terrain in TerrainPref.values)
              FilterChip(
                label: Text(terrain.label),
                selected: state.draftTerrains.contains(terrain),
                onSelected: (_) => state.toggleDraftTerrain(terrain),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Preferred days'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final day in days)
              FilterChip(
                label: Text(day),
                selected: state.draftDays.contains(day),
                onSelected: (_) => state.toggleDraftDay(day),
              ),
          ],
        ),
      ],
    );
  }
}
