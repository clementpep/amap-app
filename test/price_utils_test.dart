import 'package:flutter_test/flutter_test.dart';
import 'package:amap_app/features/price_comparison/models/price_comparison_result.dart';

void main() {
  group('PriceComparisonResult calculations', () {
    test('bioCost = bioPrice * quantity', () {
      const item = PriceComparisonResult(
        productName: 'Carottes',
        quantity: 2.0,
        unit: 'kg',
        isBio: true,
        bioPrice: 3.50,
        convPrice: 2.00,
      );
      expect(item.bioCost, equals(7.0));
    });

    test('convCost = convPrice * quantity', () {
      const item = PriceComparisonResult(
        productName: 'Carottes',
        quantity: 2.0,
        unit: 'kg',
        isBio: true,
        bioPrice: 3.50,
        convPrice: 2.00,
      );
      expect(item.convCost, equals(4.0));
    });

    test('delta = convCost - bioCost', () {
      const item = PriceComparisonResult(
        productName: 'Carottes',
        quantity: 2.0,
        unit: 'kg',
        isBio: true,
        bioPrice: 3.50,
        convPrice: 2.00,
      );
      // bio=7, conv=4 → delta = 4-7 = -3
      expect(item.delta, equals(-3.0));
    });

    test('savings positive when bio cheaper than conv', () {
      const item = PriceComparisonResult(
        productName: 'Salade',
        quantity: 1.0,
        unit: 'pièce',
        isBio: true,
        bioPrice: 1.50,
        convPrice: 2.50,
      );
      expect(item.delta, equals(1.0));
      expect(item.isCheaperBio, isTrue);
    });

    test('hasBothPrices is false when one price is null', () {
      const item = PriceComparisonResult(
        productName: 'Myrtilles',
        quantity: 0.5,
        unit: 'kg',
        isBio: true,
        bioPrice: null,
        convPrice: 5.00,
      );
      expect(item.hasBothPrices, isFalse);
    });

    test('deltaPercent is 0 when convCost is 0', () {
      const item = PriceComparisonResult(
        productName: 'Test',
        quantity: 1.0,
        unit: 'kg',
        isBio: true,
        bioPrice: 2.0,
        convPrice: 0.0,
      );
      expect(item.deltaPercent, equals(0.0));
    });
  });

  group('DeliveryComparison totals', () {
    test('totalSavings = totalConvCost - totalBioCost', () {
      final comparison = DeliveryComparison(
        deliveryId: 'test-id',
        deliveredAt: DateTime(2024, 1, 15),
        items: const [],
        totalBioCost: 25.0,
        totalConvCost: 40.0,
      );
      expect(comparison.totalSavings, equals(15.0));
    });

    test('savingsPercent rounds correctly', () {
      final comparison = DeliveryComparison(
        deliveryId: 'test-id',
        deliveredAt: DateTime(2024, 1, 15),
        items: const [],
        totalBioCost: 30.0,
        totalConvCost: 40.0,
      );
      expect(comparison.savingsPercent, equals(25.0));
    });
  });
}
