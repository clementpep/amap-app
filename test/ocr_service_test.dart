import 'package:flutter_test/flutter_test.dart';
import 'package:amap_app/features/delivery/data/ocr_service.dart';

void main() {
  late OcrService ocrService;

  setUp(() {
    ocrService = OcrService();
  });

  group('OcrService.parseLines', () {
    test('parses qty-first format: "1,5 kg carottes"', () {
      final results = ocrService.parseLines(['1,5 kg carottes']);
      expect(results, hasLength(1));
      expect(results[0].productName, equals('Carottes'));
      expect(results[0].quantity, equals(1.5));
      expect(results[0].unit, equals('kg'));
    });

    test('parses qty-last format: "carottes 1,5 kg"', () {
      final results = ocrService.parseLines(['carottes 1,5 kg']);
      expect(results, hasLength(1));
      expect(results[0].productName, equals('Carottes'));
      expect(results[0].quantity, equals(1.5));
      expect(results[0].unit, equals('kg'));
    });

    test('parses number-first without unit: "3 pommes"', () {
      final results = ocrService.parseLines(['3 pommes']);
      expect(results, hasLength(1));
      expect(results[0].productName, equals('Pommes'));
      expect(results[0].quantity, equals(3.0));
      expect(results[0].unit, equals('pièce'));
    });

    test('parses botte unit: "2 bottes persil"', () {
      final results = ocrService.parseLines(['2 bottes persil']);
      expect(results, hasLength(1));
      expect(results[0].productName, equals('Persil'));
      expect(results[0].quantity, equals(2.0));
      expect(results[0].unit, equals('botte'));
    });

    test('filters header lines: "Total"', () {
      final results = ocrService.parseLines(['Total']);
      expect(results, isEmpty);
    });

    test('filters date lines: "15/01/2024"', () {
      final results = ocrService.parseLines(['15/01/2024']);
      expect(results, isEmpty);
    });

    test('filters price-only lines: "12,50"', () {
      final results = ocrService.parseLines(['12,50']);
      expect(results, isEmpty);
    });

    test('handles mixed list', () {
      final lines = [
        'Livraison du 15/01/2024',
        '1 kg carottes',
        '2 bottes persil',
        'Total',
        '500 g courgettes',
      ];
      final results = ocrService.parseLines(lines);
      expect(results.length, greaterThanOrEqualTo(3));
    });

    test('falls back to product name only for unstructured lines', () {
      final results = ocrService.parseLines(['Poireaux']);
      expect(results, hasLength(1));
      expect(results[0].productName, equals('Poireaux'));
      expect(results[0].quantity, equals(1.0));
    });
  });
}
