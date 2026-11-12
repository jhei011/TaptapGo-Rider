// TEST-ONLY FAKES: HTTP answers come from a MockClient in this file, shaped like
// origin/production ApiGoogleAuthController (token + user, or 404 'not_found').
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/constants/app_constants.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/screens/auth/login_screen.dart';
import 'package:taptap_go/widgets/google_sign_in_button.dart';

MockClient _server(Map<String, (int, Object)> routes, List<http.Request> log) => MockClient((r) async {
      log.add(r);
      final (status, body) = routes['${r.method} ${r.url.path.replaceFirst('/api', '')}'] ?? (404, {'message': 'Not found'});
      return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    });

Map<String, dynamic> _user(String role, String status) =>
    {'id': 9, 'name': 'Rider', 'email': 'rider@example.test', 'role': role, 'status': status};

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('an approved rider signs in with a Google ID token (POST /api/auth/google)', () async {
    final log = <http.Request>[];
    await http.runWithClient(() async {
      final auth = AuthProvider();
      expect(await auth.googleLogin('google-id-token'), isTrue);
      expect(auth.user!.role, 'courier');
      expect(jsonDecode(log.single.body), {'id_token': 'google-id-token'});
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'tok');
      auth.dispose();
    }, () => _server({'POST /auth/google': (200, {'token': 'tok', 'user': _user('courier', 'approved')})}, log));
  });

  test('a Google email with no rider account is explained, not sent to registration', () async {
    await http.runWithClient(() async {
      final auth = AuthProvider();
      expect(await auth.googleLogin('x'), isFalse);
      expect(auth.error, contains('logistics company creates rider accounts'));
      auth.dispose();
    }, () => _server({'POST /auth/google': (404, {'message': 'not_found'})}, []));
  });

  test('Google sign-in keeps the approval gate: an unapproved rider is refused and its token revoked', () async {
    final log = <http.Request>[];
    await http.runWithClient(() async {
      final auth = AuthProvider();
      expect(await auth.googleLogin('x'), isFalse);
      expect(auth.error, contains('not approved'));
      expect(log.where((r) => r.url.path == '/api/logout'), hasLength(1));
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
      auth.dispose();
    }, () => _server({
          'POST /auth/google': (200, {'token': 'tok', 'user': _user('courier', 'unverified')}),
          'POST /logout': (200, {'message': 'ok'}),
        }, log));
  });

  testWidgets('the login screen shows the real Google button with the official logo (no "coming soon")', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        // The test font draws every glyph as a full square; scale as the other tests do
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: w!,
        ),
        home: const LoginScreen(),
      ),
    ));
    await tester.pump();
    final button = find.byType(GoogleSignInButton);
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.byType(SvgPicture)), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
  });

  testWidgets('the Google button disables itself and shows progress while signing in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GoogleSignInButton(onPressed: null, loading: true))));
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('debug/test builds talk to the local server; release builds default to the live server', () {
    expect(AppConstants.baseUrl, 'http://127.0.0.1:8000');
    expect(AppConstants.liveServer, 'https://taptapshop.store');
    expect(AppConstants.googleServerClientId, endsWith('.apps.googleusercontent.com'));
  });
}
