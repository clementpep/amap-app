import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/product_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

final _productDetailProvider = FutureProvider.autoDispose.family<dynamic, String>((ref, id) =>
    ref.watch(productRepositoryProvider).getProduct(id));

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail produit')),
      body: productAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => const AppErrorWidget(message: 'Produit introuvable.'),
        data: (product) {
          if (product == null) return const AppErrorWidget(message: 'Produit introuvable.');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.imageUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(product.imageUrl!, height: 200, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 80, color: AppTheme.primaryGreen)),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(product.name,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.bold)),
                if (product.category != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(product.category!, style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.textMedium)),
                  ),
                const SizedBox(height: 24),
                // Price comparison card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prix de référence',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PriceCard(
                              label: 'BIO',
                              price: product.bioPriceLatest,
                              color: AppTheme.bioGreen,
                            ),
                            _PriceCard(
                              label: 'CONVENTIONNEL',
                              price: product.convPriceLatest,
                              color: AppTheme.convBlue,
                            ),
                          ],
                        ),
                        if (product.hasPrices && product.savings > 0) ...[
                          const Divider(),
                          Text(
                            'Économie : ${product.savings.toStringAsFixed(2).replaceAll('.', ',')} €/${product.unit}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/compare/price-history/$productId'),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Voir l\'historique des prix'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String label;
  final double? price;
  final Color color;

  const _PriceCard({required this.label, this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          price != null
              ? PriceText(amount: price!, color: color, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              : Text('N/A', style: TextStyle(fontFamily: 'Poppins', color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('/kg', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}
