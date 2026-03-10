import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/config/supabase_config.dart';

part 'open_food_facts_service.g.dart';

@riverpod
OpenFoodFactsService openFoodFactsService(Ref ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'AMAP-App/1.0 (Flutter)'},
  ));
  return OpenFoodFactsService(dio);
}

class OffProduct {
  final String? offId;
  final String name;
  final String? category;
  final String? barcode;
  final String? imageUrl;

  const OffProduct({
    this.offId,
    required this.name,
    this.category,
    this.barcode,
    this.imageUrl,
  });
}

class OpenFoodPrice {
  final String productCode;
  final double price;
  final String currency;
  final String? location;
  final DateTime? date;

  const OpenFoodPrice({
    required this.productCode,
    required this.price,
    required this.currency,
    this.location,
    this.date,
  });
}

class OpenFoodFactsService {
  final Dio _dio;
  OpenFoodFactsService(this._dio);

  /// Search products by name (French language preference)
  Future<List<OffProduct>> searchByName(String query, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '${SupabaseConfig.openFoodFactsBaseUrl}/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'search_simple': 1,
          'action': 'process',
          'json': 1,
          'page': page,
          'page_size': 20,
          'lc': 'fr',
          'cc': 'fr',
          'fields': 'code,product_name,categories_tags,image_url',
        },
      );

      final products = (response.data['products'] as List?) ?? [];
      return products
          .where((p) => p['product_name'] != null &&
              (p['product_name'] as String).isNotEmpty)
          .map((p) => OffProduct(
                offId: p['code'] as String?,
                name: p['product_name'] as String,
                category: _extractCategory(p['categories_tags']),
                barcode: p['code'] as String?,
                imageUrl: p['image_url'] as String?,
              ))
          .toList();
    } on DioException catch (e) {
      // Return empty on network errors; UI will show empty state
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return [];
      }
      rethrow;
    }
  }

  /// Lookup a product by EAN barcode
  Future<OffProduct?> lookupBarcode(String barcode) async {
    try {
      final response = await _dio.get(
        '${SupabaseConfig.openFoodFactsBaseUrl}/api/v0/product/$barcode.json',
        queryParameters: {'fields': 'code,product_name,categories_tags,image_url'},
      );

      if (response.data['status'] != 1) return null;
      final p = response.data['product'] as Map<String, dynamic>?;
      if (p == null || p['product_name'] == null) return null;

      return OffProduct(
        offId: p['code'] as String?,
        name: p['product_name'] as String,
        category: _extractCategory(p['categories_tags']),
        barcode: barcode,
        imageUrl: p['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch recent prices from Open Prices API for a product code
  Future<List<OpenFoodPrice>> fetchPrices(String productCode) async {
    try {
      final response = await _dio.get(
        '${SupabaseConfig.openPricesBaseUrl}/api/v1/prices',
        queryParameters: {
          'product_code': productCode,
          'currency': 'EUR',
          'order_by': '-date',
          'size': 10,
        },
      );

      final items = (response.data['items'] as List?) ?? [];
      return items
          .where((item) => item['price'] != null)
          .map((item) => OpenFoodPrice(
                productCode: productCode,
                price: (item['price'] as num).toDouble(),
                currency: item['currency'] as String? ?? 'EUR',
                location: item['location_osm_id']?.toString(),
                date: item['date'] != null
                    ? DateTime.tryParse(item['date'] as String)
                    : null,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String? _extractCategory(dynamic categoryTags) {
    if (categoryTags == null) return null;
    final tags = categoryTags as List;
    // Find a French category tag (fr:...)
    for (final tag in tags) {
      final s = tag.toString();
      if (s.startsWith('fr:')) {
        return s
            .replaceFirst('fr:', '')
            .replaceAll('-', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
            .join(' ');
      }
    }
    if (tags.isNotEmpty) {
      return tags.first.toString().split(':').last.replaceAll('-', ' ');
    }
    return null;
  }
}
