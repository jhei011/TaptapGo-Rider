import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/screens/auth/login_screen.dart';

void main() {
  // TC-RID-029: riders cannot register themselves — the login screen offers no sign-up
  testWidgets('login screen has no rider self-registration link', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          // The test font draws every glyph as a full square, which makes the
          // "Remember me / Forgot password?" row a few pixels too wide for the card.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(0.9)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome, Rider'), findsOneWidget);
    expect(find.textContaining('Register here'), findsNothing);
    expect(find.textContaining("Don't have an account?"), findsNothing);
    expect(
      find.text('New rider? Your logistics company creates your account and '
          'emails you an activation link.'),
      findsOneWidget,
    );
  });
}
