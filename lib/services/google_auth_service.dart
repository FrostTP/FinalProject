import 'package:google_sign_in/google_sign_in.dart';
import '../config/oauth_config.dart';
import 'api_service.dart';

class GoogleAuthService {
  static const clientId = OAuthConfig.googleWebClientId;
  static bool _initialized = false;
  Future<String> idToken() async {
    if (clientId.isEmpty) {
      throw const ApiException('ยังไม่ได้ตั้งค่า GOOGLE_WEB_CLIENT_ID');
    }
    try {
      final google = GoogleSignIn.instance;
      if (!_initialized) {
        await google.initialize(serverClientId: clientId);
        _initialized = true;
      }
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ApiException(
          'Google ไม่ส่ง ID token กรุณาตรวจ OAuth configuration',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      final message = switch (e.code) {
        GoogleSignInExceptionCode.canceled =>
          'Google ไม่ได้ยืนยันการเข้าสู่ระบบ กรุณาลองใหม่และเลือกบัญชีให้เสร็จ',
        GoogleSignInExceptionCode.interrupted =>
          'การเข้าสู่ระบบ Google ถูกขัดจังหวะ กรุณาลองใหม่',
        GoogleSignInExceptionCode.clientConfigurationError =>
          'การตั้งค่า Google OAuth ของแอปไม่ถูกต้อง กรุณาตรวจ Client ID และ Android SHA-1',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'บริการ Google บนอุปกรณ์ยังไม่พร้อม กรุณาตรวจบัญชี Google และ Google Play services',
        GoogleSignInExceptionCode.uiUnavailable =>
          'เปิดหน้าต่างเข้าสู่ระบบ Google ไม่ได้ กรุณาปิดแล้วเปิดแอปใหม่',
        _ => 'เข้าสู่ระบบ Google ไม่สำเร็จ กรุณาลองใหม่',
      };
      throw ApiException('$message (รหัส: ${e.code.name})');
    }
  }
}
