import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/analytics_repository.dart';
import '../models/stats_summary.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

final _selectedPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.sixMonths);

final _summaryProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  final period = ref.watch(_selectedPeriodProvider);
  return ref.watch(analyticsRepositoryProvider).getSummary(period);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_summaryProvider);
    final selectedPeriod = ref.watch(_selectedPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          PopupMenuButton<StatsPeriod>(
            initialValue: selectedPeriod,
            onSelected: (p) => ref.read(_selectedPeriodProvider.notifier).state = p,
            itemBuilder: (_) => StatsPeriod.values
                .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(selectedPeriod.label, style: const TextStyle(color: Colors.white)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_summaryProvider),
        child: summaryAsync.when(
          loading: () => ListView.builder(
            itemCount: 4,
            itemBuilder: (_, __) => const ShimmerCard(height: 200),
          ),
          error: (e, _) => AppErrorWidget(
            message: 'Impossible de charger les statistiques.',
            onRetry: () => ref.invalidate(_summaryProvider),
          ),
          data: (summary) {
            if (summary.totalDeliveries == 0) {
              return const EmptyStateWidget(
                icon: Icons.bar_chart_outlined,
                title: 'Pas encore de données',
                subtitle: 'Ajoutez des livraisons pour voir\nvos statistiques ici.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCards(summary: summary),
                const SizedBox(height: 16),
                _WeeklyBarChart(data: summary.weeklyData),
                const SizedBox(height: 16),
                _MonthlyLineChart(data: summary.monthlyData),
                const SizedBox(height: 16),
                if (summary.categoryData.isNotEmpty)
                  _CategoryPieChart(data: summary.categoryData),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Summary cards row ────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final StatsSummary summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.shopping_basket,
          label: 'Livraisons',
          value: '${summary.totalDeliveries}',
          color: AppTheme.primaryGreen,
        ),
        _StatCard(
          icon: Icons.eco,
          label: 'Panier moy. bio',
          value: '${summary.avgBasketBio.toStringAsFixed(2).replaceAll('.', ',')} €',
          color: AppTheme.bioGreen,
        ),
        _StatCard(
          icon: Icons.savings_outlined,
          label: 'Économies totales',
          value: '${summary.totalSavings.toStringAsFixed(2).replaceAll('.', ',')} €',
          color: AppTheme.accentAmber,
        ),
        _StatCard(
          icon: Icons.percent,
          label: 'Taux d\'économie',
          value: summary.totalSpentConv > 0
              ? '${((summary.totalSavings / summary.totalSpentConv) * 100).toStringAsFixed(0)}%'
              : '-',
          color: AppTheme.convBlue,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weekly bar chart ─────────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<WeeklyData> data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final displayData = data.length > 12 ? data.sublist(data.length - 12) : data;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dépenses hebdomadaires',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                _ChartLegend(color: AppTheme.bioGreen, label: 'Bio'),
                SizedBox(width: 12),
                _ChartLegend(color: AppTheme.convBlue, label: 'Conventionnel'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: displayData.asMap().entries.map((e) {
                    final i = e.key;
                    final d = e.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: d.bioSpent,
                          color: AppTheme.bioGreen,
                          width: 6,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: d.convSpent,
                          color: AppTheme.convBlue.withOpacity(0.5),
                          width: 6,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}€',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index >= displayData.length) return const SizedBox();
                          final d = displayData[index].weekStart;
                          return Text(
                            '${d.day}/${d.month}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 9),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Monthly line chart ───────────────────────────────────────
class _MonthlyLineChart extends StatelessWidget {
  final List<MonthlyData> data;
  const _MonthlyLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final bioSpots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.bioSpent))
        .toList();
    final convSpots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.convSpent))
        .toList();

    final allValues = data.expand((d) => [d.bioSpent, d.convSpent]);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution mensuelle',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                _ChartLegend(color: AppTheme.bioGreen, label: 'Bio'),
                SizedBox(width: 12),
                _ChartLegend(color: AppTheme.convBlue, label: 'Conv.'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  maxY: maxY,
                  minY: 0,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}€',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index >= data.length) return const SizedBox();
                          final month = data[index].month;
                          return Text(
                            DateFormat('MMM', 'fr_FR').format(month),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 9),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: bioSpots,
                      isCurved: true,
                      color: AppTheme.bioGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.bioGreen.withOpacity(0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: convSpots,
                      isCurved: true,
                      color: AppTheme.convBlue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.convBlue.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category pie chart ───────────────────────────────────────
class _CategoryPieChart extends StatefulWidget {
  final List<CategoryData> data;
  const _CategoryPieChart({required this.data});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touchedIndex = -1;

  static const _colors = [
    AppTheme.primaryGreen,
    AppTheme.accentAmber,
    AppTheme.convBlue,
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par catégorie',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: PieChart(
                    PieChartData(
                      sections: widget.data.asMap().entries.map((e) {
                        final i = e.key;
                        final d = e.value;
                        final isTouched = i == _touchedIndex;
                        return PieChartSectionData(
                          value: d.percentage,
                          color: _colors[i % _colors.length],
                          radius: isTouched ? 60 : 50,
                          title: '${d.percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.data.asMap().entries.map((e) {
                      final i = e.key;
                      final d = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[i % _colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d.category,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textMedium)),
      ],
    );
  }
}
