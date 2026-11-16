import 'package:flutter/material.dart';
import '../core/services/api.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_tokens.dart';

/// A "Change password" button for riders (Profile) and linehaul couriers (Home). It opens a
/// sheet with the same rules as the website: the current password, and a new one of at least
/// 8 characters with an uppercase letter, a lowercase letter, a number and a symbol, typed twice.
class ChangePasswordButton extends StatelessWidget {
  const ChangePasswordButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        key: const Key('openChangePassword'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: kSurfaceRaised,
          builder: (_) => const ChangePasswordSheet(),
        ),
        icon: const Icon(Icons.lock_reset, size: 18),
        label: const Text('Change password'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kBrand700,
          side: BorderSide(color: kBrand700.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
        ),
      );
}

/// Why a new password is not allowed (same rules as the server), or null.
String? newPasswordProblem(String value, String current) {
  if (value.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(value) || !RegExp(r'[a-z]').hasMatch(value)) return 'Use both uppercase and lowercase letters.';
  if (!RegExp(r'\d').hasMatch(value)) return 'Add at least one number.';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Add at least one symbol, such as ! or @.';
  if (value == current) return 'Choose a password different from your current one.';
  return null;
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});
  @override State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _show = false;
  String? _error, _done;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _error = null; _done = null; });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final message = await AuthService.changePassword(current: _current.text, password: _password.text, confirmation: _confirm.text);
      _current.clear(); _password.clear(); _confirm.clear();
      if (mounted) setState(() => _done = message);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e is NetworkError ? e.message : 'Could not change the password. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, String? Function(String?) check, Key key) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace12),
        child: TextFormField(
          key: key,
          controller: c,
          obscureText: !_show,
          enableSuggestions: false,
          autocorrect: false,
          validator: check,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
            suffixIcon: IconButton(
              tooltip: _show ? 'Hide passwords' : 'Show passwords',
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 4),
            Text('At least 8 characters, with an uppercase letter, a lowercase letter, a number and a symbol. '
                'You stay signed in here; other phones are signed out.',
                style: TextStyle(fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 16),
            _field('Current password', _current, (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null, const Key('currentPassword')),
            _field('New password', _password, (v) => newPasswordProblem(v ?? '', _current.text), const Key('newPassword')),
            _field('Confirm new password', _confirm, (v) => v != _password.text ? 'The passwords do not match.' : null, const Key('confirmPassword')),
            if (_error != null || _done != null)
              Container(
                key: const Key('passwordResult'),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: kSpace12),
                decoration: BoxDecoration(
                  color: (_error != null ? kDanger : kBrand700).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Text(_error ?? _done!, style: TextStyle(fontSize: 13, color: _error != null ? kDanger : kBrand700)),
              ),
            FilledButton.icon(
              key: const Key('changePasswordButton'),
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kBrand700Fill,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
              ),
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_reset, size: 18),
              label: const Text('Change password'),
            ),
          ]),
        ),
      ),
    );
  }
}
