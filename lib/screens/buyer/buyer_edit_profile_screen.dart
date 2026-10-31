import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/buyer_service.dart';
import '../../core/services/api.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/grad_button.dart';
import '../../widgets/field_card.dart';

class BuyerEditProfileScreen extends StatefulWidget {
  const BuyerEditProfileScreen({super.key});
  @override State<BuyerEditProfileScreen> createState() => _BuyerEditProfileState();
}

class _BuyerEditProfileState extends State<BuyerEditProfileScreen> {
  final _fk = GlobalKey<FormState>();
  late TextEditingController _name, _fn, _ln, _mi, _contact,
      _province, _muni, _barangay, _street, _houseNo;
  String? _sex;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    final p = user.profile;
    _name     = TextEditingController(text: user.name);
    _fn       = TextEditingController(text: p?.firstName ?? '');
    _ln       = TextEditingController(text: p?.lastName ?? '');
    _mi       = TextEditingController(text: p?.middleInitial ?? '');
    _contact  = TextEditingController(text: p?.contactNo ?? '');
    _province = TextEditingController(text: p?.province ?? '');
    _muni     = TextEditingController(text: p?.municipality ?? '');
    _barangay = TextEditingController(text: p?.barangay ?? '');
    _street   = TextEditingController(text: p?.street ?? '');
    _houseNo  = TextEditingController(text: p?.houseNo ?? '');
    _sex = p?.sex;
  }

  @override void dispose() {
    for (final c in [_name,_fn,_ln,_mi,_contact,_province,_muni,_barangay,_street,_houseNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'first_name': _fn.text.trim(),
        'last_name': _ln.text.trim(),
        if (_mi.text.trim().isNotEmpty) 'middle_initial': _mi.text.trim(),
        if (_sex != null) 'sex': _sex,
        if (_contact.text.trim().isNotEmpty)  'contact_no': _contact.text.trim(),
        if (_province.text.trim().isNotEmpty) 'province': _province.text.trim(),
        if (_muni.text.trim().isNotEmpty)     'municipality': _muni.text.trim(),
        if (_barangay.text.trim().isNotEmpty) 'barangay': _barangay.text.trim(),
        if (_street.text.trim().isNotEmpty)   'street': _street.text.trim(),
        if (_houseNo.text.trim().isNotEmpty)  'house_no': _houseNo.text.trim(),
      };
      await BuyerService.updateProfile(body);
      final updated = await BuyerService.profile();
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!'), backgroundColor: C.b700));
    } on ApiError catch (e) { setState(() => _error = e.message); }
    catch (_) { setState(() => _error = 'Failed to update profile.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const TaptapNavBar(title: 'Edit Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _fk,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FieldCard(title: 'Account', titleIcon: Icons.person_outline, children: [
              _f('Display Name', _name, required: true),
            ]),
            const SizedBox(height: 12),
            FieldCard(title: 'Personal', titleIcon: Icons.badge_outlined, children: [
              Row(children: [
                Expanded(child: _f('Last Name', _ln)),
                const SizedBox(width: 10),
                Expanded(child: _f('First Name', _fn)),
              ]),
              const SizedBox(height: 12),
              _f('Middle Initial', _mi),
              const SizedBox(height: 12),
              _dropdown('Sex', ['Male', 'Female'], _sex, (v) => setState(() => _sex = v)),
              const SizedBox(height: 12),
              _f('Contact No.', _contact, kb: TextInputType.phone),
            ]),
            const SizedBox(height: 12),
            FieldCard(title: 'Address', titleIcon: Icons.location_on_outlined, children: [
              _f('Province', _province),
              const SizedBox(height: 12),
              _f('Municipality / City', _muni),
              const SizedBox(height: 12),
              _f('Barangay', _barangay),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _f('Street', _street)),
                const SizedBox(width: 10),
                Expanded(child: _f('House No.', _houseNo)),
              ]),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.dangerBg, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13))),
            ],
            const SizedBox(height: 20),
            GradButton(label: 'Save Changes', icon: Icons.save_outlined, onPressed: _save, loading: _loading),
          ]),
        ),
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl, {
    bool required = false, TextInputType kb = TextInputType.text,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(text: label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.textPrimary),
      children: required ? const [TextSpan(text: ' *', style: TextStyle(color: C.danger))] : null)),
    const SizedBox(height: 5),
    TextFormField(controller: ctrl, keyboardType: kb,
      decoration: InputDecoration(hintText: label),
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null),
  ]);

  Widget _dropdown(String label, List<String> opts, String? value, void Function(String?) onChange) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.textPrimary)),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(initialValue: value, onChanged: onChange,
        decoration: const InputDecoration(), hint: Text('Select $label'),
        items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList()),
    ]);
}
