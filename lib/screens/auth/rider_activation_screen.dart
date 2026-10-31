import 'package:flutter/material.dart';
import '../../core/services/courier_service.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/grad_button.dart';

/// Rider account activation screen.
///
/// Opened when the rider taps the activation link in their email.
/// The token is passed as a route argument.
///
/// TC-RID-020: valid activation → password saved, redirect to login
/// TC-RID-021: password complexity enforcement (UI + backend)
/// TC-RID-022: password confirmation mismatch
/// TC-RID-023: expired token → show error, offer resend
/// TC-RID-025: already-used token → show error
/// TC-RID-026: after activation rider can log in (handled by login screen)
class RiderActivationScreen extends StatefulWidget {
  final String token;
  const RiderActivationScreen({super.key, required this.token});

  @override
  State<RiderActivationScreen> createState() => _RiderActivationScreenState();
}

class _RiderActivationScreenState extends State<RiderActivationScreen> {
  // ── form ──────────────────────────────────────────────────────────────────
  final _fk  = GlobalKey<FormState>();
  final _pw  = TextEditingController();
  final _cpw = TextEditingController();
  bool _ob1  = true, _ob2 = true;

  // ── page state ────────────────────────────────────────────────────────────
  bool   _loadingInfo = true;
  bool   _submitting  = false;
  String? _tokenError;      // set when token is invalid/expired/used
  String? _submitError;
  String? _riderName;
  String? _logisticsName;

  // ── resend state ──────────────────────────────────────────────────────────
  String? _riderEmail;
  bool    _resending    = false;
  String? _resendResult;

