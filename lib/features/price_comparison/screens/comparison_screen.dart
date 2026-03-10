import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/price_repository.dart';
import '../models/price_comparison_result.dart';
import '../../delivery/models/delivery.dart';
import '../../delivery/providers/delivery_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

// Provider for the comparison of a given delivery
final _comparisonProvider =
    FutureProvider.autoDispose.family<DeliveryComparison, String>((ref, id) =>
        ref.watch(priceRepositoryProvider).getComparisonForDelivery(id));

class ComparisonScreen extends ConsumerWidget {
  final String? deliveryId;
  const ComparisonScreen({super.key, this.deliveryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (deliveryId == null) {
      // Show list of deliveries to select
      return _DeliveryPickerScreen();
    }
    return _ComparisonDetailScreen(deliveryId: deliveryId!);
  }
}

class _DeliveryPickerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(deliveryListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer les prix')),
      body: deliveriesAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => const AppErrorWidget(message: 'Impossible de charger les livraisons.'),
        data: (deliveries) {
          if (deliveries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.compare_arrows,
              title: 'Aucune livraison',
              subtitle: 'Ajoutez d\'abord une livraison pour pouvoir comparer les prix.',
            );
          }
          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final d = deliveries[index];
              return ListTile(
                leading: const Icon(Icons.shopping_basket, color: AppTheme.primaryGreen),
                title: Text(
                  d.formattedDate,
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '${d.itemCount} produits',
                  style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.textMedium),
                ),
                trailing: const Icon(Icons.compare_arrows, color: AppTheme.textLight),
                onTap: () => context.push('/compare/delivery/${d.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _ComparisonDetailScreen extends ConsumerWidget {
  final String deliveryId;
  const _ComparisonDetailScreen({required this.deliveryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(_comparisonProvider(deliveryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison prix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les prix',
            onPressed: () async {
              await ref.read(priceRepositoryProvider).refreshPricesForDelivery(deliveryId);
              ref.invalidate(_comparisonProvider(deliveryId));
            },
          ),
        ],
      ),
      body: comparisonAsync.when(
        loading: () => const LoadingWidget(message: 'Calcul des prix...'),
        error: (e, _) => AppErrorWidget(
          message: 'Impossible de calculer la comparaison.',
          onRetry: () => ref.invalidate(_comparisonProvider(deliveryId)),
        ),
        data: (comparison) => Column(
          children: [
            // Summary header
            Container(
              color: AppTheme.primaryGreen,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryTile(
                    label: 'Panier bio',
                    amount: comparison.totalBioCost,
                    color: Colors.white,
                  ),
                  Container(width: 1, height: 40, color: Colors.white30),
                  _SummaryTile(
                    label: 'Prix conv.',
                    amount: comparison.totalConvCost,
                    color: Colors.white70,
                  ),
                  Container(width: 1, height: 40, color: Colors.white30),
                  _SummaryTile(
                    label: 'Économie',
                    amount: comparison.totalSavings,
                    color: Colors.greenAccent,
                    suffix: '(${comparison.savingsPercent.toStringAsFixed(0)}%)',
                  ),
                ],
              ),
            ),
            // Items table
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Table header
                  const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12))),
                      SizedBox(width: 8),
                      Expanded(flex: 2, child: Text('Bio', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.bioGreen))),
                      Expanded(flex: 2, child: Text('Conv.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.convBlue))),
                      Expanded(flex: 2, child: Text('Diff.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12))),
                    ],
                  ),
                  const Divider(),
                  ...comparison.items.map((item) => _ComparisonRow(
                    item: item,
                    onTap: item.productId != null
                        ? () => context.push('/compare/price-history/${item.productId}')
                        : null,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String? suffix;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = amount.toStringAsFixed(2).replaceAll('.', ',');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text('$formatted €',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        if (suffix != null)
          Text(suffix!, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color.withOpacity(0.8))),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final PriceComparisonResult item;
  final VoidCallback? onTap;

  const _ComparisonRow({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${item.unit}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: item.bioPrice != null
                  ? Column(
                      children: [
                        Text(
                          '${item.bioCost.toStringAsFixed(2).replaceAll('.', ',')} €',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.bioGreen, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (item.bioPriceStale == true)
                          const Icon(Icons.warning_amber, size: 12, color: AppTheme.accentAmber),
                      ],
                    )
                  : const Text('—', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textLight)),
            ),
            Expanded(
              flex: 2,
              child: item.convPrice != null
                  ? Column(
                      children: [
                        Text(
                          '${item.convCost.toStringAsFixed(2).replaceAll('.', ',')} €',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.convBlue, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (item.convPriceStale == true)
                          const Icon(Icons.warning_amber, size: 12, color: AppTheme.accentAmber),
                      ],
                    )
                  : const Text('—', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textLight)),
            ),
            Expanded(
              flex: 2,
              child: item.hasBothPrices
                  ? Column(
                      children: [
                        Text(
                          '${item.delta >= 0 ? '-' : '+'}${item.delta.abs().toStringAsFixed(2).replaceAll('.', ',')} €',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: item.delta >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${item.deltaPercent.toStringAsFixed(0)}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: item.delta >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : const Text('—', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textLight)),
            ),
          ],
        ),
      ),
    );
  }
}
