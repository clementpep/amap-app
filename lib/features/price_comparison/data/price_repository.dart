import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/price_comparison_result.dart';
import '../../delivery/data/delivery_repository.dart';
import '../../products/data/open_food_facts_service.dart';

part 'price_repository.g.dart';

@riverpod
PriceRepository priceRepository(Ref ref) {
  return PriceRepository(
    Supabase.instance.client,
    ref.watch(openFoodFactsServiceProvider),
  );
}

class PriceHistory {
  final String productId;
  final String priceType;
  final double price;
  final String unit;
  final String source;
  final DateTime recordedAt;

  const PriceHistory({
    required this.productId,
    required this.priceType,
    required this.price,
    required this.unit,
    required this.source,
    required this.recordedAt,
  });
}

class PriceRepository {
  final SupabaseClient _client;
  final OpenFoodFactsService _off;

  PriceRepository(this._client, this._off);

  /// Build comparison for a specific delivery
  Future<DeliveryComparison> getComparisonForDelivery(String deliveryId) async {
    // Fetch delivery with items
    final deliveryRow = await _client
        .from('deliveries')
        .select('*, basket_items(*, products(id, name, barcode, off_id))')
        .eq('id', deliveryId)
        .single();

    final basketItems = (deliveryRow['basket_items'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final results = <PriceComparisonResult>[];

    for (final item in basketItems) {
      final productId = item['product_id'] as String?;
      final productName = item['product_name'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final unit = item['unit'] as String? ?? 'kg';

      double? bioPrice;
      double? convPrice;
      String? bioSource;
      String? convSource;
      bool? bioPriceStale;
      bool? convPriceStale;

      if (productId != null) {
        // Fetch latest prices for this product
        final prices = await _client
            .from('price_references')
            .select()
            .eq('product_id', productId)
            .order('recorded_at', ascending: false)
            .limit(10);

        final now = DateTime.now();
        for (final p in (prices as List).cast<Map<String, dynamic>>()) {
          final recordedAt = DateTime.parse(p['recorded_at'] as String);
          final isStale = now.difference(recordedAt).inDays > 30;
          final priceType = p['price_type'] as String;
          final price = (p['price'] as num).toDouble();
          final source = p['source'] as String;

          if (priceType == 'bio' && bioPrice == null) {
            bioPrice = price;
            bioSource = source;
            bioPriceStale = isStale;
          }
          if (priceType == 'conv' && convPrice == null) {
            convPrice = price;
            convSource = source;
            convPriceStale = isStale;
          }
        }
      }

      results.add(PriceComparisonResult(
        productName: productName,
        productId: productId,
        quantity: qty,
        unit: unit,
        isBio: item['is_bio'] as bool? ?? true,
        bioPrice: bioPrice,
        convPrice: convPrice,
        bioSource: bioSource,
        convSource: convSource,
        bioPriceStale: bioPriceStale,
        convPriceStale: convPriceStale,
      ));
    }

    final totalBio = results.fold(0.0, (sum, r) => sum + r.bioCost);
    final totalConv = results.fold(0.0, (sum, r) => sum + r.convCost);

    // Update delivery totals in DB
    await _client.from('deliveries').update({
      'total_bio_price': totalBio,
      'total_conv_price': totalConv,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', deliveryId);

    return DeliveryComparison(
      deliveryId: deliveryId,
      deliveredAt: DateTime.parse(deliveryRow['delivered_at'] as String),
      items: results,
      totalBioCost: totalBio,
      totalConvCost: totalConv,
    );
  }

  /// Refresh Open Prices for items in a delivery
  Future<void> refreshPricesForDelivery(String deliveryId) async {
    final items = await _client
        .from('basket_items')
        .select('product_id, products(barcode, off_id)')
        .eq('delivery_id', deliveryId)
        .not('product_id', 'is', null);

    for (final item in (items as List)) {
      final product = item['products'] as Map<String, dynamic>?;
      if (product == null) continue;

      final productId = item['product_id'] as String;
      final code = product['barcode'] as String? ?? product['off_id'] as String?;
      if (code == null) continue;

      final prices = await _off.fetchPrices(code);
      for (final p in prices) {
        await _client.from('price_references').insert({
          'product_id': productId,
          'price_type': 'conv',
          'price': p.price,
          'unit': 'kg',
          'source': 'open_prices',
          if (p.location != null) 'location': p.location,
          'recorded_at': p.date?.toIso8601String() ?? DateTime.now().toIso8601String(),
        });
      }
    }
  }

  /// Fetch price history for a product (for chart)
  Future<List<PriceHistory>> getPriceHistory(String productId, {int months = 12}) async {
    final since = DateTime.now().subtract(Duration(days: months * 30));
    final rows = await _client
        .from('price_references')
        .select()
        .eq('product_id', productId)
        .gte('recorded_at', since.toIso8601String())
        .order('recorded_at', ascending: true);

    return (rows as List).map((dynamic r) {
      final row = r as Map<String, dynamic>;
      return PriceHistory(
        productId: productId,
        priceType: row['price_type'] as String,
        price: (row['price'] as num).toDouble(),
        unit: row['unit'] as String,
        source: row['source'] as String,
        recordedAt: DateTime.parse(row['recorded_at'] as String),
      );
    }).toList();
  }
}
