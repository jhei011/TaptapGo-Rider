import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';


const _kRememberMe = 'remember_me';
const _kSavedEmail  = 'saved_email';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
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
      setState(() { _rememberMe = true; _emailCtrl.text = email; });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
      } else if (role == 'buyer') {
        Navigator.pushReplacementNamed(context, '/buyer');
      } else if (role == 'seller') {
        Navigator.pushReplacementNamed(context, '/seller');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported role. Please use the web panel.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F6F4),
      appBar: _buildAppBar(),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _card(auth),
              ),
            ),
          ),
        ),
        _footer(),
      ]),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 1,
    shadowColor: Colors.black12,
    automaticallyImplyLeading: false,
    titleSpacing: 20,
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          gradient: C.heroGrad,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bilis Hatid',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0E2A38), height: 1.1)),
        Text('Express Inc.',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7C82), height: 1.1)),
      ]),
    ]),
  );

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      color: Color(0xFFF5F6F4),
      border: Border(top: BorderSide(color: Color(0xFFE8EAE9))),
    ),
    child: const Text('© 2026 Bilis Hatid Express Inc. All rights reserved.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xFFADB5B4))),
  );

  Widget _card(AuthProvider auth) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F1EF)),
      boxShadow: const [
        BoxShadow(color: Color(0x18000000), blurRadius: 40, offset: Offset(0, 16)),
        BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    ),
    padding: const EdgeInsets.all(32),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Header — collapses when keyboard is open
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: MediaQuery.of(context).viewInsets.bottom > 0 ? 80.0 : 180.0,
          clipBehavior: Clip.hardEdge,
          curve: Curves.easeInOut,
          decoration: const BoxDecoration(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: C.heroGrad,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.two_wheeler, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 14),
                const Text('Rider Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0E2A38))),
                const SizedBox(height: 4),
                const Text('Sign in to your Bilis Hatid Rider account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Error banner
        if (auth.error != null) ...[
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
              Expanded(child: Text(auth.error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
              GestureDetector(
                onTap: auth.clearError,
                child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 15)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Email
        _fieldLabel('Email Address'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(hint: 'Enter your email', icon: Icons.email_outlined),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@'))       return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password
        _fieldLabel('Password'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _login(),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(hint: 'Enter your password', icon: Icons.lock_outline)
              .copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 19, color: const Color(0xFF9AA5A4)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
        ),
        const SizedBox(height: 14),

        // Remember me + Forgot password
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 18, height: 18,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  activeColor: const Color(0xFF2E7C82),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 7),
              const Text('Remember me',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
            ]),
          ),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Use the web portal to reset your password.'))),
            child: const Text('Forgot password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1F5F66))),
          ),
        ]),
        const SizedBox(height: 22),

        // LOG IN button
        _LoginButton(loading: auth.loading, onPressed: _login),
        const SizedBox(height: 20),

        const Row(children: [
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF), letterSpacing: 1)),
          ),
          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ]),
        const SizedBox(height: 16),

        const Text("Don't have a rider account?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
        const SizedBox(height: 10),

        // Only show Courier / Rider registration
        _roleBtn(
          label: 'Register as Rider',
          icon: Icons.motorcycle,
          bg: const Color(0xFFEEF8F7),
          border: const Color(0xFFB4DEDB),
          color: const Color(0xFF1F5F66),
          onTap: () => Navigator.pushNamed(context, '/register/courier'),
        ),
      ]),
    ),
  );

  Widget _fieldLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)));

  InputDecoration _inputDeco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA5A4), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9AA5A4)),
        filled: true,
        fillColor: const Color(0xFFFBFCFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF2E7C82), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      );

  Widget _roleBtn({
    required String label, required IconData icon,
    required Color bg, required Color border, required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _LoginButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onPressed,
    child: Container(
      height: 46,
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
              Icon(Icons.login, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('LOG IN', style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
    ),
  );
}
