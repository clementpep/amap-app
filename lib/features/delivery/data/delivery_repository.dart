import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery.dart';
import '../models/basket_item.dart';

part 'delivery_repository.g.dart';

@riverpod
DeliveryRepository deliveryRepository(Ref ref) =>
    DeliveryRepository(Supabase.instance.client);

class DeliveryRepository {
  final SupabaseClient _client;
  DeliveryRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Create a new delivery and its items. Returns the created delivery.
  Future<Delivery> createDelivery({
    required DateTime deliveredAt,
    required List<BasketItem> items,
    String? photoUrl,
    String? notes,
    double? totalBioPrice,
    double? totalConvPrice,
  }) async {
    // 1. Insert delivery
    final deliveryData = await _client.from('deliveries').insert({
      'user_id': _userId,
      'delivered_at': deliveredAt.toIso8601String().split('T')[0],
      'photo_url': photoUrl,
      'notes': notes,
      'total_bio_price': totalBioPrice,
      'total_conv_price': totalConvPrice,
    }).select().single();

    final deliveryId = deliveryData['id'] as String;

    // 2. Insert basket items
    if (items.isNotEmpty) {
      await _client.from('basket_items').insert(
        items.map((item) => {
          'delivery_id': deliveryId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit': item.unit,
          'is_bio': item.isBio,
          'unit_price': item.unitPrice,
        }).toList(),
      );
    }

    return _parseDelivery(deliveryData, items);
  }

  /// Fetch paginated deliveries for current user, with items
  Future<List<Delivery>> getDeliveries({int limit = 20, int offset = 0}) async {
    final rows = await _client
        .from('deliveries')
        .select('*, basket_items(*)')
        .eq('user_id', _userId)
        .order('delivered_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List).map((dynamic row) {
      final r = row as Map<String, dynamic>;
      final itemRows = (r['basket_items'] as List?) ?? [];
      final items = itemRows
          .map((i) => _parseBasketItem(i as Map<String, dynamic>))
          .toList();
      return _parseDelivery(r, items);
    }).toList();
  }

  /// Fetch a single delivery with items
  Future<Delivery?> getDelivery(String deliveryId) async {
    final row = await _client
        .from('deliveries')
        .select('*, basket_items(*)')
        .eq('id', deliveryId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (row == null) return null;
    final itemRows = (row['basket_items'] as List?) ?? [];
    final items = itemRows
        .map((i) => _parseBasketItem(i as Map<String, dynamic>))
        .toList();
    return _parseDelivery(row, items);
  }

  /// Update delivery metadata
  Future<void> updateDelivery(String deliveryId, {
    DateTime? deliveredAt,
    String? photoUrl,
    String? notes,
    double? totalBioPrice,
    double? totalConvPrice,
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (deliveredAt != null) {
      updates['delivered_at'] = deliveredAt.toIso8601String().split('T')[0];
    }
    if (photoUrl != null) updates['photo_url'] = photoUrl;
    if (notes != null) updates['notes'] = notes;
    if (totalBioPrice != null) updates['total_bio_price'] = totalBioPrice;
    if (totalConvPrice != null) updates['total_conv_price'] = totalConvPrice;

    await _client
        .from('deliveries')
        .update(updates)
        .eq('id', deliveryId)
        .eq('user_id', _userId);
  }

  /// Replace all items for a delivery
  Future<void> updateBasketItems(
    String deliveryId,
    List<BasketItem> items,
  ) async {
    // Delete old items
    await _client.from('basket_items').delete().eq('delivery_id', deliveryId);

    // Insert new items
    if (items.isNotEmpty) {
      await _client.from('basket_items').insert(
        items.map((item) => {
          'delivery_id': deliveryId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit': item.unit,
          'is_bio': item.isBio,
          'unit_price': item.unitPrice,
        }).toList(),
      );
    }
  }

  /// Delete a delivery (cascade deletes items via FK)
  Future<void> deleteDelivery(String deliveryId) async {
    await _client
        .from('deliveries')
        .delete()
        .eq('id', deliveryId)
        .eq('user_id', _userId);
  }

  // ─── Parsers ─────────────────────────────────────────────
  Delivery _parseDelivery(Map<String, dynamic> row, List<BasketItem> items) {
    return Delivery(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      deliveredAt: DateTime.parse(row['delivered_at'] as String),
      photoUrl: row['photo_url'] as String?,
      notes: row['notes'] as String?,
      totalBioPrice: (row['total_bio_price'] as num?)?.toDouble(),
      totalConvPrice: (row['total_conv_price'] as num?)?.toDouble(),
      items: items,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  BasketItem _parseBasketItem(Map<String, dynamic> row) {
    return BasketItem(
      id: row['id'] as String,
      deliveryId: row['delivery_id'] as String,
      productId: row['product_id'] as String?,
      productName: row['product_name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String? ?? 'kg',
      isBio: row['is_bio'] as bool? ?? true,
      unitPrice: (row['unit_price'] as num?)?.toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
