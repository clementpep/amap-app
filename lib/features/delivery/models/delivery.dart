import 'package:freezed_annotation/freezed_annotation.dart';
import 'basket_item.dart';

part 'delivery.freezed.dart';
part 'delivery.g.dart';

@freezed
class Delivery with _$Delivery {
  const factory Delivery({
    required String id,
    required String userId,
    required DateTime deliveredAt,
    String? photoUrl,
    String? notes,
    double? totalBioPrice,
    double? totalConvPrice,
    @Default([]) List<BasketItem> items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Delivery;

  factory Delivery.fromJson(Map<String, dynamic> json) =>
      _$DeliveryFromJson(json);
}

extension DeliveryX on Delivery {
  double get savings =>
      (totalConvPrice ?? 0) - (totalBioPrice ?? 0);

  double get savingsPercent {
    if (totalConvPrice == null || totalConvPrice == 0) return 0;
    return (savings / totalConvPrice!) * 100;
  }

  int get itemCount => items.length;

  String get formattedDate {
    final d = deliveredAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
