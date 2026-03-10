import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

part 'ocr_service.g.dart';

@riverpod
OcrService ocrService(Ref ref) => OcrService();

/// Result of parsing a single OCR text line
class OcrItem {
  final String rawLine;
  final String productName;
  final double? quantity;
  final String? unit;
  final bool confirmed;

  const OcrItem({
    required this.rawLine,
    required this.productName,
    this.quantity,
    this.unit,
    this.confirmed = true,
  });

  OcrItem copyWith({
    String? rawLine,
    String? productName,
    double? quantity,
    String? unit,
    bool? confirmed,
  }) {
    return OcrItem(
      rawLine: rawLine ?? this.rawLine,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      confirmed: confirmed ?? this.confirmed,
    );
  }
}

class OcrService {
  // ── Supported units (ordered by specificity to prevent partial matches) ──
  static const _units = [
    'kg', 'g', 'gr', 'litre', 'litres', 'l', 'cl', 'ml',
    'botte', 'bottes', 'bouquet', 'tête', 'têtes', 'piece', 'pièce',
    'pièces', 'sachet', 'sachets', 'barquette', 'barquettes',
  ];

  // qty-first regex: "1,5 kg carottes", "2 pièces poireaux"
  static final _qtyFirstRe = RegExp(
    r'^(\d+[.,]?\d*)\s*(' + _units.join('|') + r')\.?\s+(.+)$',
    caseSensitive: false,
  );

  // qty-last regex: "carottes 1,5 kg", "poireaux 2 pièces"
  static final _qtyLastRe = RegExp(
    r'^(.+?)\s+(\d+[.,]?\d*)\s*(' + _units.join('|') + r')\.?$',
    caseSensitive: false,
  );

  // No unit: "carottes 3" or "3 carottes"
  static final _numFirstRe = RegExp(r'^(\d+[.,]?\d*)\s+(.+)$');
  static final _numLastRe = RegExp(r'^(.+?)\s+(\d+[.,]?\d*)$');

  /// Run ML Kit OCR on an image file
  Future<List<String>> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final result = await recognizer.processImage(inputImage);
      return result.blocks
          .expand((block) => block.lines)
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty && line.length > 1)
          .toList();
    } finally {
      recognizer.close();
    }
  }

  /// Parse a list of raw OCR lines into structured OcrItem objects
  List<OcrItem> parseLines(List<String> lines) {
    return lines
        .map((line) => _parseLine(line))
        .where((item) => item != null)
        .cast<OcrItem>()
        .toList();
  }

  OcrItem? _parseLine(String line) {
    // Skip lines that look like dates, prices, headers
    if (_looksLikeHeader(line)) return null;

    final cleaned = _cleanLine(line);
    if (cleaned.length < 2) return null;

    // Try qty-first: "1.5 kg carottes"
    var match = _qtyFirstRe.firstMatch(cleaned);
    if (match != null) {
      return OcrItem(
        rawLine: line,
        productName: _capitalizeFirst(match.group(3)!.trim()),
        quantity: _parseQty(match.group(1)!),
        unit: _normalizeUnit(match.group(2)!),
      );
    }

    // Try qty-last: "carottes 1.5 kg"
    match = _qtyLastRe.firstMatch(cleaned);
    if (match != null) {
      return OcrItem(
        rawLine: line,
        productName: _capitalizeFirst(match.group(1)!.trim()),
        quantity: _parseQty(match.group(2)!),
        unit: _normalizeUnit(match.group(3)!),
      );
    }

    // Try number-first (no unit): "3 pommes"
    match = _numFirstRe.firstMatch(cleaned);
    if (match != null) {
      return OcrItem(
        rawLine: line,
        productName: _capitalizeFirst(match.group(2)!.trim()),
        quantity: _parseQty(match.group(1)!),
        unit: 'pièce',
      );
    }

    // Try number-last: "pommes 3"
    match = _numLastRe.firstMatch(cleaned);
    if (match != null) {
      return OcrItem(
        rawLine: line,
        productName: _capitalizeFirst(match.group(1)!.trim()),
        quantity: _parseQty(match.group(2)!),
        unit: 'pièce',
      );
    }

    // Fallback: treat whole line as product name, qty 1
    if (cleaned.length >= 3) {
      return OcrItem(
        rawLine: line,
        productName: _capitalizeFirst(cleaned),
        quantity: 1.0,
        unit: 'pièce',
      );
    }

    return null;
  }

  bool _looksLikeHeader(String line) {
    final lower = line.toLowerCase().trim();
    return lower.startsWith('total') ||
        lower.startsWith('date') ||
        lower.startsWith('livraison') ||
        lower.startsWith('semaine') ||
        lower.startsWith('amap') ||
        RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$').hasMatch(lower) ||
        RegExp(r'^\d+[.,]\d+\s*€?$').hasMatch(lower) ||
        (lower.length < 3);
  }

  String _cleanLine(String line) {
    return line
        .replaceAll(RegExp(r'[•·–—]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double? _parseQty(String s) {
    final cleaned = s.replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  String _normalizeUnit(String unit) {
    final u = unit.toLowerCase().trim();
    if (u == 'g' || u == 'gr') return 'g';
    if (u == 'litre' || u == 'litres' || u == 'l') return 'L';
    if (u == 'botte' || u == 'bottes') return 'botte';
    if (u == 'pièce' || u == 'piece' || u == 'pièces') return 'pièce';
    if (u == 'tête' || u == 'têtes') return 'tête';
    if (u == 'sachet' || u == 'sachets') return 'sachet';
    if (u == 'barquette' || u == 'barquettes') return 'barquette';
    return u;
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
