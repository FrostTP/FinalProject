import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projectapp/services/api_service.dart';

void main() {
  test('Requests include bearer token and preserve Thai JSON', () async {
    final api = ApiService(
      client: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(r.body)['name'], 'ทดสอบ');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'data': {'name': 'ทดสอบ'},
            }),
          ),
          200,
        );
      }),
    )..token = 'test-token';
    expect(
      (await api.post('employee/update_profile.php', {
        'name': 'ทดสอบ',
      }))['name'],
      'ทดสอบ',
    );
    api.client.close();
  });
  test('Malformed server response produces actionable error', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('<html>PHP error</html>', 500),
      ),
    );
    await expectLater(
      api.get('auth/me.php'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('PHP API'),
        ),
      ),
    );
    api.client.close();
  });
  test('API rejection is not mistaken for success', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'duplicate'}),
          409,
        ),
      ),
    );
    await expectLater(
      api.post('attendance/check_in.php'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
    api.client.close();
  });
}
