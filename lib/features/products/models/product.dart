import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    String? category,
    @Default('kg') String unit,
    String? barcode,
    String? imageUrl,
    String? offId,
    double? bioPriceLatest,
    double? convPriceLatest,
    DateTime? createdAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

extension ProductX on Product {
  double get savings {
    if (bioPriceLatest == null || convPriceLatest == null) return 0;
    return convPriceLatest! - bioPriceLatest!;
  }

  bool get hasPrices => bioPriceLatest != null && convPriceLatest != null;
}
