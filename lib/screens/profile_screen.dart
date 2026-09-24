import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';
import 'biometric_screen.dart';
import 'outside_work_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService auth;
  final TimeGuardService data;
  const ProfileScreen({super.key, required this.auth, required this.data});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(text: widget.auth.employee!.name);
  late final phone = TextEditingController(text: widget.auth.employee!.phone);
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
      if (mounted) {
        showMessage(context, 'ดำเนินการเรียบร้อย');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.auth.employee!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'โปรไฟล์',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 44,
            child: Text(
              u.name.characters.first,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(u.email, textAlign: TextAlign.center),
        Text('${u.position} • ${u.role}', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'ชื่อ–นามสกุล'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () => action(
                  () => widget.auth.updateProfile(
                    name.text.trim(),
                    phone.text.trim(),
                  ),
                ),
          child: const Text('บันทึกโปรไฟล์'),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.face_retouching_natural),
          title: const Text('การลงทะเบียนใบหน้า'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openPage(context, BiometricScreen(data: widget.data)),
        ),
        ListTile(
          leading: const Icon(Icons.business_center_outlined),
          title: const Text('คำขอปฏิบัติงานนอกพื้นที่'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openPage(context, OutsideWorkScreen(data: widget.data)),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: busy ? null : () => action(widget.auth.logout),
          icon: const Icon(Icons.logout),
          label: const Text('ออกจากระบบ'),
        ),
      ],
    );
  }
}
