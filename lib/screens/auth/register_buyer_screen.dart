import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api.dart';
import '../../providers/auth_provider.dart';

// ── PSGC model ────────────────────────────────────────────────────────────────
class _PsgcItem {
  final String code, name;
  const _PsgcItem(this.code, this.name);
}

class RegisterBuyerScreen extends StatefulWidget {
  const RegisterBuyerScreen({super.key});
  @override State<RegisterBuyerScreen> createState() => _RegBuyerState();
}

class _RegBuyerState extends State<RegisterBuyerScreen> {
  final _fk = GlobalKey<FormState>();

  // controllers
  final _ln      = TextEditingController();
  final _fn      = TextEditingController();
  final _mi      = TextEditingController();
  final _email   = TextEditingController();
  final _contact = TextEditingController();
  final _street  = TextEditingController();
  final _houseNo = TextEditingController();
  final _pw      = TextEditingController();
  final _cpw     = TextEditingController();

  // personal
  String? _sex;
  DateTime? _birthday;
  int?     _age;

  // address
  List<_PsgcItem> _provinces     = [];
  List<_PsgcItem> _municipalities = [];
  List<_PsgcItem> _barangays      = [];
  _PsgcItem? _province;
  _PsgcItem? _municipality;
  _PsgcItem? _barangay;
  bool _loadingProv = true, _loadingMuni = false, _loadingBrgy = false;

  // file
  File?   _validId;
  String? _validIdName;

  // ui state
  bool    _ob1     = true, _ob2 = true;
  bool    _loading = false;
  String? _error;

