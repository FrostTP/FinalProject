import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthService auth;
  const EditProfileScreen({super.key, required this.auth});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.auth.employee!.name);
  late final phone = TextEditingController(text: widget.auth.employee!.phone);
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.auth.updateProfile(name.text.trim(), phone.text.trim());
      if (mounted) {
        showMessage(context, 'บันทึกข้อมูลสำเร็จ');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF667085),
      ),
    ),
  );
  InputDecoration decoration() => InputDecoration(
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF4)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF4)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = widget.auth.employee;
    if (user == null) return const SizedBox.shrink();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'แก้ไขโปรไฟล์',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          automaticallyImplyLeading: !busy,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 15),
                Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFE5EDFF),
                    child: Text(
                      user.name.characters.firstOrNull ?? 'T',
                      style: const TextStyle(
                        fontSize: 32,
                        color: Color(0xFF2F66F6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                label('ชื่อ–นามสกุล'),
                TextFormField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: decoration(),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'กรุณาระบุชื่อ–นามสกุล'
                      : null,
                ),
                const SizedBox(height: 18),
                label('อีเมล'),
                TextFormField(
                  initialValue: user.email,
                  enabled: false,
                  decoration: decoration().copyWith(
                    fillColor: const Color(0xFFE9EDF3),
                  ),
                ),
                const SizedBox(height: 18),
                label('เบอร์โทร'),
                TextFormField(
                  controller: phone,
                  enabled: !busy,
                  maxLength: 15,
                  keyboardType: TextInputType.phone,
                  decoration: decoration(),
                  validator: (v) =>
                      v != null &&
                          v.trim().isNotEmpty &&
                          !RegExp(r'^[0-9+() -]+$').hasMatch(v.trim())
                      ? 'รูปแบบเบอร์โทรไม่ถูกต้อง'
                      : null,
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'กำลังบันทึก...' : 'บันทึก'),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
