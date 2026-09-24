import 'package:flutter/material.dart';
import '../services/timeguard_service.dart';
import '../services/face_service.dart';
import '../widgets/common.dart';

class BiometricScreen extends StatefulWidget {
  final TimeGuardService data;
  const BiometricScreen({super.key, required this.data});
  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  int revision = 0;
  bool busy = false;
  Future<void> register() async {
    setState(() => busy = true);
    try {
      final image = await FaceService().capture();
      await widget.data.registerFace(image);
      if (mounted) {
        setState(() => revision++);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ลงทะเบียนใบหน้า')),
    body: AsyncView(
      key: ValueKey(revision),
      load: widget.data.enrollment,
      builder: (e) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          const Icon(
            Icons.face_retouching_natural,
            size: 110,
            color: Color(0xFF2F66F6),
          ),
          const SizedBox(height: 24),
          Panel(
            child: Column(
              children: [
                const Text(
                  'สถานะการลงทะเบียนใบหน้า',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                StatusBadge(e.status),
                const SizedBox(height: 16),
                const Text(
                  'ถ่ายภาพใบหน้าเดียวให้ชัดเจน ระบบจะเก็บภาพและข้อมูลใบหน้าสำหรับเปรียบเทียบในการลงเวลา โดย HR เป็นผู้ตรวจสอบและอนุมัติ',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: busy || ['pending', 'approved'].contains(e.status)
                ? null
                : register,
            child: Text(
              busy ? 'กำลังตรวจสอบใบหน้า...' : 'ถ่ายภาพและส่งคำขอลงทะเบียน',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'เมื่อ HR อนุมัติแล้ว จึงจะใช้ใบหน้านี้ลงเวลางานได้',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
