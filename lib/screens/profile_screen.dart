import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';
import 'biometric_screen.dart';
import 'outside_work_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService auth;
  final TimeGuardService data;
  const ProfileScreen({super.key, required this.auth, required this.data});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Enrollment> enrollment;
  bool busy = false;
  static const ink = Color(0xFF202938);
  static const muted = Color(0xFF667085);
  @override
  void initState() {
    super.initState();
    enrollment = widget.data.enrollment();
  }

  Future<void> biometric() async {
    await openPage(context, BiometricScreen(data: widget.data));
    if (mounted) setState(() => enrollment = widget.data.enrollment());
  }

  Future<void> logout() async {
    setState(() => busy = true);
    try {
      await widget.auth.logout();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(18)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EAF4)),
        ),
        child: child,
      );
  Widget menu(String title, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE3EAF4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Color(0xFF98A2B3),
        ),
        onTap: busy ? null : action,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = widget.auth.employee;
    if (user == null) return const SizedBox.shrink();
    final department =
        user.profile['department_name']?.toString() ?? user.position;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        card(
          Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFE5EDFF),
                child: Text(
                  user.name.characters.firstOrNull ?? 'T',
                  style: const TextStyle(
                    fontSize: 30,
                    color: Color(0xFF2F66F6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user.id} • $department',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              FutureBuilder<Enrollment>(
                future: enrollment,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasError) {
                    return TextButton(
                      onPressed: () =>
                          setState(() => enrollment = widget.data.enrollment()),
                      child: const Text('ตรวจสถานะใบหน้าอีกครั้ง'),
                    );
                  }
                  final status = snapshot.data!.status;
                  final approved = status == 'approved';
                  final color = approved
                      ? const Color(0xFF12B981)
                      : const Color(0xFFF59E0B);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          approved
                              ? Icons.check_circle_outline
                              : Icons.face_outlined,
                          size: 13,
                          color: color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          approved
                              ? 'ใบหน้าได้รับอนุมัติแล้ว'
                              : statusText(status),
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'แผนก',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.phone.isEmpty ? 'ยังไม่ได้ระบุ' : user.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'เบอร์โทร',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(user.email, style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 18),
        const Text(
          'บัญชีของฉัน',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        menu('แก้ไขข้อมูลส่วนตัว', () async {
          await openPage(context, EditProfileScreen(auth: widget.auth));
          if (mounted) setState(() {});
        }),
        menu('ลงทะเบียนใบหน้า', biometric),
        menu(
          'คำขอปฏิบัติงานนอกพื้นที่',
          () => openPage(context, OutsideWorkScreen(data: widget.data)),
        ),
        Material(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            onTap: busy ? null : logout,
            title: Text(
              busy ? 'กำลังออกจากระบบ...' : 'ออกจากระบบ',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
