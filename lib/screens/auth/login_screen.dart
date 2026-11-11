import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

const _kRememberMe = 'remember_me';
const _kSavedEmail = 'saved_email';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final prefs   = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRememberMe) ?? false;
    final email    = prefs.getString(_kSavedEmail) ?? '';
    if (remember && email.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailCtrl.text = email;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showForgotPassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        prefillEmail: _emailCtrl.text.trim(),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_kRememberMe, true);
      await prefs.setString(_kSavedEmail, _emailCtrl.text.trim());
    } else {
      await prefs.setBool(_kRememberMe, false);
      await prefs.remove(_kSavedEmail);
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    if (ok && auth.user != null) {
      final role = auth.user!.role;
      if (role == 'courier') {
        Navigator.pushReplacementNamed(context, '/courier');
      } else if (role == 'linehaul') {
        Navigator.pushReplacementNamed(context, '/linehaul');
      } else if (role == 'buyer') {
        Navigator.pushReplacementNamed(context, '/buyer');
      } else if (role == 'seller') {
        Navigator.pushReplacementNamed(context, '/seller');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unsupported role. Please use the web panel.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      // Dark teal gradient background matching the reference
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2A38), Color(0xFF1B5260), Color(0xFF0E2A38)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _card(auth),
                    ),
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // Top bar — logo image + "TaptapGo" text beside it
  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Image.asset(
              'assets/images/taptapgo_logo_text.png',
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(text: 'Taptap', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Go', style: TextStyle(color: Color(0xFF8FE0D2), fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          '© 2026 TaptapGo. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11, color: Colors.white.withAlpha(100)),
        ),
      );

  Widget _card(AuthProvider auth) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x28000000),
                blurRadius: 40,
                offset: Offset(0, 16)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Header ────────────────────────────────────────────────────
            const Text(
              'Welcome, Rider',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E2A38)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Login to your TaptapGo account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),

            // ── Error banner ───────────────────────────────────────────────
            if (auth.error != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFDC2626), size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(auth.error!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626), fontSize: 12))),
                  GestureDetector(
                      onTap: auth.clearError,
                      child: const Icon(Icons.close,
                          color: Color(0xFFDC2626), size: 15)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Email ──────────────────────────────────────────────────────
            _fieldLabel('Email Address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              decoration: _inputDeco(
                  hint: 'Enter your email', icon: Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password ───────────────────────────────────────────────────
            _fieldLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              decoration:
                  _inputDeco(hint: 'Enter your password', icon: Icons.lock_outline)
                      .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: const Color(0xFF9AA5A4)),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Password is required' : null,
            ),
            const SizedBox(height: 14),

            // ── Remember me + Forgot password ──────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _rememberMe = !_rememberMe),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      activeColor: const Color(0xFF2E7C82),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Remember me',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF4B5563))),
                ]),
              ),
              GestureDetector(
                onTap: () => _showForgotPassword(context),
                child: const Text('Forgot password?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F5F66))),
              ),
            ]),
            const SizedBox(height: 22),

            // ── LOG IN button ──────────────────────────────────────────────
            _LoginButton(loading: auth.loading, onPressed: _login),
            const SizedBox(height: 14),

            // ── Google Sign-In ─────────────────────────────────────────────
            // TODO(OD-07): wire to POST /api/auth/google once backend is ready.
            _GoogleButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Google sign-in coming soon'),
                  duration: Duration(seconds: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── No rider self-registration (TC-RID-029) ────────────────────
            // Riders are added by their logistics company and activate the
            // account from the emailed link.
            const Text(
              'New rider? Your logistics company creates your account and '
              'emails you an activation link.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
          ]),
        ),
      );

  Widget _fieldLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151)));

  InputDecoration _inputDeco(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
        prefixIcon:
            Icon(icon, size: 18, color: const Color(0xFF9AA5A4)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF2E7C82), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      );

}

