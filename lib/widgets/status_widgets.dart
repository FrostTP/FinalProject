import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoadingPanel extends StatelessWidget {
  final String message;
  const LoadingPanel({super.key, this.message = 'กำลังโหลดข้อมูลของคุณ...'});
  Widget skeleton(bool compact) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3EAF4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 13,
          width: compact ? 80 : 130,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 11,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          height: compact ? 18 : 11,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF2563F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'TimeGuard',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202938),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF2563F6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 27),
            skeleton(false),
            skeleton(true),
          ],
        ),
      ),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const ErrorPanel(this.error, this.retry, {super.key});
  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final network = api?.failure == ApiFailure.connection;
    final timeout = api?.failure == ApiFailure.timeout;
    final server = (api?.status ?? 0) >= 500;
    final color = network ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final title = network
        ? 'การเชื่อมต่อขาดหาย'
        : timeout
        ? 'เซิร์ฟเวอร์ตอบสนองช้า'
        : server
        ? 'เกิดข้อผิดพลาด'
        : 'ไม่สามารถดำเนินการได้';
    final message = network
        ? 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต\nแล้วลองอีกครั้ง'
        : server
        ? 'เซิร์ฟเวอร์ขัดข้องชั่วคราว\nกรุณาลองใหม่อีกครั้งในภายหลัง'
        : error.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: network
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFFFFBEB),
              ),
              child: Icon(
                network
                    ? Icons.cloud_off_outlined
                    : server
                    ? Icons.dns_outlined
                    : Icons.error_outline,
                size: 49,
                color: color,
              ),
            ),
            const SizedBox(height: 27),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202938),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFF667085),
              ),
            ),
            if (api?.status != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'รหัสข้อผิดพลาด: ${api!.status}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: retry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563F6),
                ),
                child: const Text('ลองอีกครั้ง'),
              ),
            ),
            if (server)
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('ติดต่อผู้ดูแลระบบ'),
                    content: Text(
                      'กรุณาแจ้ง HR หรือผู้ดูแล TimeGuard ผ่านช่องทางของหน่วยงาน พร้อมรหัสข้อผิดพลาด ${api?.status}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ปิด'),
                      ),
                    ],
                  ),
                ),
                child: const Text('ติดต่อผู้ดูแลระบบ'),
              ),
          ],
        ),
      ),
    );
  }
}
