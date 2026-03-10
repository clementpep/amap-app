import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'open_food_facts_service.dart';

part 'product_repository.g.dart';

@riverpod
ProductRepository productRepository(Ref ref) {
  return ProductRepository(
    Supabase.instance.client,
    ref.watch(openFoodFactsServiceProvider),
  );
}

class ProductRepository {
  final SupabaseClient _client;
  final OpenFoodFactsService _off;

  ProductRepository(this._client, this._off);

  /// Search local Supabase products by name (full-text)
  Future<List<Product>> searchLocal(String query) async {
    final rows = await _client
        .from('products')
        .select('*, latest_prices(*)')
        .textSearch('name', query, config: 'french')
        .limit(20);

    return (rows as List)
        .map((row) => _parseProduct(row as Map<String, dynamic>))
        .toList();
  }

  /// Search Open Food Facts and cache results in Supabase
  Future<List<Product>> searchRemote(String query) async {
    final offProducts = await _off.searchByName(query);
    final products = <Product>[];

    for (final offProduct in offProducts) {
      final product = await upsertProduct(
        name: offProduct.name,
        category: offProduct.category,
        barcode: offProduct.barcode,
        imageUrl: offProduct.imageUrl,
        offId: offProduct.offId,
      );
      products.add(product);
    }
    return products;
  }

  /// Search products: local first, then remote if not enough results
  Future<List<Product>> search(String query) async {
    final local = await searchLocal(query);
    if (local.length >= 5) return local;

    final remote = await searchRemote(query);
    // Merge, deduplicate by id
    final seen = <String>{};
    final merged = <Product>[];
    for (final p in [...local, ...remote]) {
      if (seen.add(p.id)) merged.add(p);
    }
    return merged.take(20).toList();
  }

  /// Upsert a product from OFF (by barcode or offId)
  Future<Product> upsertProduct({
    required String name,
    String? category,
    String? unit,
    String? barcode,
    String? imageUrl,
    String? offId,
  }) async {
    final data = {
      'name': name,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (barcode != null) 'barcode': barcode,
      if (imageUrl != null) 'image_url': imageUrl,
      if (offId != null) 'off_id': offId,
    };

    // Try upsert by barcode or offId
    Map<String, dynamic> row;
    if (barcode != null || offId != null) {
      final upsertData = await _client
          .from('products')
          .upsert(data, onConflict: barcode != null ? 'barcode' : 'off_id')
          .select()
          .single();
      row = upsertData;
    } else {
      final insertData = await _client
          .from('products')
          .insert(data)
          .select()
          .single();
      row = insertData;
    }

    return _parseProduct(row);
  }

  /// Get a product by ID with latest prices
  Future<Product?> getProduct(String productId) async {
    final row = await _client
        .from('products')
        .select('*, latest_prices(*)')
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return _parseProduct(row);
  }

  /// Add a price reference for a product
  Future<void> addPrice({
    required String productId,
    required String priceType, // 'bio' or 'conv'
    required double price,
    required String unit,
    String source = 'manual',
    String? location,
  }) async {
    await _client.from('price_references').insert({
      'product_id': productId,
      'price_type': priceType,
      'price': price,
      'unit': unit,
      'source': source,
      if (location != null) 'location': location,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  /// Fetch and store Open Prices for a product
  Future<void> fetchAndStorePrices(String productId, String productCode) async {
    final prices = await _off.fetchPrices(productCode);
    for (final p in prices) {
      await addPrice(
        productId: productId,
        priceType: 'conv', // Open Prices are market prices (conventional reference)
        price: p.price,
        unit: 'kg',
        source: 'open_prices',
        location: p.location,
      );
    }
  }

  Product _parseProduct(Map<String, dynamic> row) {
    // Extract latest prices from join
    double? bioPrice;
    double? convPrice;
    final latestPrices = row['latest_prices'];
    if (latestPrices is List) {
      for (final lp in latestPrices) {
        if (lp['price_type'] == 'bio') bioPrice = (lp['price'] as num?)?.toDouble();
        if (lp['price_type'] == 'conv') convPrice = (lp['price'] as num?)?.toDouble();
      }
    }

    return Product(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String?,
      unit: row['unit'] as String? ?? 'kg',
      barcode: row['barcode'] as String?,
      imageUrl: row['image_url'] as String?,
      offId: row['off_id'] as String?,
      bioPriceLatest: bioPrice,
      convPriceLatest: convPrice,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
