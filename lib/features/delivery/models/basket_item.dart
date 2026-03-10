import 'package:freezed_annotation/freezed_annotation.dart';

part 'basket_item.freezed.dart';
part 'basket_item.g.dart';

@freezed
class BasketItem with _$BasketItem {
  const factory BasketItem({
    required String id,
    required String deliveryId,
    String? productId,
    required String productName,
    required double quantity,
    @Default('kg') String unit,
    @Default(true) bool isBio,
    double? unitPrice,
    DateTime? createdAt,
  }) = _BasketItem;

  factory BasketItem.empty() => BasketItem(
    id: '',
    deliveryId: '',
    productName: '',
    quantity: 1.0,
    unit: 'kg',
    isBio: true,
  );

  factory BasketItem.fromJson(Map<String, dynamic> json) =>
      _$BasketItemFromJson(json);
}
