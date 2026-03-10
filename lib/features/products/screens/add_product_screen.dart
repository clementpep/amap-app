import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/product_repository.dart';
import '../../../core/widgets/common_widgets.dart';

const _units = ['kg', 'g', 'L', 'cl', 'botte', 'pièce', 'sachet', 'barquette', 'tête'];

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _bioPriceCtrl = TextEditingController();
  final _convPriceCtrl = TextEditingController();
  String _selectedUnit = 'kg';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _bioPriceCtrl.dispose();
    _convPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.upsertProduct(
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : null,
        unit: _selectedUnit,
        barcode: _barcodeCtrl.text.trim().isNotEmpty ? _barcodeCtrl.text.trim() : null,
      );

      // Add prices if provided
      if (_bioPriceCtrl.text.isNotEmpty) {
        await repo.addPrice(
          productId: product.id,
          priceType: 'bio',
          price: double.parse(_bioPriceCtrl.text.replaceAll(',', '.')),
          unit: _selectedUnit,
          source: 'manual',
        );
      }
      if (_convPriceCtrl.text.isNotEmpty) {
        await repo.addPrice(
          productId: product.id,
          priceType: 'conv',
          price: double.parse(_convPriceCtrl.text.replaceAll(',', '.')),
          unit: _selectedUnit,
          source: 'manual',
        );
      }

      if (mounted) {
        showSuccessSnackbar(context, 'Produit ajouté !');
        context.pop();
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Erreur lors de l\'ajout du produit.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un produit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du produit *',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined),
                  hintText: 'ex: Légumes, Fruits, Laitages...',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Code-barres (EAN)',
                        prefixIcon: Icon(Icons.barcode_reader),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'Unité'),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v!),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Prix de référence (optionnel)',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bioPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Prix bio (€)',
                        prefixIcon: Icon(Icons.eco, color: Colors.green.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _convPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix conv. (€)',
                        prefixIcon: Icon(Icons.store_outlined, color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Ajouter le produit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
