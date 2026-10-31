import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api.dart';

class _PsgcItem {
  final String code, name;
  const _PsgcItem(this.code, this.name);
}

// Top-level function required by compute() — runs in a background isolate.
List<_PsgcItem> _parsePsgc(String body) {
  final list = (jsonDecode(body) as List)
      .map((e) => _PsgcItem(e['code'] as String, e['name'] as String))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return list;
}

class RegisterCourierScreen extends StatefulWidget {
  const RegisterCourierScreen({super.key});
  @override State<RegisterCourierScreen> createState() => _RegCourierState();
}

class _RegCourierState extends State<RegisterCourierScreen> {
  final _fk      = GlobalKey<FormState>();
  final _ln      = TextEditingController();
  final _fn      = TextEditingController();
  final _mi      = TextEditingController();
  final _email   = TextEditingController();
  final _contact = TextEditingController(); // TC-RID-009 to TC-RID-011
  final _licenseNo     = TextEditingController();
  final _licenseExpiry = TextEditingController();
  final _plate   = TextEditingController();
  final _street  = TextEditingController();
  final _houseNo = TextEditingController();
  final _pw      = TextEditingController();
  final _cpw     = TextEditingController();

  String?   _sex;
  DateTime? _birthday;
  int?      _age;
  String?   _vehicleType;
  DateTime? _licenseExpiryDate; // TC-RID-014

  // address
  List<_PsgcItem> _provinces      = [];
  List<_PsgcItem> _municipalities = [];
  List<_PsgcItem> _barangays      = [];
  _PsgcItem? _province;
  _PsgcItem? _municipality;
  _PsgcItem? _barangay;
  bool _loadingProv = true, _loadingMuni = false, _loadingBrgy = false;

  // files
  File?   _validId;   String? _validIdName;
  File?   _orCr;      String? _orCrName;

  bool    _ob1 = true, _ob2 = true;
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

  @override
  void initState() { super.initState(); _loadProvinces(); }

