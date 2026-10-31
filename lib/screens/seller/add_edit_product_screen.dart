import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/seller_provider.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/grad_button.dart';
import '../../widgets/field_card.dart';

class AddEditProductScreen extends StatefulWidget {
  final int? productId;
  const AddEditProductScreen({super.key, this.productId});
  bool get isEdit => productId != null;
  @override State<AddEditProductScreen> createState() => _AddEditProductState();
}

class _AddEditProductState extends State<AddEditProductScreen> {
  final _fk = GlobalKey<FormState>();
  final _name = TextEditingController(), _desc = TextEditingController(),
        _price = TextEditingController(), _stock = TextEditingController();
  String _status = 'active';
  int? _categoryId;
  File? _imageFile;
  String? _existingImageUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SellerProvider>().loadCategories();
      if (widget.isEdit) _prefill();
    });
  }

  void _prefill() {
    final sp = context.read<SellerProvider>();
    final match = sp.products.where((p) => p.id == widget.productId);
    if (match.isNotEmpty) {
      final p = match.first;
      _name.text  = p.name;
      _desc.text  = p.description ?? '';
      _price.text = p.price.toString();
      _stock.text = p.stock.toString();
      _status = p.status;
      _categoryId = p.category?.id;
      _existingImageUrl = p.image;
      setState(() {});
    }
  }

  @override void dispose() { _name.dispose(); _desc.dispose(); _price.dispose(); _stock.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() { _imageFile = File(picked.path); });
  }

  Future<void> _save() async {
    if (!_fk.currentState!.validate()) return;
    final price = double.tryParse(_price.text);
    final stock = int.tryParse(_stock.text);
    if (price == null) { setState(() => _error = 'Invalid price'); return; }
    if (stock == null) { setState(() => _error = 'Invalid stock'); return; }

    setState(() { _loading = true; _error = null; });
    final sp = context.read<SellerProvider>();
    final bool ok;
    if (widget.isEdit) {
      ok = await sp.editProduct(widget.productId!,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        price: price, stock: stock, categoryId: _categoryId, status: _status,
        image: _imageFile);
    } else {
      ok = await sp.createProduct(
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        price: price, stock: stock, categoryId: _categoryId, status: _status,
        image: _imageFile);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEdit ? 'Product updated!' : 'Product created!'),
        backgroundColor: C.b700));
    } else {
      setState(() => _error = sp.error ?? 'Failed to save product');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<SellerProvider>().categories;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: TaptapNavBar(title: widget.isEdit ? 'Edit Product' : 'Add New Product'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _fk,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Image picker — matches Laravel dropzone
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.b50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.b200, style: BorderStyle.solid, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : _existingImageUrl != null
                          ? CachedNetworkImage(imageUrl: _existingImageUrl!, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _imgPlaceholder())
                          : _imgPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_outlined, size: 16, color: C.b600),
                label: Text(
                  _imageFile != null || _existingImageUrl != null ? 'Change Image' : 'Add Image',
                  style: const TextStyle(color: C.b600, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),

            FieldCard(
              title: 'Basic Information', titleIcon: Icons.info_outline,
              subtitle: 'What buyers will see first',
              children: [
                _field('Product Name', _name, required: true),
                const SizedBox(height: 12),
                _ddCategory(categories),
                const SizedBox(height: 12),
                _field('Description', _desc, maxLines: 4, hint: 'Describe your product...'),
              ],
            ),
            const SizedBox(height: 12),

            FieldCard(
              title: 'Pricing & Stock', titleIcon: Icons.tag,
              subtitle: 'Set price and available quantity',
              children: [
                Row(children: [
                  Expanded(child: _field('Price (₱)', _price, required: true,
                    kb: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) { if (v!.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; if (double.parse(v) < 0) return '≥ 0'; return null; })),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Stock', _stock, required: true,
                    kb: TextInputType.number,
                    validator: (v) { if (v!.isEmpty) return 'Required'; if (int.tryParse(v) == null) return 'Invalid'; if (int.parse(v) < 0) return '≥ 0'; return null; })),
                ]),
              ],
            ),
            const SizedBox(height: 12),

            FieldCard(
              title: 'Status', titleIcon: Icons.toggle_on_outlined,
              subtitle: 'Control visibility to buyers',
              children: [
                _statusPill('active', 'Active — visible to buyers'),
                const SizedBox(height: 8),
                _statusPill('inactive', 'Inactive — hidden from buyers'),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.dangerBg, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13))),
            ],
            const SizedBox(height: 20),
            GradButton(
              label: widget.isEdit ? 'Update Product' : 'Add Product',
              icon: widget.isEdit ? Icons.save_outlined : Icons.add_box_outlined,
              onPressed: _save, loading: _loading,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Cancel'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.cloud_upload_outlined, size: 36, color: C.b700),
    SizedBox(height: 8),
    Text('Tap to add image', style: TextStyle(color: C.b700, fontSize: 13, fontWeight: FontWeight.w500)),
    SizedBox(height: 3),
    Text('JPG, PNG. Max 5MB.', style: TextStyle(color: C.textMuted, fontSize: 11)),
  ]);

  Widget _field(String label, TextEditingController ctrl, {
    bool required = false, TextInputType kb = TextInputType.text,
    int maxLines = 1, String? hint, String? Function(String?)? validator,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(text: label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.textPrimary),
      children: required ? const [TextSpan(text: ' *', style: TextStyle(color: C.danger))] : null)),
    const SizedBox(height: 5),
    TextFormField(controller: ctrl, keyboardType: kb, maxLines: maxLines,
      decoration: InputDecoration(hintText: hint ?? label),
      validator: validator ?? (required ? (v) => v!.isEmpty ? 'Required' : null : null)),
  ]);

  Widget _ddCategory(List categories) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.textPrimary)),
    const SizedBox(height: 5),
    DropdownButtonFormField<int>(
      initialValue: _categoryId, onChanged: (v) => setState(() => _categoryId = v),
      decoration: const InputDecoration(), hint: const Text('Select Category'),
      items: [
        for (final cat in categories)
          if (!cat.isParent || cat.children.isEmpty)
            DropdownMenuItem<int>(value: cat.id, child: Text(cat.name))
          else ...[
            DropdownMenuItem<int>(
              enabled: false,
              child: Text(cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: C.textSecondary, fontSize: 12))),
            for (final sub in cat.children)
              DropdownMenuItem<int>(value: sub.id, child: Text('  ${sub.name}')),
          ],
      ],
    ),
  ]);

  Widget _statusPill(String value, String label) => GestureDetector(
    onTap: () => setState(() => _status = value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _status == value ? C.b50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _status == value ? C.b600 : const Color(0xFFE2E5E4),
          width: _status == value ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _status == value
              ? (value == 'active' ? C.b600 : C.textMuted)
              : const Color(0xFFD1D5DB),
        )),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 13, color: _status == value ? C.b800 : C.textSecondary,
                fontWeight: _status == value ? FontWeight.w600 : FontWeight.w400)),
      ]),
    ),
  );
}
