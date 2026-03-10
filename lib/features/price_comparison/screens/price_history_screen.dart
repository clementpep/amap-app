import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/price_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

final _priceHistoryProvider =
    FutureProvider.autoDispose.family<List<PriceHistory>, String>((ref, productId) =>
        ref.watch(priceRepositoryProvider).getPriceHistory(productId));

class PriceHistoryScreen extends ConsumerWidget {
  final String productId;
  const PriceHistoryScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_priceHistoryProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des prix')),
      body: historyAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => const AppErrorWidget(message: 'Impossible de charger l\'historique.'),
        data: (history) {
          if (history.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.show_chart,
              title: 'Pas d\'historique',
              subtitle: 'Aucun prix enregistré pour ce produit.',
            );
          }

          final bioHistory = history.where((h) => h.priceType == 'bio').toList();
          final convHistory = history.where((h) => h.priceType == 'conv').toList();

          // Build chart spots
          final bioSpots = bioHistory
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.price))
              .toList();
          final convSpots = convHistory
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.price))
              .toList();

          final allPrices = history.map((h) => h.price).toList();
          final minY = (allPrices.reduce((a, b) => a < b ? a : b) * 0.8).floorToDouble();
          final maxY = (allPrices.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Évolution des prix (12 mois)',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, _) => Text(
                              '${value.toStringAsFixed(1)}€',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        if (bioSpots.isNotEmpty)
                          LineChartBarData(
                            spots: bioSpots,
                            isCurved: true,
                            color: AppTheme.bioGreen,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                        if (convSpots.isNotEmpty)
                          LineChartBarData(
                            spots: convSpots,
                            isCurved: true,
                            color: AppTheme.convBlue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  children: [
                    _Legend(color: AppTheme.bioGreen, label: 'Bio'),
                    const SizedBox(width: 16),
                    _Legend(color: AppTheme.convBlue, label: 'Conventionnel'),
                  ],
                ),
                const SizedBox(height: 24),
                // Recent prices table
                const Text(
                  'Derniers prix enregistrés',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...history.reversed.take(10).map((h) => ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.circle,
                    size: 10,
                    color: h.priceType == 'bio' ? AppTheme.bioGreen : AppTheme.convBlue,
                  ),
                  title: Text(
                    '${h.price.toStringAsFixed(2).replaceAll('.', ',')} €/${h.unit}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  ),
                  subtitle: Text(
                    '${h.priceType.toUpperCase()} · ${h.source}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textMedium),
                  ),
                  trailing: Text(
                    '${h.recordedAt.day.toString().padLeft(2,'0')}/${h.recordedAt.month.toString().padLeft(2,'0')}/${h.recordedAt.year}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textMedium),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 24, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
      ],
    );
  }
}