  @override
  void dispose() {
    for (final c in [_ln,_fn,_mi,_email,_contact,_licenseNo,_licenseExpiry,_plate,_street,_houseNo,_pw,_cpw,_birthdayCtrl,_ageCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── PSGC ────────────────────────────────────────────────────────────────
  Future<void> _loadProvinces() async {
    try {
      final r = await http.get(Uri.parse('https://psgc.gitlab.io/api/provinces/'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final list = await compute(_parsePsgc, r.body);
        if (mounted) setState(() { _provinces = list; _loadingProv = false; });
      } else {
        if (mounted) setState(() => _loadingProv = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProv = false);
    }
  }

  Future<void> _loadMuni(String code) async {
    setState(() { _loadingMuni = true; _municipalities = []; _barangays = [];
                  _municipality = null; _barangay = null; });
    try {
      final r = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/provinces/$code/cities-municipalities/'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final list = await compute(_parsePsgc, r.body);
        if (mounted) setState(() { _municipalities = list; _loadingMuni = false; });
      } else {
        if (mounted) setState(() => _loadingMuni = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMuni = false);
    }
  }

  Future<void> _loadBrgy(String code) async {
    setState(() { _loadingBrgy = true; _barangays = []; _barangay = null; });
    try {
      final r = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/cities-municipalities/$code/barangays/'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final list = await compute(_parsePsgc, r.body);
        if (mounted) setState(() { _barangays = list; _loadingBrgy = false; });
      } else {
        if (mounted) setState(() => _loadingBrgy = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBrgy = false);
    }
  }

  void _calcAge(DateTime bd) {
    final today = DateTime.now();
    int age = today.year - bd.year;
    if (today.month < bd.month || (today.month == bd.month && today.day < bd.day)) age--;
    final computed = age > 0 ? age : 0;
    setState(() => _age = computed);
    _ageCtrl.text = computed.toString();
  }

  Future<void> _pickFile(bool isValidId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final pf   = result.files.first;
    final path = pf.path;
    if (path == null) return;

    // TC-RID-018: 5 MB size limit (5 × 1024 × 1024 bytes)
    final sizeBytes = await File(path).length();
    if (sizeBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('File is too large. Maximum size is 5 MB.'),
        backgroundColor: Color(0xFFDC2626),
      ));
      return;
    }

    setState(() {
      if (isValidId) { _validId = File(path); _validIdName = pf.name; }
      else           { _orCr   = File(path); _orCrName    = pf.name; }
    });
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;

    // TC-RID-016: both document uploads are required
    if (_validId == null) {
      setState(() => _error = 'Please upload your Driver\'s License / Valid ID.');
      return;
    }
    if (_orCr == null) {
      setState(() => _error = 'Please upload your Vehicle OR/CR.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final bdStr = _birthday == null ? null
          : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2,'0')}-${_birthday!.day.toString().padLeft(2,'0')}';
      final dobStr = bdStr ?? '';
      final expiryStr = _licenseExpiryDate == null ? ''
          : '${_licenseExpiryDate!.year}-${_licenseExpiryDate!.month.toString().padLeft(2,'0')}-${_licenseExpiryDate!.day.toString().padLeft(2,'0')}';

      await AuthService.registerCourier(
        firstName: _fn.text.trim(), lastName: _ln.text.trim(),
        middleInitial: _mi.text.trim().isEmpty ? null : _mi.text.trim(),
        sex: _sex, birthday: bdStr, age: _age,
        email: _email.text.trim(),
        mobileNumber: _contact.text.trim(),
        driverLicenseNumber: _licenseNo.text.trim().toUpperCase(),
        licenseExpiryDate: expiryStr,
        dateOfBirth: dobStr,
        contactNo: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        province: _province?.name, municipality: _municipality?.name,
        barangay: _barangay?.name,
        street: _street.text.trim().isEmpty ? null : _street.text.trim(),
        houseNo: _houseNo.text.trim().isEmpty ? null : _houseNo.text.trim(),
        vehicleType: _vehicleType ?? '',
        plateNumber: _plate.text.trim().toUpperCase(),
        password: _pw.text, passwordConfirmation: _cpw.text,
        validId: _validId, orCr: _orCr,
      );
      if (!mounted) return;
      _showSuccess();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60,
          decoration: const BoxDecoration(color: Color(0xFFFAEEE6), shape: BoxShape.circle),
          child: const Icon(Icons.motorcycle, size: 32, color: Color(0xFFA1552F))),
        const SizedBox(height: 14),
        const Text('Registration Submitted!',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0E2A38))),
        const SizedBox(height: 8),
        const Text('Your rider account is pending admin approval.\nYou will be notified via email.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ]),
      actions: [TextButton(
        onPressed: () { Navigator.pop(context); Navigator.pop(context); },
        child: const Text('Go to Login',
            style: TextStyle(color: Color(0xFF1F5F66), fontWeight: FontWeight.w700)),
      )],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F6F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1, shadowColor: Colors.black12,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 31, height: 31,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.1),
              children: [
                TextSpan(text: 'Taptap', style: TextStyle(color: Color(0xFF0E2A38))),
                TextSpan(text: 'Go', style: TextStyle(color: Color(0xFF2E7C82), fontStyle: FontStyle.italic)),
              ],
            )),
            Text('Rider App', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2E7C82), height: 1.1)),
          ]),
        ]),
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
        _footer(),
      ]),
    );
  }

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      color: Color(0xFFF5F6F4),
      border: Border(top: BorderSide(color: Color(0xFFE8EAE9))),
    ),
    child: const Text('© 2026 TaptapGo. All rights reserved.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xFFADB5B4))),
  );

  Widget _card() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F1EF)),
      boxShadow: const [BoxShadow(color: Color(0x160E2A38), blurRadius: 40, offset: Offset(0,16))],
    ),
    padding: const EdgeInsets.all(28),
    child: Form(
      key: _fk,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // header — orange/brown courier accent
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.motorcycle, size: 22, color: Colors.white)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rider Registration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0E2A38)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Create your TaptapGo rider account',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 24),

        if (_error != null) ...[_errorBanner(), const SizedBox(height: 16)],

        // row 1: first / last / mi
        _row3(
          _txt(
            label: 'First Name', ctrl: _fn, required: true, hint: 'First name',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 2) return 'At least 2 characters';
              if (v.trim().length > 50) return 'Max 50 characters';
              if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿÑñ\s'\-\.]+$").hasMatch(v.trim())) {
                return 'Letters only';
              }
              return null;
            },
          ),
          _txt(
            label: 'Last Name', ctrl: _ln, required: true, hint: 'Last name',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 2) return 'At least 2 characters';
              if (v.trim().length > 50) return 'Max 50 characters';
              if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿÑñ\s'\-\.]+$").hasMatch(v.trim())) {
                return 'Letters only';
              }
              return null;
            },
          ),
          _txt(label: 'Middle Initial', ctrl: _mi, hint: 'M.I.',
              formatters: [LengthLimitingTextInputFormatter(2)]),
        ),
        const SizedBox(height: 14),

        // row 2: sex / birthday / age
        _row3(_sexDd(), _birthdayField(), _ageField()),
        const SizedBox(height: 14),

        // row 3: email / contact (Contact No. also serves as mobile number)
        _row2(
          _txt(label: 'Email', ctrl: _email, hint: 'Email address',
              kb: TextInputType.emailAddress,
              prefix: const Icon(Icons.email_outlined, size: 15, color: Color(0xFF2E7C82)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                // TC-RID-007: proper email format check
                final email = v.trim();
                if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              }),
          _txt(label: 'Contact No.', ctrl: _contact, required: true,
              hint: '09XXXXXXXXX', kb: TextInputType.phone,
              prefix: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF2E7C82)),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!RegExp(r'^09\d{9}$').hasMatch(v.trim())) {
                  return 'Must be 11 digits starting with 09';
                }
                return null;
              }),
        ),
        const SizedBox(height: 14),

        // row 4: driver's license number + expiry (TC-RID-012 to TC-RID-014)
        _row2(
          _txt(
            label: "Driver's License No.", ctrl: _licenseNo, required: true,
            hint: 'A00-00-000000',
            prefix: const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF2E7C82)),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!RegExp(r'^[A-Za-z]\d{2}-\d{2}-\d{6}$').hasMatch(v.trim())) {
                return 'Format: A00-00-000000';
              }
              return null;
            },
          ),
          _licenseExpiryField(),
        ),
        const SizedBox(height: 14),

        // address
        const Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2E7C82)),
          SizedBox(width: 6),
          Text('Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F5F66))),
        ]),
        const SizedBox(height: 10),
        _row3(
          _psgcDd(label: 'Province',     loading: _loadingProv, items: _provinces,     value: _province,     hint: 'Select Province',     onChanged: (v) { setState(() => _province = v); if (v != null) _loadMuni(v.code); }),
          _psgcDd(label: 'Municipality', loading: _loadingMuni, items: _municipalities, value: _municipality, hint: 'Select Municipality', onChanged: (v) { setState(() => _municipality = v); if (v != null) _loadBrgy(v.code); }),
          _psgcDd(label: 'Barangay',     loading: _loadingBrgy, items: _barangays,     value: _barangay,     hint: 'Select Barangay',     onChanged: (v) => setState(() => _barangay = v)),
        ),
        const SizedBox(height: 12),
        _row2(
          _txt(label: 'Street',         ctrl: _street,  hint: 'Street name'),
          _txt(label: 'House No./Unit', ctrl: _houseNo, hint: 'House/Unit number'),
        ),
        const SizedBox(height: 14),

        // vehicle info box — courier orange accent
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEE6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECCBB8)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.motorcycle, size: 15, color: Color(0xFFA1552F)),
              SizedBox(width: 6),
              Text('Vehicle Information',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFA1552F))),
            ]),
            const SizedBox(height: 14),
            _row2(
              _vehicleTypeDd(),
              _txt(label: 'Plate Number', ctrl: _plate, required: true, hint: 'e.g. ABC 1234'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // password rules hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF8F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB4DEDB)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, size: 15, color: Color(0xFF2E7C82)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Password must have at least 8 characters with uppercase, lowercase, number and special character.',
              style: TextStyle(fontSize: 11, color: Color(0xFF1F5F66)),
            )),
          ]),
        ),
        const SizedBox(height: 10),

        // password row
        _row2(
          _pwField(label: 'Password',         ctrl: _pw,  obscure: _ob1, toggle: () => setState(() => _ob1 = !_ob1),
              hint: 'Create password (min 8 characters)',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Password must be at least 8 characters.';
                if (!v.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter.';
                if (!v.contains(RegExp(r'[a-z]'))) return 'Password must contain at least one lowercase letter.';
                if (!v.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number.';
                if (!v.contains(RegExp(r'[\W_]'))) return 'Password must contain at least one special character.';
                return null;
              }),
          _pwField(label: 'Confirm Password', ctrl: _cpw, obscure: _ob2, toggle: () => setState(() => _ob2 = !_ob2),
              hint: 'Confirm password',
              validator: (v) => v != _pw.text ? 'Passwords do not match' : null),
        ),
        const SizedBox(height: 14),

        // uploads row
        _row2(
          _filePicker(label: 'Upload Valid ID / Driver\'s License', required: true, fileName: _validIdName, onTap: () => _pickFile(true)),
          _filePicker(label: 'Upload OR/CR', required: true, fileName: _orCrName, onTap: () => _pickFile(false)),
        ),
        const SizedBox(height: 14),

        _noticeBanner(),
        const SizedBox(height: 20),

        _SubmitButton(loading: _loading, onPressed: _submit),
        const SizedBox(height: 18),

        const Row(children: [
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 1))),
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ]),
        const SizedBox(height: 14),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Already have an account? ', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('Login here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F5F66)))),
        ]),
      ]),
    ),
  );

  // ── layout helpers ────────────────────────────────────────────────────────
  Widget _row3(Widget a, Widget b, Widget c) => LayoutBuilder(
    builder: (_, cs) => cs.maxWidth >= 500
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b), const SizedBox(width: 10), Expanded(child: c)])
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b, const SizedBox(height: 12), c]),
  );

  Widget _row2(Widget a, Widget b) => LayoutBuilder(
    builder: (_, cs) => cs.maxWidth >= 400
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)])
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b]),
  );

  // ── fields ────────────────────────────────────────────────────────────────
  Widget _txt({required String label, required TextEditingController ctrl,
    bool required = false, String? hint, TextInputType kb = TextInputType.text,
    List<TextInputFormatter>? formatters, Widget? prefix, String? Function(String?)? validator}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label, required: required, prefix: prefix),
      const SizedBox(height: 5),
      TextFormField(controller: ctrl, keyboardType: kb, inputFormatters: formatters,
        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        decoration: _deco(hint ?? label),
        validator: validator ?? (required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null)),
    ]);

  Widget _pwField({required String label, required TextEditingController ctrl,
    required bool obscure, required VoidCallback toggle, String? hint, String? Function(String?)? validator}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label, required: true, prefix: const Icon(Icons.lock_outline, size: 15, color: Color(0xFF2E7C82))),
      const SizedBox(height: 5),
      TextFormField(controller: ctrl, obscureText: obscure,
        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        decoration: _deco(hint ?? label).copyWith(
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: const Color(0xFF9AA5A4)),
            onPressed: toggle)),
        validator: validator),
    ]);

  Widget _sexDd() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Sex', required: true),
    const SizedBox(height: 5),
    DropdownButtonFormField<String>(
      initialValue: _sex,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: _deco('Select'),
      hint: const Text('Select', style: TextStyle(fontSize: 13, color: Color(0xFF9AA5A4))),
      items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
      onChanged: (v) => setState(() => _sex = v),
      validator: (v) => v == null ? 'Required' : null,
    ),
  ]);

  Widget _vehicleTypeDd() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Vehicle Type', required: true),
    const SizedBox(height: 5),
    DropdownButtonFormField<String>(
      initialValue: _vehicleType,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: _deco('Select Vehicle'),
      hint: const Text('Select Vehicle', style: TextStyle(fontSize: 13, color: Color(0xFF9AA5A4))),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
        DropdownMenuItem(value: 'Bicycle',    child: Text('Bicycle')),
        DropdownMenuItem(value: 'Scooter',    child: Text('Scooter')),
        DropdownMenuItem(value: 'Car',        child: Text('Car')),
        DropdownMenuItem(value: 'Van',        child: Text('Van')),
      ],
      onChanged: (v) => setState(() => _vehicleType = v),
      validator: (v) => v == null ? 'Required' : null,
    ),
  ]);

  Widget _birthdayField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Birthday', required: true),
    const SizedBox(height: 5),
    TextFormField(
      readOnly: true,
      controller: _birthdayCtrl,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: _deco('mm/dd/yyyy').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9AA5A4))),
      onTap: () async {
        final p = await showDatePicker(context: context,
          initialDate: _birthday ?? DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2E7C82))), child: child!));
        if (p != null) {
          _birthdayCtrl.text = '${p.month.toString().padLeft(2,'0')}/${p.day.toString().padLeft(2,'0')}/${p.year}';
          setState(() => _birthday = p);
          _calcAge(p);
        }
      },
      validator: (_) {
        if (_birthday == null) return 'Required';
        // TC-RID-006: rider must be at least 18 years old
        final today = DateTime.now();
        int age = today.year - _birthday!.year;
        if (today.month < _birthday!.month ||
            (today.month == _birthday!.month && today.day < _birthday!.day)) {
          age--;
        }
        if (age < 18) return 'Rider must be at least 18 years old.';
        return null;
      },
    ),
  ]);

  Widget _ageField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Age'),
    const SizedBox(height: 5),
    TextFormField(readOnly: true,
      controller: _ageCtrl,
      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      decoration: _deco('Auto').copyWith(filled: true, fillColor: const Color(0xFFF9FAFB))),
  ]);

  // TC-RID-014: license expiry — today or future
  Widget _licenseExpiryField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl("License Expiry Date", required: true),
    const SizedBox(height: 5),
    TextFormField(
      readOnly: true,
      controller: _licenseExpiry,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: _deco('mm/dd/yyyy').copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9AA5A4))),
      onTap: () async {
        final today = DateTime.now();
        final p = await showDatePicker(
          context: context,
          initialDate: _licenseExpiryDate ?? today,
          firstDate: today, // TC-RID-014: cannot pick expired date
          lastDate: DateTime(today.year + 20),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xFF2E7C82))),
            child: child!),
        );
        if (p != null) {
          _licenseExpiry.text =
              '${p.month.toString().padLeft(2,'0')}/${p.day.toString().padLeft(2,'0')}/${p.year}';
          setState(() => _licenseExpiryDate = p);
        }
      },
      validator: (_) => _licenseExpiryDate == null ? 'Required' : null,
    ),
  ]);

  Widget _psgcDd({required String label, required bool loading, required List<_PsgcItem> items,
    required _PsgcItem? value, required String hint, required void Function(_PsgcItem?) onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label, required: true, small: true),
      const SizedBox(height: 5),
      loading
        ? _loadingField()
        : DropdownButtonFormField<_PsgcItem>(
            initialValue: value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            decoration: _deco(hint),
            hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA5A4))),
            isExpanded: true,
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.name, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
    ]);

  Widget _filePicker({required String label, required bool required, String? fileName, required VoidCallback onTap}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.credit_card_outlined, size: 15, color: Color(0xFF2E7C82)),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)))),
        if (required) const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFB),
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD1D5DB))),
              child: const Text('Choose File', style: TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500))),
            const SizedBox(width: 10),
            Expanded(child: Text(fileName ?? 'No file chosen',
                style: TextStyle(fontSize: 12, color: fileName != null ? const Color(0xFF374151) : const Color(0xFF9AA5A4)),
                overflow: TextOverflow.ellipsis)),
            if (fileName != null)
              const Icon(Icons.check_circle, size: 15, color: Color(0xFF2E7C82)),
          ]),
        ),
      ),
      const SizedBox(height: 3),
      const Text('JPG, PNG, PDF. Max 5 MB.', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
    ]);

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 17),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
      GestureDetector(onTap: () => setState(() => _error = null), child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 15)),
    ]),
  );

  Widget _noticeBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFEEF8F7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB4DEDB))),
    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 16, color: Color(0xFF2E7C82)),
      SizedBox(width: 8),
      Expanded(child: Text('After submitting, please wait for the administrator\'s approval. You will be notified via email.',
          style: TextStyle(fontSize: 12, color: Color(0xFF1F5F66)))),
    ]),
  );

  Widget _loadingField() => Container(height: 44,
    decoration: BoxDecoration(color: const Color(0xFFFBFCFB), border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(9)),
    child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7C82)))));

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
    filled: true, fillColor: const Color(0xFFFBFCFB), isDense: true,
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
      Text(text, style: TextStyle(fontSize: small ? 11 : 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
      if (required) const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
    ]);
}

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
        gradient: const LinearGradient(colors: [Color(0xFF0E2A38), Color(0xFF4A949C)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x300E2A38), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: loading
        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.send, color: Colors.white, size: 17), SizedBox(width: 8),
            Text('SUBMIT REGISTRATION', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ]),
    ),
  );
}
