import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "How to Become a Rider" screen
//
// Rider self-registration is intentionally blocked by the backend (TC-RID-029).
// Riders are added by their logistics company, which sends an activation email.
// This screen explains that 3-step process using the same visual shell as the
// TaptapShop Flutter buyer registration (gradient bg, card, stepper).
// ─────────────────────────────────────────────────────────────────────────────

class RegisterCourierScreen extends StatelessWidget {
  const RegisterCourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E2A38), Color(0xFF1B5260), Color(0xFF2E7C82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // ── Decorative circles ─────────────────────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          Positioned.fill(
            child: SafeArea(
              child: Column(children: [
                // ── Pinned header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    // TaptapGo logo box
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withAlpha(40), width: 1),
                      ),
                      child: const Icon(Icons.motorcycle,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    RichText(
                      text: const TextSpan(children: [
                        TextSpan(
                          text: 'Taptap',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Go',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF8FE0D2)),
                        ),
                      ]),
                    ),
                  ]),
                ),

                // ── Scrollable card + footer ───────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 560),
                        child: Column(children: [
                          _card(context),
                          const SizedBox(height: 16),
                          Text(
                            '© 2026 TaptapGo. All rights reserved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withAlpha(110)),
                          ),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F1EF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x160E2A38),
                blurRadius: 40,
                offset: Offset(0, 16)),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.motorcycle,
                  size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Become a Rider',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E2A38))),
                    Text('How rider accounts work on TaptapGo',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ]),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Stepper ───────────────────────────────────────────────────────
          const _RiderStepper(),
          const SizedBox(height: 28),

          // ── Info notice ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF8F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB4DEDB)),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF2E7C82)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rider accounts are created by approved logistics '
                      'partners, not by individual sign-up. Contact your '
                      'logistics company to get started.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF1F5F66)),
                    ),
                  ),
                ]),
          ),
          const SizedBox(height: 22),

          // ── OR divider ────────────────────────────────────────────────────
          const Row(children: [
            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 1)),
            ),
            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          ]),
          const SizedBox(height: 14),

          // ── Back to Login ─────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account? ',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF4B5563))),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Login here',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F5F66))),
            ),
          ]),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Rider process stepper — 3 static steps explaining how accounts are created
// ─────────────────────────────────────────────────────────────────────────────
class _RiderStepper extends StatelessWidget {
  const _RiderStepper();

  static const _steps = [
    _StepData(
      icon: Icons.business_outlined,
      label: 'Logistics Partner',
      title: 'Your company creates your account',
      body:
          'An approved TaptapGo logistics partner registers your rider '
          'profile on the TaptapShop web portal.',
    ),
    _StepData(
      icon: Icons.email_outlined,
      label: 'Activation Email',
      title: 'Check your inbox',
      body:
          'You receive an activation email with a secure link. '
          'Tap the link to open it in TaptapGo.',
    ),
    _StepData(
      icon: Icons.lock_outline,
      label: 'Set Password',
      title: 'Set your password & log in',
      body:
          'Create a strong password to activate your account. '
          'You can then log in and start accepting deliveries.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Step circles + connectors (horizontal row) ───────────────────────
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            return const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 20),
                child: Divider(
                    color: Color(0xFF2E7C82), thickness: 2, height: 2),
              ),
            );
          }
          final idx = i ~/ 2;
          final step = _steps[idx];
          return _StepCircle(index: idx, step: step);
        }),
      ),
      const SizedBox(height: 24),

      // ── Detail cards ─────────────────────────────────────────────────────
      ...List.generate(_steps.length, (i) => _StepCard(
            index: i,
            step: _steps[i],
            isLast: i == _steps.length - 1,
          )),
    ]);
  }
}

class _StepData {
  final IconData icon;
  final String label;
  final String title;
  final String body;
  const _StepData({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
  });
}

class _StepCircle extends StatelessWidget {
  final int index;
  final _StepData step;
  const _StepCircle({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 42, height: 42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x280E2A38),
                blurRadius: 10,
                offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Icon(step.icon, size: 20, color: Colors.white),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: 72,
        child: Text(
          step.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7C82),
              height: 1.3),
        ),
      ),
    ]);
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final _StepData step;
  final bool isLast;
  const _StepCard(
      {required this.index, required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCECEA)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Step number badge
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0E2A38))),
                  const SizedBox(height: 3),
                  Text(step.body,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                          height: 1.5)),
                ]),
          ),
        ]),
      ),
    );
  }
}
