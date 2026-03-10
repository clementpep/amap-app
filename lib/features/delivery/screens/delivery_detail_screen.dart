import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../providers/delivery_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryDetailScreen extends ConsumerWidget {
  final String deliveryId;
  const DeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryAsync = ref.watch(deliveryDetailProvider(deliveryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail livraison'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'compare') {
                context.push('/compare/delivery/$deliveryId');
              } else if (value == 'edit') {
                context.push('/deliveries/basket-form',
                    extra: {'deliveryId': deliveryId});
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'compare',
                child: ListTile(
                  leading: Icon(Icons.compare_arrows),
                  title: Text('Comparer les prix'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Modifier'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: deliveryAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: 'Livraison introuvable.'),
        data: (delivery) {
          if (delivery == null) {
            return const AppErrorWidget(message: 'Livraison introuvable.');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photo
                if (delivery.photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      delivery.photoUrl!,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: AppTheme.paleGreen,
                        child: const Icon(Icons.eco, size: 80, color: AppTheme.primaryGreen),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.paleGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.eco, size: 60, color: AppTheme.primaryGreen),
                    ),
                  ),
                const SizedBox(height: 16),
                // Date
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(delivery.deliveredAt),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${delivery.itemCount} produit${delivery.itemCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 16),
                // Totals card
                if (delivery.totalBioPrice != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total bio',
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
                              PriceText(
                                amount: delivery.totalBioPrice!,
                                color: AppTheme.bioGreen,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (delivery.totalConvPrice != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Prix conventionnel',
                                    style: TextStyle(fontFamily: 'Poppins', color: AppTheme.textMedium)),
                                PriceText(
                                  amount: delivery.totalConvPrice!,
                                  color: AppTheme.convBlue,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                            if (delivery.savings > 0) ...[
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Économie',
                                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                                  Text(
                                    '-${delivery.savings.toStringAsFixed(2).replaceAll('.', ',')} € (${delivery.savingsPercent.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: AppTheme.successGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Items list
                const Text(
                  'Produits',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...delivery.items.map((item) => Card(
                  child: ListTile(
                    leading: item.isBio
                        ? const BioBadge()
                        : const Icon(Icons.eco_outlined, color: AppTheme.textLight),
                    title: Text(
                      item.productName,
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${item.unit}',
                      style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.textMedium),
                    ),
                    trailing: item.unitPrice != null
                        ? PriceText(amount: item.unitPrice! * item.quantity)
                        : null,
                  ),
                )),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/compare/delivery/$deliveryId'),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Comparer bio vs conventionnel'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
