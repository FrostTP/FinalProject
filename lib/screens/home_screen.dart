import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/timeguard_service.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../widgets/common.dart';
import 'attendance_screen.dart';
import 'outside_work_screen.dart';
import 'biometric_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthService auth;
  final TimeGuardService data;
  final VoidCallback onNotifications;
  const HomeScreen({
    super.key,
    required this.auth,
    required this.data,
    required this.onNotifications,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int revision = 0;
  double? latitude, longitude;
  bool locating = false;
  String? locationError;
  Future<(Attendance?, Dashboard, List<WorkArea>, List<Attendance>)>
  load() async {
    final results = await Future.wait<dynamic>([
      widget.data.today(),
      widget.data.summary(),
      widget.data.areas(),
      widget.data.recent(),
    ]);
    return (
      results[0] as Attendance?,
      results[1] as Dashboard,
      results[2] as List<WorkArea>,
      results[3] as List<Attendance>,
    );
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final p = await LocationService().current();
      if (mounted) {
        setState(() {
          latitude = p.latitude;
          longitude = p.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => locationError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Text(widget.auth.employee!.name.characters.first),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('สวัสดี 👋'),
                  Text(
                    widget.auth.employee!.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.auth.employee!.position,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onNotifications,
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
      ),
      Expanded(
        child: AsyncView(
          key: ValueKey(revision),
          load: load,
          builder: (result) {
            final (today, summary, areas, recent) = result;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    children: [
                      const Text(
                        'เวลาทำงานวันนี้',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const ClockWidget(),
                      if (today != null) StatusBadge(today.status),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            'เข้างาน\n${timeText(today?.checkIn)}',
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'ออกงาน\n${timeText(today?.checkOut)}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: today?.checkOut != null
                              ? null
                              : () async {
                                  await openPage(
                                    context,
                                    AttendanceScreen(
                                      data: widget.data,
                                      checkOut: today?.checkIn != null,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() => revision++);
                                  }
                                },
                          icon: const Icon(Icons.face_retouching_natural),
                          label: Text(
                            today?.checkOut != null
                                ? 'ลงเวลาครบแล้ววันนี้'
                                : today?.checkIn != null
                                ? 'ลงเวลาออกงาน'
                                : 'ลงเวลาเข้างาน',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'ภาพรวมเดือนนี้',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    stat('มาทำงาน', summary.present, Colors.green),
                    const SizedBox(width: 8),
                    stat('มาสาย', summary.late, Colors.orange),
                    const SizedBox(width: 8),
                    stat('ขาดงาน', summary.absent, Colors.red),
                  ],
                ),
                const Text(
                  'ยังไม่มีปฏิทินงานสำหรับคำนวณวันขาดงาน',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'พื้นที่ปฏิบัติงาน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (areas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('ไม่พบพื้นที่ปฏิบัติงานที่ได้รับมอบหมาย'),
                        ),
                      for (final a in areas)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(a.name),
                          subtitle: Text(
                            'Polygon ${a.polygon.length} จุด${latitude == null ? '' : '\n${GeofenceService.contains(latitude!, longitude!, a.polygon) ? 'อยู่ภายในพื้นที่' : 'อยู่นอกพื้นที่'}'}',
                          ),
                        ),
                      if (locationError != null)
                        Text(
                          locationError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      TextButton.icon(
                        onPressed: locating ? null : locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          locating
                              ? 'กำลังหาตำแหน่ง...'
                              : 'ตรวจสอบตำแหน่งในพื้นที่',
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => openPage(
                        context,
                        OutsideWorkScreen(data: widget.data),
                      ),
                      icon: const Icon(Icons.business_center_outlined),
                      label: const Text('ขอปฏิบัติงานนอกพื้นที่'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          openPage(context, BiometricScreen(data: widget.data)),
                      icon: const Icon(Icons.face_retouching_natural),
                      label: const Text('ลงทะเบียนใบหน้า'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'กิจกรรมล่าสุด',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Panel(child: Text('ยังไม่มีประวัติการลงเวลา')),
                for (final a in recent) AttendanceTile(a),
              ],
            );
          },
        ),
      ),
    ],
  );
  Widget stat(String label, int? value, Color color) => Expanded(
    child: Panel(
      child: Column(
        children: [
          Text(
            value?.toString() ?? '—',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label),
        ],
      ),
    ),
  );
}

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});
  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return Column(
      children: [
        Text(
          DateFormat('HH:mm:ss').format(now),
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202938),
          ),
        ),
        Text('${DateFormat('d MMMM yyyy', 'th').format(now)} • เวลาไทย'),
      ],
    );
  }
}
