import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projectapp/config/app_theme.dart';
import 'package:projectapp/models/models.dart';
import 'package:projectapp/screens/home_screen.dart';
import 'package:projectapp/services/api_service.dart';
import 'package:projectapp/services/auth_service.dart';
import 'package:projectapp/services/timeguard_service.dart';

void main() {
  testWidgets('Dashboard renders empty API state on a narrow Android display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiService(
      client: MockClient((request) async {
        final dynamic data = request.url.path.endsWith('summary.php')
            ? {'present': 0, 'late': 0, 'absent': null}
            : [];
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );
    final auth = AuthService(api)
      ..employee = SessionUser.fromJson({
        'id': 'E0001',
        'role': 'employee',
        'profile': {
          'employee_id': 'E0001',
          'full_name': 'พนักงานตัวอย่าง',
          'email': 'employee@test.com',
          'department_id': 'D0001',
        },
      });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('th'),
        supportedLocales: const [Locale('th')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: HomeScreen(
            auth: auth,
            data: TimeGuardService(api),
            onNotifications: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ลงเวลาเข้างาน'), findsOneWidget);
    expect(find.text('แผนกยังไม่ได้กำหนดพื้นที่ปฏิบัติงาน'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.client.close();
  });
}
