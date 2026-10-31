import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/buyer_service.dart';
import '../../core/services/api.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/grad_button.dart';
import '../../widgets/field_card.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  final _fk = GlobalKey<FormState>();
  final _province = TextEditingController(),
        _muni     = TextEditingController(),
        _barangay = TextEditingController(),
        _street   = TextEditingController(),
        _houseNo  = TextEditingController(),
        _notes    = TextEditingController();
  String _payment = 'cod';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<AuthProvider>().user?.profile;
      if (profile != null) {
        _province.text = profile.province ?? '';
        _muni.text     = profile.municipality ?? '';
        _barangay.text = profile.barangay ?? '';
        _street.text   = profile.street ?? '';
        _houseNo.text  = profile.houseNo ?? '';
      }
    });
  }

  @override void dispose() {
    for (final c in [_province,_muni,_barangay,_street,_houseNo,_notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await BuyerService.checkout(
        province: _province.text.trim(), municipality: _muni.text.trim(),
        barangay: _barangay.text.trim(),
        street: _street.text.trim().isEmpty ? null : _street.text.trim(),
        houseNo: _houseNo.text.trim().isEmpty ? null : _houseNo.text.trim(),
        paymentMethod: _payment,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      await context.read<CartProvider>().load();
      if (!mounted) return;
      _showSuccess();
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: C.danger));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order failed. Please try again.'), backgroundColor: C.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 70, height: 70,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [C.b50, C.b100]),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 40, color: C.b700)),
        const SizedBox(height: 16),
        const Text('Order Placed!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 8),
        const Text('Your order has been placed successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.textSecondary, fontSize: 13)),
      ]),
      actions: [TextButton(
        onPressed: () {
          Navigator.pop(context); // close dialog
          Navigator.pop(context); // back to cart
        },
        child: const Text('OK', style: TextStyle(color: C.b700, fontWeight: FontWeight.w700, fontSize: 16)),
      )],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: const TaptapNavBar(title: 'Checkout'),
      body: Form(
        key: _fk,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Delivery Address
            FieldCard(
              title: 'Delivery Address',
              titleIcon: Icons.location_on_outlined,
              subtitle: 'Where should we send your order',
              children: [
                _field('Province', _province, required: true),
                const SizedBox(height: 12),
                _field('Municipality / City', _muni, required: true),
                const SizedBox(height: 12),
                _field('Barangay', _barangay, required: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Street', _street)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('House No.', _houseNo)),
                ]),
              ],
            ),
            const SizedBox(height: 14),

            // Payment Method — COD and GCash only (no bank transfer)
            FieldCard(
              title: 'Payment Method',
              titleIcon: Icons.wallet_outlined,
              subtitle: 'How would you like to pay',
              children: const ['cod', 'gcash'].map((m) {
                final selected = _payment == m;
                return GestureDetector(
                  onTap: () => setState(() => _payment = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? C.b50 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? C.b600 : const Color(0xFFE2E5E4),
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: selected
                          ? [const BoxShadow(color: C.b100, blurRadius: 6)]
                          : null,
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: selected ? C.b600 : C.gray100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_payIcon(m), size: 16,
                            color: selected ? Colors.white : C.textMuted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppConstants.paymentLabel(m),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                color: selected ? C.b800 : C.textPrimary)),
                        Text(_paySubtitle(m),
                            style: const TextStyle(fontSize: 11, color: C.textMuted)),
                      ])),
                      if (selected) const Icon(Icons.check_circle, color: C.b600, size: 18),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Notes
            FieldCard(
              title: 'Order Notes',
              titleIcon: Icons.note_outlined,
              subtitle: 'Optional — anything the seller should know',
              children: [
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Any special instructions? (optional)'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Order Summary — after notes, matching website layout
            FieldCard(
              title: 'Order Summary',
              titleIcon: Icons.receipt_outlined,
              children: [
                ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item.product?.name ?? 'Unknown'} × ${item.quantity}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('₱${(item.product?.price ?? 0).toStringAsFixed(2)} each',
                          style: const TextStyle(fontSize: 11, color: C.textMuted)),
                    ])),
                    Text('₱${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                )),
                const Divider(height: 14),
                _summRow('Subtotal', '₱${cart.subtotal.toStringAsFixed(2)}'),
                _summRow('Admin Commission (10%)',
                    '₱${(cart.subtotal * 0.10).toStringAsFixed(2)}', small: true),
                const SizedBox(height: 4),
                _summRow('Total', '₱${cart.subtotal.toStringAsFixed(2)}',
                    bold: true, color: C.b700),
              ],
            ),
            const SizedBox(height: 20),

            GradButton(
              label: 'Place Order',
              icon: Icons.check,
              onPressed: cart.isEmpty ? null : _placeOrder,
              loading: _loading,
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(text: label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.textPrimary),
        children: required ? const [TextSpan(text: ' *', style: TextStyle(color: C.danger))] : null)),
      const SizedBox(height: 5),
      TextFormField(controller: ctrl,
        decoration: InputDecoration(hintText: label),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null),
    ]);

  Widget _summRow(String label, String value, {bool bold = false, Color? color, bool small = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: small ? 12 : 13, color: C.textSecondary)),
        Text(value, style: TextStyle(
          fontSize: bold ? 17 : (small ? 12 : 13),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? C.textPrimary)),
      ]),
    );

  IconData _payIcon(String m) => switch(m) {
    'cod'           => Icons.money,
    'gcash'         => Icons.phone_android,
    'bank_transfer' => Icons.account_balance,
    _ => Icons.payment,
  };

  String _paySubtitle(String m) => switch(m) {
    'cod'           => 'Pay when your order arrives',
    'gcash'         => 'Pay via GCash mobile wallet',
    'bank_transfer' => 'Pay via bank transfer',
    _ => '',
  };
}
