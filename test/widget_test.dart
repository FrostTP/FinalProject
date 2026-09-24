import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectapp/config/app_theme.dart';
import 'package:projectapp/screens/login_screen.dart';
import 'package:projectapp/services/api_service.dart';
import 'package:projectapp/services/auth_service.dart';

void main() {
  testWidgets('Mobile login offers Google without staff login controls', (
    tester,
  ) async {
    final api = ApiService();
    final auth = AuthService(api);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(auth: auth),
      ),
    );
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Backoffice'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(auth.employee, isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.client.close();
  });
}
