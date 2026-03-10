import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/delivery_repository.dart';
import '../models/basket_item.dart';
import '../providers/delivery_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

const _units = ['kg', 'g', 'L', 'cl', 'botte', 'pièce', 'sachet', 'barquette', 'tête'];

class BasketFormScreen extends ConsumerStatefulWidget {
  final String? deliveryId;
  final String? imagePath;
  final List<Map<String, dynamic>>? prefilledItems;

  const BasketFormScreen({
    super.key,
    this.deliveryId,
    this.imagePath,
    this.prefilledItems,
  });

  @override
  ConsumerState<BasketFormScreen> createState() => _BasketFormScreenState();
}

class _BasketFormScreenState extends ConsumerState<BasketFormScreen> {
  final List<_ItemRow> _rows = [];
  DateTime _deliveredAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from OCR results
    if (widget.prefilledItems != null) {
      for (final item in widget.prefilledItems!) {
        _rows.add(_ItemRow(
          nameCtrl: TextEditingController(text: item['productName'] as String? ?? ''),
          qtyCtrl: TextEditingController(
            text: (item['quantity'] as double? ?? 1.0)
                .toString()
                .replaceAll(RegExp(r'\.0$'), ''),
          ),
          unit: item['unit'] as String? ?? 'pièce',
          isBio: item['isBio'] as bool? ?? true,
        ));
      }
    }
    if (_rows.isEmpty) _addRow();
  }

  void _addRow() {
    setState(() {
      _rows.add(_ItemRow(
        nameCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        unit: 'kg',
        isBio: true,
      ));
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Validate at least one named item
    final validRows = _rows.where((r) => r.nameCtrl.text.trim().isNotEmpty).toList();
    if (validRows.isEmpty) {
      showErrorSnackbar(context, 'Ajoutez au moins un produit.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Upload photo if present
      String? photoUrl;
      if (widget.imagePath != null) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }
        final fileName = '$userId/${_deliveredAt.millisecondsSinceEpoch}.jpg';
        final bytes = await File(widget.imagePath!).readAsBytes();
        await client.storage
            .from(SupabaseConfig.storageBucket)
            .uploadBinary(fileName, bytes);
        photoUrl = client.storage
            .from(SupabaseConfig.storageBucket)
            .getPublicUrl(fileName);
      }

      final items = validRows
          .map((row) => BasketItem(
                id: '',
                deliveryId: widget.deliveryId ?? '',
                productName: row.nameCtrl.text.trim(),
                quantity: double.tryParse(
                        row.qtyCtrl.text.replaceAll(',', '.')) ??
                    1.0,
                unit: row.unit,
                isBio: row.isBio,
              ))
          .toList();

      final repo = ref.read(deliveryRepositoryProvider);

      if (widget.deliveryId != null) {
        // Update existing delivery
        await repo.updateBasketItems(widget.deliveryId!, items);
      } else {
        // Create new delivery
        await repo.createDelivery(
          deliveredAt: _deliveredAt,
          items: items,
          photoUrl: photoUrl,
        );
      }

      // Invalidate the list so it refreshes
      ref.invalidate(deliveryListProvider);

      if (mounted) {
        showSuccessSnackbar(context, 'Livraison sauvegardée !');
        context.go('/deliveries');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, 'Erreur lors de la sauvegarde.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) setState(() => _deliveredAt = picked);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deliveryId != null ? 'Modifier le panier' : 'Nouveau panier'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo preview (if any)
          if (widget.imagePath != null)
            Container(
              height: 120,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date picker
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryGreen),
                        const SizedBox(width: 12),
                        Text(
                          'Livraison du ${_deliveredAt.day.toString().padLeft(2, '0')}/${_deliveredAt.month.toString().padLeft(2, '0')}/${_deliveredAt.year}',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, size: 16, color: AppTheme.textLight),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Produits',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Items
                ...List.generate(
                  _rows.length,
                  (index) => _ItemRowWidget(
                    key: ValueKey(index),
                    row: _rows[index],
                    onRemove: () => _removeRow(index),
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un produit'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.deliveryId != null ? 'Mettre à jour' : 'Enregistrer la livraison'),
          ),
        ),
      ),
    );
  }
}

// ─── Data model for a form row ────────────────────────────────
class _ItemRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;
  bool isBio;

  _ItemRow({
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.unit,
    required this.isBio,
  });

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
  }
}

// ─── Row widget ───────────────────────────────────────────────
class _ItemRowWidget extends StatefulWidget {
  final _ItemRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: widget.row.nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Nom du produit',
                      isDense: true,
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: widget.row.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.row.unit,
                  isDense: true,
                  underline: const SizedBox(),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => widget.row.unit = v);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Bio', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                Switch(
                  value: widget.row.isBio,
                  onChanged: (v) => setState(() => widget.row.isBio = v),
                  activeColor: AppTheme.primaryGreen,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.row.isBio ? AppTheme.paleGreen : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.row.isBio ? 'Produit BIO' : 'Conventionnel',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: widget.row.isBio ? AppTheme.primaryGreen : AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