// ── Forgot Password bottom sheet ─────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordSheet({this.prefillEmail = ''});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.prefillEmail;
    _ctrl.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final err = await auth.forgotPassword(_ctrl.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD1EDE9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7C82), size: 18),
            SizedBox(width: 10),
            Text('We have emailed your password reset link.',
                style: TextStyle(color: Color(0xFF1F5F66), fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
    } else {
      setState(() { _loading = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: Color(0xFF2E7C82)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _formView(),
      ),
    );
  }

  Widget _formView() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Lock icon
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF8F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                color: Color(0xFF2E7C82), size: 26),
          ),
          const SizedBox(height: 16),
          const Text('Forgot Password?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E2A38))),
          const SizedBox(height: 8),
          const Text(
            "No worries! Enter your email and we'll send you a reset link.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                const Row(children: [
                  Icon(Icons.email_outlined, size: 14, color: Color(0xFF4B5563)),
                  SizedBox(width: 5),
                  Text('Email Address',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ctrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle:
                        const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: _error != null
                            ? const BorderSide(color: Color(0xFFDC2626))
                            : const BorderSide(color: Color(0xFFD1D5DB))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF2E7C82), width: 1.5)),
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFDC2626))),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFDC2626), width: 1.5)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                // ── Inline error under field ──────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Send button
          GestureDetector(
            onTap: _loading ? null : _send,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E2A38), Color(0xFF2E7C82)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x300E2A38),
                      blurRadius: 14,
                      offset: Offset(0, 6)),
                ],
              ),
              child: _loading
                  ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5)))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_outlined,
                            color: Colors.white, size: 17),
                        SizedBox(width: 8),
                        Text('SEND RESET LINK',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ],
                    ),
            ),
          ),
        ],
      );
}

// ── Google Sign-In button ─────────────────────────────────────────────────────
class _GoogleButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 50,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF8F8F8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
          boxShadow: _pressed
              ? []
              : [
                  const BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google coloured "G" icon
            SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the official Google "G" logo using canvas arcs — no external asset needed.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawGoogleG(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _LoginButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E2A38), Color(0xFF2E7C82)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x300E2A38),
                  blurRadius: 18,
                  offset: Offset(0, 8)),
            ],
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('LOG IN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0)),
                  ],
                ),
        ),
      );
}

// ── Shared Google G drawing helper ───────────────────────────────────────────
// Draws the real Google G logo as filled pie sectors.
// Used by both TaptapGo and TaptapShop login screens.
void _drawGoogleG(Canvas canvas, Size size) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r  = math.min(cx, cy);
  final inner = r * 0.45;   // inner cutout radius
  final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: r);

  void sector(Color color, double startDeg, double sweepDeg) {
    final start = startDeg * math.pi / 180;
    final sweep = sweepDeg * math.pi / 180;
    final path  = Path()
      ..moveTo(cx, cy)
      ..arcTo(rect, start, sweep, false)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // Four coloured sectors matching the reference image:
  // Red   : top-right going clockwise → bottom  (-23° … 113° sweep)
  // Yellow: bottom-left small wedge            ( 90° …  60° sweep)
  // Green : left wedge                         (150° …  75° sweep)
  // Blue  : top arc (longest)                  (225° … 137° sweep)
  sector(const Color(0xFFEA4335), -23,  113); // red
  sector(const Color(0xFFFBBC05),  90,   60); // yellow
  sector(const Color(0xFF34A853), 150,   75); // green
  sector(const Color(0xFF4285F4), 225,  137); // blue

  // Punch out inner circle → ring shape
  canvas.drawCircle(
    Offset(cx, cy), inner, Paint()..color = Colors.white);

  // Draw horizontal bar of the "G" (blue)
  final barH   = r * 0.30;
  final barTop = cy - barH / 2;
  canvas.drawRect(
    Rect.fromLTRB(cx, barTop, cx + r, barTop + barH),
    Paint()..color = const Color(0xFF4285F4),
  );

  // Re-punch inner circle over the bar so only half-ring remains
  canvas.drawCircle(
    Offset(cx, cy), inner, Paint()..color = Colors.white);
}
