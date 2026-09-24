import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/timeguard_service.dart';
import '../services/attendance_service.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  final TimeGuardService data;
  final bool checkOut;
  const AttendanceScreen({
    super.key,
    required this.data,
    required this.checkOut,
  });
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool busy = true;
  String progress = 'กำลังเริ่มตรวจสอบ';
  Object? error;
  AttendanceEvent? result;
  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      result = await AttendanceService(widget.data).submit(widget.checkOut, (
        v,
      ) {
        if (mounted) {
          setState(() => progress = v);
        }
      });
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.checkOut ? 'ลงเวลาออกงาน' : 'ลงเวลาเข้างาน'),
        automaticallyImplyLeading: !busy,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 28),
                Text(progress, textAlign: TextAlign.center),
              ],
              if (error != null) ...[
                ErrorPanel(error!, run),
                const Text(
                  'หากเครือข่ายขาดขณะบันทึก ให้กลับหน้าหลักเพื่อตรวจสอบเวลาล่าสุดก่อนลองใหม่',
                  textAlign: TextAlign.center,
                ),
              ],
              if (!busy && result != null) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 100,
                  color: Color(0xFF12B981),
                ),
                const SizedBox(height: 24),
                const Text(
                  'บันทึกเวลาสำเร็จ',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  timeText(result!.checkDatetime),
                  style: const TextStyle(fontSize: 40),
                ),
                StatusBadge(result!.approvalStatus),
              ],
              if (!busy) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('กลับหน้าหลัก'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
