import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'google_auth_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService api;
  SessionUser? employee;
  AuthService(this.api) {
    api.onUnauthorized = () {
      employee = null;
      notifyListeners();
    };
  }
  Future<void> restore() async {
    await api.restore();
    if (api.token != null) {
      try {
        final session = SessionUser.fromJson(await api.get('auth/me.php'));
        if (session.role == 'employee') {
          employee = session;
        } else {
          // Discard a staff session saved by an older mobile version.
          await api.clearToken();
          employee = null;
        }
      } on ApiException catch (e) {
        if (e.status != 401) {
          rethrow;
        }
      }
    }
    notifyListeners();
  }

  Future<void> _accept(dynamic data) async {
    final session = SessionUser.fromJson(data['user']);
    if (session.role != 'employee') {
      throw const ApiException('แอปมือถือรองรับบัญชีพนักงานเท่านั้น');
    }
    await api.saveToken(data['token']);
    employee = session;
    notifyListeners();
  }

  Future<void> googleLogin() async {
    final token = await GoogleAuthService().idToken();
    await _accept(await api.post('auth/google.php', {'id_token': token}));
  }

  Future<void> logout() async {
    await api.post('auth/logout.php');
    await api.clearToken();
    employee = null;
    notifyListeners();
  }

  Future<void> updateProfile(String name, String phone) async {
    employee = SessionUser.fromJson(
      await api.post('employee/update_profile.php', {
        'full_name': name,
        'phone': phone,
      }),
    );
    notifyListeners();
  }
}
