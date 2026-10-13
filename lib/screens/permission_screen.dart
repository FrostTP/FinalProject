import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/common.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const PermissionScreen({super.key, required this.onContinue});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final granted = <Permission, bool>{};
  bool busy = false;
  Future<void> request(Permission permission) async {
    setState(() => busy = true);
    try {
      final result = await permission.request();
      if (mounted) {
        setState(() => granted[permission] = result.isGranted);
        if (result.isPermanentlyDenied) {
          showMessage(context, 'เปิดสิทธิ์ได้จากการตั้งค่าแอป');
        }
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

  Widget tile(
    IconData icon,
    String title,
    String subtitle,
    Permission permission,
  ) => Panel(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        onPressed: busy ? null : () => request(permission),
        icon: Icon(
          granted[permission] == true
              ? Icons.check_circle
              : Icons.add_circle_outline,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('เตรียมพร้อมใช้งาน')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 72,
          color: Color(0xFF2F66F6),
        ),
        const SizedBox(height: 24),
        const Text(
          'สิทธิ์การเข้าถึงที่จำเป็น',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'เพื่อให้ระบบทำงานได้อย่างถูกต้องโปรดอนุญาติสิทธิ์ต่อไปนี้',
        ),
        const SizedBox(height: 28),
        tile(
          Icons.location_on_outlined,
          'ตำแหน่ง GPS',
          'ตรวจสอบว่าคุณอยู่ในพื้นที่ปฏิบัติงาน',
          Permission.locationWhenInUse,
        ),
        tile(
          Icons.camera_alt_outlined,
          'กล้องถ่ายภาพ',
          'ถ่ายภาพใบหน้าเพื่อลงทะเบียนและเปรียบเทียบก่อนลงเวลา',
          Permission.camera,
        ),
        tile(
          Icons.notifications_outlined,
          'การแจ้งเตือน',
          'ดูผลการลงเวลาและประกาศได้ในแอป รุ่นนี้ยังไม่มี Push Notification',
          Permission.notification,
        ),
        TextButton(
          onPressed: openAppSettings,
          child: const Text('เปิดการตั้งค่าแอป'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : widget.onContinue,
          child: const Text('เริ่มต้นใช้งาน'),
        ),
      ],
    ),
  );
}
