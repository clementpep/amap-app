import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_comparison_result.freezed.dart';
part 'price_comparison_result.g.dart';

@freezed
class PriceComparisonResult with _$PriceComparisonResult {
  const factory PriceComparisonResult({
    required String productName,
    String? productId,
    required double quantity,
    required String unit,
    required bool isBio,
    double? bioPrice,     // unit price
    double? convPrice,    // unit price
    String? bioSource,
    String? convSource,
    bool? bioPriceStale,  // >30 days old
    bool? convPriceStale,
  }) = _PriceComparisonResult;

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) =>
      _$PriceComparisonResultFromJson(json);
}

extension PriceComparisonResultX on PriceComparisonResult {
  double get bioCost => (bioPrice ?? 0) * quantity;
  double get convCost => (convPrice ?? 0) * quantity;
  double get delta => convCost - bioCost;
  double get deltaPercent =>
      convCost > 0 ? (delta / convCost) * 100 : 0;

  bool get hasBothPrices => bioPrice != null && convPrice != null;
  bool get isCheaperBio => hasBothPrices && bioCost < convCost;
}

class DeliveryComparison {
  final String deliveryId;
  final DateTime deliveredAt;
  final List<PriceComparisonResult> items;
  final double totalBioCost;
  final double totalConvCost;

  const DeliveryComparison({
    required this.deliveryId,
    required this.deliveredAt,
    required this.items,
    required this.totalBioCost,
    required this.totalConvCost,
  });

  double get totalSavings => totalConvCost - totalBioCost;
  double get savingsPercent =>
      totalConvCost > 0 ? (totalSavings / totalConvCost) * 100 : 0;
}
