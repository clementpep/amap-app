import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class OcrReviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final List<String> recognizedLines;

  const OcrReviewScreen({
    super.key,
    required this.imagePath,
    required this.recognizedLines,
  });

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  late List<OcrItem> _items;

  @override
  void initState() {
    super.initState();
    final service = OcrService();
    _items = service.parseLines(widget.recognizedLines);
  }

  void _toggleConfirm(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(confirmed: !_items[index].confirmed);
    });
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _confirm() {
    final confirmedItems = _items
        .where((item) => item.confirmed)
        .map((item) => {
              'productName': item.productName,
              'quantity': item.quantity ?? 1.0,
              'unit': item.unit ?? 'pièce',
              'isBio': true,
            })
        .toList();

    context.push('/deliveries/basket-form', extra: {
      'imagePath': widget.imagePath,
      'items': confirmedItems,
    });
  }

  @override
  Widget build(BuildContext context) {
    final confirmedCount = _items.where((i) => i.confirmed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifier les produits'),
        actions: [
          TextButton(
            onPressed: () => context.push('/deliveries/basket-form',
                extra: {'imagePath': widget.imagePath}),
            child: const Text('Ignorer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo preview
          Container(
            height: 160,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(widget.imagePath)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Instructions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppTheme.textMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$confirmedCount produit${confirmedCount > 1 ? 's' : ''} sélectionné${confirmedCount > 1 ? 's' : ''}. '
                    'Appuyez pour (dés)activer, balayez pour supprimer.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items
          Expanded(
            child: _items.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'Aucun produit détecté',
                    subtitle: 'Vous pourrez les saisir manuellement.',
                    action: ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('Continuer'),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Dismissible(
                        key: Key('ocr_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppTheme.errorRed,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(index),
                        child: ListTile(
                          onTap: () => _toggleConfirm(index),
                          leading: Checkbox(
                            value: item.confirmed,
                            onChanged: (_) => _toggleConfirm(index),
                            activeColor: AppTheme.primaryGreen,
                          ),
                          title: Text(
                            item.productName,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              color: item.confirmed ? AppTheme.textDark : AppTheme.textLight,
                              decoration: item.confirmed ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: item.quantity != null
                              ? Text(
                                  '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${item.unit ?? ''}',
                                  style: const TextStyle(fontFamily: 'Poppins'),
                                )
                              : null,
                          trailing: item.confirmed
                              ? const Icon(Icons.check_circle, color: AppTheme.successGreen)
                              : const Icon(Icons.circle_outlined, color: AppTheme.textLight),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: confirmedCount > 0 ? _confirm : null,
            child: Text('Continuer avec $confirmedCount produit${confirmedCount > 1 ? 's' : ''}'),
          ),
        ),
      ),
    );
  }
}
