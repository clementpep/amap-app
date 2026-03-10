import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/delivery_provider.dart';
import '../models/delivery.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryListScreen extends ConsumerWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(deliveryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Livraisons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outlined),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/deliveries/new'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Nouvelle livraison'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(deliveryListProvider),
        child: deliveriesAsync.when(
          loading: () => ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const ShimmerCard(height: 100),
          ),
          error: (e, _) => AppErrorWidget(
            message: 'Impossible de charger les livraisons.',
            onRetry: () => ref.invalidate(deliveryListProvider),
          ),
          data: (deliveries) {
            if (deliveries.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.shopping_basket_outlined,
                title: 'Aucune livraison',
                subtitle: 'Commencez par prendre en photo\nvotre premier panier AMAP.',
                action: ElevatedButton.icon(
                  onPressed: () => context.push('/deliveries/new'),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Ajouter une livraison'),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: deliveries.length,
              itemBuilder: (context, index) =>
                  _DeliveryCard(delivery: deliveries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(delivery.deliveredAt);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/deliveries/${delivery.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Photo thumbnail or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: delivery.photoUrl != null
                    ? Image.network(
                        delivery.photoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${delivery.itemCount} produit${delivery.itemCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppTheme.textMedium,
                        fontSize: 13,
                      ),
                    ),
                    if (delivery.totalBioPrice != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          PriceText(
                            amount: delivery.totalBioPrice!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            color: AppTheme.primaryGreen,
                          ),
                          if (delivery.totalConvPrice != null &&
                              delivery.savings > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.paleGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '-${delivery.savingsPercent.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      color: AppTheme.paleGreen,
      child: const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 30),
    );
  }
}
