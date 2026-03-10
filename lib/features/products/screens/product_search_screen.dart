import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.length < 2) return [];
  return ref.watch(productRepositoryProvider).search(query);
});

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(_searchResultsProvider);
    final query = ref.watch(_searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/products/add'),
            tooltip: 'Ajouter manuellement',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(_searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: query.length < 2
                ? const EmptyStateWidget(
                    icon: Icons.search,
                    title: 'Rechercher des produits',
                    subtitle: 'Tapez au moins 2 caractères pour rechercher\ndans la base locale et Open Food Facts.',
                  )
                : resultsAsync.when(
                    loading: () => ListView.builder(
                      itemCount: 5,
                      itemBuilder: (_, __) => const ShimmerCard(height: 80),
                    ),
                    error: (e, _) => AppErrorWidget(
                      message: 'Erreur lors de la recherche.',
                      onRetry: () => ref.invalidate(_searchResultsProvider),
                    ),
                    data: (products) {
                      if (products.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.eco_outlined,
                          title: 'Aucun résultat',
                          subtitle: 'Essayez un autre terme ou\najoutez le produit manuellement.',
                          action: ElevatedButton.icon(
                            onPressed: () => context.push('/products/add'),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter manuellement'),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) =>
                            _ProductTile(product: products[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: product.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: AppTheme.primaryGreen),
              ),
            )
          : const Icon(Icons.eco, color: AppTheme.primaryGreen),
      title: Text(
        product.name,
        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
      ),
      subtitle: product.category != null
          ? Text(product.category!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textMedium))
          : null,
      trailing: product.hasPrices
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PriceText(amount: product.bioPriceLatest!, color: AppTheme.bioGreen,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                PriceText(amount: product.convPriceLatest!, color: AppTheme.convBlue,
                    style: const TextStyle(fontSize: 11)),
              ],
            )
          : const Icon(Icons.chevron_right, color: AppTheme.textLight),
      onTap: () => context.push('/products/${product.id}'),
    );
  }
}
