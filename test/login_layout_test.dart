import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/screens/auth/login_screen.dart';

void main() {
  testWidgets('the login screen fits a small phone (320 dp wide) at full text size', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320 * 2, 720 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
  });
}
