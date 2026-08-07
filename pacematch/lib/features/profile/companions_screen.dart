import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/rider_widgets.dart';

class CompanionsScreen extends StatefulWidget {
  const CompanionsScreen({super.key});

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  CompanionRankMetric _metric = CompanionRankMetric.sharedKm;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final ranked = state.companionsRankedBy(_metric);
    final all = List<CompanionStats>.from(state.companionStats)
      ..sort((a, b) => b.sharedRides.compareTo(a.sharedRides));

    return Scaffold(
      appBar: AppBar(title: const Text('Riding companions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Who you’ve shared the road with — ranked by the stories your legs remember.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final metric in CompanionRankMetric.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(metric.icon, size: 16),
                      label: Text(metric.label),
                      selected: _metric == metric,
                      onSelected: (_) => setState(() => _metric = metric),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _metric.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.stone),
          ),
          const SizedBox(height: 20),
          if (ranked.isEmpty)
            _EmptyCompanions(theme: theme)
          else ...[
            _Podium(
              top: ranked.take(3).toList(),
              metric: _metric,
              valueLabel: state.companionMetricLabel,
              onOpen: (id) => context.push('/profile/rider/$id'),
            ),
            const SizedBox(height: 24),
            Text('Full ranking', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (var i = 0; i < ranked.length; i++) ...[
              _RankRow(
                rank: i + 1,
                stats: ranked[i],
                value: state.companionMetricLabel(ranked[i], _metric),
                onTap: () =>
                    context.push('/profile/rider/${ranked[i].rider.id}'),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (all.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Ride DNA with each buddy', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'A quick fingerprint of how you ride together.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final stats in all.take(6)) ...[
              _CompanionDnaCard(
                stats: stats,
                onTap: () =>
                    context.push('/profile/rider/${stats.rider.id}'),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyCompanions extends StatelessWidget {
  const _EmptyCompanions({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text('No shared kilometers yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Join rides, roll together, then come back for the leaderboards.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.top,
    required this.metric,
    required this.valueLabel,
    required this.onOpen,
  });

  final List<CompanionStats> top;
  final CompanionRankMetric metric;
  final String Function(CompanionStats, CompanionRankMetric) valueLabel;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (top.isEmpty) return const SizedBox.shrink();

    Widget seat(int index, double height) {
      if (index >= top.length) return const Expanded(child: SizedBox());
      final stats = top[index];
      final placeColors = [
        const Color(0xFFC9A227),
        const Color(0xFF8A9399),
        const Color(0xFFB87333),
      ];
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onOpen(stats.rider.id),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: placeColors[index].withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: placeColors[index]),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: placeColors[index],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              RiderAvatar(rider: stats.rider, radius: index == 0 ? 28 : 22),
              const SizedBox(height: 8),
              Text(
                stats.rider.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                valueLabel(stats, metric),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      stats.rider.accentColor.withValues(alpha: 0.85),
                      AppColors.forestDeep,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Visual order: 2nd, 1st, 3rd
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        seat(1, 56),
        const SizedBox(width: 8),
        seat(0, 84),
        const SizedBox(width: 8),
        seat(2, 40),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.stats,
    required this.value,
    required this.onTap,
  });

  final int rank;
  final CompanionStats stats;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: rank <= 3 ? AppColors.forest : null,
                  ),
                ),
              ),
              RiderAvatar(rider: stats.rider, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.rider.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${stats.sharedRides} rides · ${stats.sharedKm.round()} km',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanionDnaCard extends StatelessWidget {
  const _CompanionDnaCard({required this.stats, required this.onTap});

  final CompanionStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <String>[
      if (stats.morningRides > 0) '${stats.morningRides} early starts',
      if (stats.weekendRides > 0) '${stats.weekendRides} weekend rides',
      if (stats.hardRides > 0) '${stats.hardRides} hard days',
      'Peak climb ${stats.biggestClimbM} m',
    ];

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RiderAvatar(rider: stats.rider, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.rider.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${stats.sharedKm.round()} km · ${stats.sharedElevationM} m together',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in chips)
                    Chip(
                      label: Text(chip, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
