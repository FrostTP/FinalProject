import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;
  String? error;

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.auth.googleLogin();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.face_retouching_natural,
                  size: 84,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'TimeGuard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const Text('ทุกเวลางาน ยืนยันได้', textAlign: TextAlign.center),
                const SizedBox(height: 40),
                const Text(
                  'ยินดีต้อนรับ',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'เข้าสู่ระบบพนักงานด้วยบัญชี Google ที่ลงทะเบียนกับ HR',
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : login,
                  icon: const Icon(Icons.login),
                  label: Text(
                    busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบด้วย Google',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