  // ── cached border shapes (TC-RID-021 validation fields) ───────────────────
  static final _borderDefault  = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD1D5DB)));
  static final _borderFocused  = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF2E7C82), width: 1.5));
  static final _borderError    = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDC2626)));
  static final _borderErrFocus = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5));

  @override
  void initState() {
    super.initState();
    _verifyToken();
  }

  @override
  void dispose() {
    _pw.dispose();
    _cpw.dispose();
    super.dispose();
  }

  // ── verify token on load ──────────────────────────────────────────────────
  Future<void> _verifyToken() async {
    setState(() { _loadingInfo = true; _tokenError = null; });
    try {
      final info = await CourierService.activationInfo(widget.token);
      if (mounted) {
        setState(() {
          _riderName     = info['rider_name'] as String?;
          _logisticsName = info['logistics_name'] as String?;
          _riderEmail    = info['email'] as String?;
          _loadingInfo   = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _tokenError = e.message; _loadingInfo = false; });
    } catch (_) {
      if (mounted) setState(() { _tokenError = 'Unable to verify activation link.'; _loadingInfo = false; });
    }
  }

  // ── submit activation ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _submitting = true; _submitError = null; });
    try {
      await CourierService.activate(
        token:                widget.token,
        password:             _pw.text,
        passwordConfirmation: _cpw.text,
      );
      if (!mounted) return;
      _showSuccess();
    } on ApiError catch (e) {
      if (mounted) setState(() { _submitError = e.message; });
    } catch (_) {
      if (mounted) setState(() { _submitError = 'Activation failed. Please try again.'; });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── resend activation email ───────────────────────────────────────────────
  Future<void> _resend() async {
    if (_riderEmail == null) return;
    setState(() { _resending = true; _resendResult = null; });
    try {
      await CourierService.resendActivation(_riderEmail!);
      if (mounted) setState(() => _resendResult = 'A new activation link has been sent to $_riderEmail.');
    } catch (_) {
      if (mounted) setState(() => _resendResult = 'Failed to resend. Please contact your logistics company.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showSuccess() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: C.b50, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 38, color: C.b700)),
        const SizedBox(height: 14),
        const Text('Account Activated!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: C.textPrimary)),
        const SizedBox(height: 8),
        const Text('Your rider account is now active. You can log in with your email and new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.textSecondary, fontSize: 13)),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // dismiss dialog
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          },
          child: const Text('Go to Login',
              style: TextStyle(color: C.b700, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  // ── build ─────────────────────────────────────────────────────────────────
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
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator(color: C.b600))
          : _tokenError != null
              ? _buildTokenError()
              : _buildForm(),
    );
  }

  // ── token invalid / expired UI ────────────────────────────────────────────
  Widget _buildTokenError() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0F1EF)),
              boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 40, offset: Offset(0, 16))],
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: C.dangerBg, borderRadius: BorderRadius.circular(32)),
                child: const Icon(Icons.link_off, size: 32, color: C.danger)),
              const SizedBox(height: 16),
              const Text('Activation Link Invalid',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 8),
              Text(_tokenError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: C.textSecondary)),
              if (_riderEmail != null) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Need a new link?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary)),
                const SizedBox(height: 8),
                if (_resendResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.b50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.b200)),
                    child: Text(_resendResult!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: C.b700)))
                else
                  GradButton(
                    label: 'Resend Activation Email',
                    icon: Icons.email_outlined,
                    loading: _resending,
                    onPressed: _resend,
                  ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
                child: const Text('Back to Login',
                    style: TextStyle(color: C.b600, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── password setup form ───────────────────────────────────────────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0F1EF)),
              boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 40, offset: Offset(0, 16))],
            ),
            child: Form(
              key: _fk,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Header
                const SizedBox(
                  width: 56, height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: C.b50),
                    child: Icon(Icons.lock_outline, size: 28, color: C.b700),
                  ),
                ),
                const Text('Activate Your Account',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0E2A38))),
                const SizedBox(height: 4),
                if (_riderName != null)
                  Text('Welcome, $_riderName',
                      style: const TextStyle(fontSize: 13, color: C.textSecondary)),
                if (_logisticsName != null)
                  Text(_logisticsName!,
                      style: const TextStyle(fontSize: 12, color: C.b600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Set a password to activate your rider account.',
                    style: TextStyle(fontSize: 13, color: C.textSecondary)),
                const SizedBox(height: 22),

                // Error banner
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: C.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: C.danger, size: 17),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_submitError!,
                          style: const TextStyle(color: C.danger, fontSize: 12))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Password rules hint
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.b50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.b200)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Password must contain:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.b700)),
                    SizedBox(height: 4),
                    Text('• At least 8 characters\n• One uppercase letter (A–Z)\n• One lowercase letter (a–z)\n• One number (0–9)\n• One special character (!@#\$%^&*)',
                        style: TextStyle(fontSize: 11, color: C.textSecondary, height: 1.6)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Password field
                _lbl('Password'),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _pw,
                  obscureText: _ob1,
                  style: const TextStyle(fontSize: 13),
                  decoration: _deco('Create password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_ob1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: const Color(0xFF9AA5A4)),
                      onPressed: () => setState(() => _ob1 = !_ob1))),
                  // TC-RID-021: client-side rule check mirrors backend
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required.';
                    if (v.length < 8) return 'Password must be at least 8 characters.';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter.';
                    if (!v.contains(RegExp(r'[a-z]'))) return 'Password must contain at least one lowercase letter.';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number.';
                    if (!v.contains(RegExp(r'[\W_]'))) return 'Password must contain at least one special character.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                _lbl('Confirm Password'),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _cpw,
                  obscureText: _ob2,
                  style: const TextStyle(fontSize: 13),
                  decoration: _deco('Confirm password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_ob2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: const Color(0xFF9AA5A4)),
                      onPressed: () => setState(() => _ob2 = !_ob2))),
                  // TC-RID-022: password confirmation mismatch
                  validator: (v) => v != _pw.text ? 'Passwords do not match.' : null,
                ),
                const SizedBox(height: 22),

                GradButton(
                  label: 'Activate Account',
                  icon: Icons.check_circle_outline,
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbl(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)));

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
    filled: true, fillColor: const Color(0xFFFBFCFB), isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border:             _borderDefault,
    enabledBorder:      _borderDefault,
    focusedBorder:      _borderFocused,
    errorBorder:        _borderError,
    focusedErrorBorder: _borderErrFocus,
  );
}