  // Cached border shapes — created once, never recreated per build
  static final _borderDefault  = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD1D5DB)));
  static final _borderFocused  = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF2E7C82), width: 1.5));
  static final _borderError    = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDC2626)));
  static final _borderErrFocus = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5));

  // Controllers for read-only date/age fields — managed like all other controllers
  final _birthdayCtrl = TextEditingController();
  final _ageCtrl      = TextEditingController();

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    for (final c in [_ln,_fn,_mi,_email,_contact,_street,_houseNo,_pw,_cpw,_birthdayCtrl,_ageCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── PSGC ───────────────────────────────────────────────────────────────────
  Future<void> _loadProvinces() async {
    try {
      final r = await http.get(Uri.parse('https://psgc.gitlab.io/api/provinces/'));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List)
            .map((e) => _PsgcItem(e['code'] as String, e['name'] as String))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        setState(() { _provinces = list; _loadingProv = false; });
      }
    } catch (_) {
      setState(() => _loadingProv = false);
    }
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    setState(() { _loadingMuni = true; _municipalities = []; _barangays = [];
                  _municipality = null; _barangay = null; });
    try {
      final r = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/provinces/$provinceCode/cities-municipalities/'));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List)
            .map((e) => _PsgcItem(e['code'] as String, e['name'] as String))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        setState(() { _municipalities = list; _loadingMuni = false; });
      }
    } catch (_) { setState(() => _loadingMuni = false); }
  }

  Future<void> _loadBarangays(String muniCode) async {
    setState(() { _loadingBrgy = true; _barangays = []; _barangay = null; });
    try {
      final r = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/cities-municipalities/$muniCode/barangays/'));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List)
            .map((e) => _PsgcItem(e['code'] as String, e['name'] as String))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        setState(() { _barangays = list; _loadingBrgy = false; });
      }
    } catch (_) { setState(() => _loadingBrgy = false); }
  }

  // ── age auto-calc ──────────────────────────────────────────────────────────
  void _calcAge(DateTime bd) {
    final today = DateTime.now();
    int age = today.year - bd.year;
    if (today.month < bd.month ||
        (today.month == bd.month && today.day < bd.day)) {
      age--;
    }
    final computed = age > 0 ? age : 0;
    setState(() => _age = computed);
    _ageCtrl.text = computed.toString();
  }

  // ── file picker ────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _validId     = File(picked.path);
        _validIdName = picked.name;
      });
    }
  }

  // ── submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final bdStr = _birthday == null ? null
          : '${_birthday!.year}-'
            '${_birthday!.month.toString().padLeft(2,'0')}-'
            '${_birthday!.day.toString().padLeft(2,'0')}';

      await AuthService.registerBuyer(
        firstName:             _fn.text.trim(),
        lastName:              _ln.text.trim(),
        middleInitial:         _mi.text.trim().isEmpty ? null : _mi.text.trim(),
        sex:                   _sex,
        birthday:              bdStr,
        age:                   _age,
        email:                 _email.text.trim(),
        contactNo:             _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        province:              _province?.name,
        municipality:          _municipality?.name,
        barangay:              _barangay?.name,
        street:                _street.text.trim().isEmpty ? null : _street.text.trim(),
        houseNo:               _houseNo.text.trim().isEmpty ? null : _houseNo.text.trim(),
        password:              _pw.text,
        passwordConfirmation:  _cpw.text,
        validId:               _validId,
      );
      if (!mounted) return;
      // Buyer is auto-approved — log in immediately and go to buyer dashboard
      final auth = context.read<AuthProvider>();
      final ok = await auth.login(_email.text.trim(), _pw.text);
      if (!mounted) return;
      if (ok) {
        Navigator.pushNamedAndRemoveUntil(context, '/buyer', (_) => false);
      } else {
        // login failed for some reason, fall back to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F6F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/taptapgo-logo.png', width: 31, height: 31),
          const SizedBox(width: 8),
          RichText(text: const TextSpan(children: [
            TextSpan(text: 'Taptap',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF0E2A38))),
            TextSpan(text: 'Go',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic, color: Color(0xFF2E7C82))),
          ])),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 15, color: Color(0xFF1F5F66)),
            label: const Text('Back to Login',
                style: TextStyle(fontSize: 13, color: Color(0xFF1F5F66),
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: _card(),
              ),
            ),
          ),
        ),
        // pinned footer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6F4),
            border: Border(top: BorderSide(color: Color(0xFFE8EAE9))),
          ),
          child: const Text('© 2026 TaptapGo. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFFADB5B4))),
        ),
      ]),
    );
  }

  Widget _card() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F1EF)),
      boxShadow: const [
        BoxShadow(color: Color(0x160E2A38), blurRadius: 40, offset: Offset(0, 16)),
      ],
    ),
    padding: const EdgeInsets.all(28),
    child: Form(
      key: _fk,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── header row ───────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF8F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, size: 22, color: Color(0xFF2E7C82)),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Buyer Registration',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF0E2A38))),
            Text('Create your buyer account',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        ]),
        const SizedBox(height: 24),

        // ── error banner ─────────────────────────────────────────────────────
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
              GestureDetector(
                onTap: () => setState(() => _error = null),
                child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 15)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── row 1: First Name / Last Name / Middle Initial ───────────────────
        _row3(
          _textField(label: 'First Name', ctrl: _fn, required: true, hint: 'First name'),
          _textField(label: 'Last Name', ctrl: _ln, required: true, hint: 'Last name'),
          _textField(label: 'Middle Initial', ctrl: _mi, hint: 'M.I.',
              formatters: [LengthLimitingTextInputFormatter(2)]),
        ),
        const SizedBox(height: 14),

        // ── row 2: Sex / Birthday / Age ──────────────────────────────────────
        _row3(
          _sexDropdown(),
          _birthdayField(),
          _ageField(),
        ),
        const SizedBox(height: 14),

        // ── row 3: Email / Contact ───────────────────────────────────────────
        _row2(
          _textField(
            label: 'Email', ctrl: _email, required: false, hint: 'Email address',
            kb: TextInputType.emailAddress,
            prefix: const Icon(Icons.email_outlined, size: 15, color: Color(0xFF2E7C82)),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          _textField(
            label: 'Contact No.', ctrl: _contact, required: true,
            hint: '09XXXXXXXXX', kb: TextInputType.phone,
            prefix: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF2E7C82)),
          ),
        ),
        const SizedBox(height: 14),

        // ── Address section ──────────────────────────────────────────────────
        const Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2E7C82)),
          SizedBox(width: 6),
          Text('Address',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF1F5F66))),
        ]),
        const SizedBox(height: 10),

        // Province / Municipality / Barangay
        _row3(
          _psgcDropdown(
            label: 'Province', required: true,
            loading: _loadingProv, items: _provinces, value: _province,
            hint: 'Select Province',
            onChanged: (v) { setState(() => _province = v); if (v != null) _loadMunicipalities(v.code); },
          ),
          _psgcDropdown(
            label: 'Municipality', required: true,
            loading: _loadingMuni, items: _municipalities, value: _municipality,
            hint: 'Select Municipality',
            onChanged: (v) { setState(() => _municipality = v); if (v != null) _loadBarangays(v.code); },
          ),
          _psgcDropdown(
            label: 'Barangay', required: true,
            loading: _loadingBrgy, items: _barangays, value: _barangay,
            hint: 'Select Barangay',
            onChanged: (v) => setState(() => _barangay = v),
          ),
        ),
        const SizedBox(height: 12),

        // Street / House No.
        _row2(
          _textField(label: 'Street', ctrl: _street, hint: 'Street name'),
          _textField(label: 'House No. / Unit', ctrl: _houseNo, hint: 'House/Unit number'),
        ),
        const SizedBox(height: 14),

        // ── Password / Confirm ───────────────────────────────────────────────
        _row2(
          _pwField(
            label: 'Password', ctrl: _pw, obscure: _ob1,
            hint: 'Create password (min 8 characters)',
            toggle: () => setState(() => _ob1 = !_ob1),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          _pwField(
            label: 'Confirm Password', ctrl: _cpw, obscure: _ob2,
            hint: 'Confirm password',
            toggle: () => setState(() => _ob2 = !_ob2),
            validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
          ),
        ),
        const SizedBox(height: 14),

        // ── Upload Valid ID ──────────────────────────────────────────────────
        const Row(children: [
          Icon(Icons.credit_card_outlined, size: 15, color: Color(0xFF2E7C82)),
          SizedBox(width: 6),
          Text('Upload Valid ID',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: Color(0xFF374151))),
          Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFCFB),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: const Text('Choose File',
                    style: TextStyle(fontSize: 12, color: Color(0xFF374151),
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _validIdName ?? 'No file chosen',
                  style: TextStyle(fontSize: 13,
                      color: _validIdName != null
                          ? const Color(0xFF374151)
                          : const Color(0xFF9AA5A4)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Accepted: JPG, PNG, PDF. Max 5MB.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 14),

        // ── Info notice ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF8F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB4DEDB)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Color(0xFF2E7C82)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'After submitting, please wait for the administrator\'s approval. '
                'You will be notified via email.',
                style: TextStyle(fontSize: 12, color: Color(0xFF1F5F66)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Submit button ────────────────────────────────────────────────────
        _SubmitButton(loading: _loading, onPressed: _submit),
        const SizedBox(height: 18),

        // OR divider
        const Row(children: [
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF), letterSpacing: 1)),
          ),
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ]),
        const SizedBox(height: 14),

        // Already have an account
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Already have an account? ',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('Login here',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1F5F66))),
          ),
        ]),
      ]),
    ),
  );

  // ── layout helpers ─────────────────────────────────────────────────────────
  // On mobile (<500px) stack vertically; on wider screens use side-by-side columns.
  Widget _row3(Widget a, Widget b, Widget c) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth >= 500) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a), const SizedBox(width: 10),
          Expanded(child: b), const SizedBox(width: 10),
          Expanded(child: c),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        a, const SizedBox(height: 12),
        b, const SizedBox(height: 12),
        c,
      ]);
    },
  );

  Widget _row2(Widget a, Widget b) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth >= 400) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a), const SizedBox(width: 10),
          Expanded(child: b),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        a, const SizedBox(height: 12),
        b,
      ]);
    },
  );

  // ── field widgets ──────────────────────────────────────────────────────────
  Widget _textField({
    required String label,
    required TextEditingController ctrl,
    bool required = false,
    String? hint,
    TextInputType kb = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? prefix,
    String? Function(String?)? validator,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label, required: required, prefix: prefix),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: kb,
          inputFormatters: formatters,
          style: const TextStyle(fontSize: 13),
          decoration: _deco(hint ?? label),
          validator: validator ??
              (required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null),
        ),
      ]);

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool obscure,
    required VoidCallback toggle,
    String? hint,
    String? Function(String?)? validator,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label,
            required: true,
            prefix: const Icon(Icons.lock_outline, size: 15, color: Color(0xFF2E7C82))),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(fontSize: 13),
          decoration: _deco(hint ?? label).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18, color: const Color(0xFF9AA5A4)),
              onPressed: toggle,
            ),
          ),
          validator: validator,
        ),
      ]);

  Widget _sexDropdown() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Sex', required: true),
    const SizedBox(height: 5),
    DropdownButtonFormField<String>(
      initialValue: _sex,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: _deco('Select'),
      hint: const Text('Select', style: TextStyle(fontSize: 13, color: Color(0xFF9AA5A4))),
      items: const [
        DropdownMenuItem(value: 'Male',   child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
      ],
      onChanged: (v) => setState(() => _sex = v),
      validator: (v) => v == null ? 'Required' : null,
    ),
  ]);

  Widget _birthdayField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Birthday', required: true),
    const SizedBox(height: 5),
    TextFormField(
      readOnly: true,
      controller: _birthdayCtrl,
      style: const TextStyle(fontSize: 13),
      decoration: _deco('mm/dd/yyyy').copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined,
            size: 16, color: Color(0xFF9AA5A4)),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthday ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF2E7C82))),
            child: child!,
          ),
        );
        if (picked != null) {
          _birthdayCtrl.text = '${picked.month.toString().padLeft(2,'0')}/${picked.day.toString().padLeft(2,'0')}/${picked.year}';
          setState(() => _birthday = picked);
          _calcAge(picked);
        }
      },
      validator: (_) => _birthday == null ? 'Required' : null,
    ),
  ]);

  Widget _ageField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Age'),
    const SizedBox(height: 5),
    TextFormField(
      readOnly: true,
      controller: _ageCtrl,
      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      decoration: _deco('Auto').copyWith(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    ),
  ]);

  Widget _psgcDropdown({
    required String label,
    required bool required,
    required bool loading,
    required List<_PsgcItem> items,
    required _PsgcItem? value,
    required String hint,
    required void Function(_PsgcItem?) onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label, required: required, small: true),
        const SizedBox(height: 5),
        loading
            ? _dummyField(hint)
            : DropdownButtonFormField<_PsgcItem>(
                initialValue: value,
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                decoration: _deco(hint),
                hint: Text(hint,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9AA5A4))),
                isExpanded: true,
                items: items.map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.name, style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: onChanged,
                validator: required ? (v) => v == null ? 'Required' : null : null,
              ),
      ]);

  Widget _dummyField(String hint) => Container(
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFFBFCFB),
      border: Border.all(color: const Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Center(
      child: SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7C82)))),
  );

  // ── shared decoration ──────────────────────────────────────────────────────
  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFFBFCFB),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border:             _borderDefault,
    enabledBorder:      _borderDefault,
    focusedBorder:      _borderFocused,
    errorBorder:        _borderError,
    focusedErrorBorder: _borderErrFocus,
  );

  Widget _lbl(String text, {bool required = false, bool small = false, Widget? prefix}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (prefix != null) ...[prefix, const SizedBox(width: 5)],
        Text(text,
            style: TextStyle(
                fontSize: small ? 11 : 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151))),
        if (required)
          const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
      ]);
}

// ── gradient SUBMIT button ─────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _SubmitButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onPressed,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x300E2A38), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: loading
          ? const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.send, color: Colors.white, size: 17),
              SizedBox(width: 8),
              Text('SUBMIT REGISTRATION',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
    ),
  );
}
