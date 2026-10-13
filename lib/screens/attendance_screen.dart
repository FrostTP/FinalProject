import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/timeguard_service.dart';
import '../services/attendance_service.dart';
import '../widgets/common.dart';
import '../widgets/area_preview_painter.dart';
import '../widgets/workplace_map.dart';
import '../services/geofence_service.dart';
import '../services/api_service.dart';
import 'outside_work_screen.dart';

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
  AttendanceLocationCheck? location;
  Completer<void>? nextStep;
  int step = 0;
  Uint8List? facePhoto;
  Json? lateContext;
  Completer<Json>? lateStep;
  final lateForm = GlobalKey<FormState>();
  final lateReason = TextEditingController();
  Uint8List? evidencePhoto;
  bool capturingEvidence = false;
  String? evidenceError;
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
      result = null;
      location = null;
      step = 0;
      facePhoto = null;
      lateContext = null;
      evidencePhoto = null;
      evidenceError = null;
      lateReason.clear();
    });
    try {
      result = await AttendanceService(widget.data).submit(
        widget.checkOut,
        (v) {
          if (mounted) {
            setState(() {
              progress = v;
              step = v.startsWith('แนบ') || lateContext != null
                  ? 2
                  : v.startsWith('ถ่าย')
                  ? 1
                  : v.startsWith('กำลังเปรียบเทียบ')
                  ? 1
                  : 0;
            });
          }
        },
        onLate: (preview) async {
          if (!mounted) throw const ApiException('ยกเลิกการลงเวลา');
          lateStep = Completer<Json>();
          setState(() {
            lateContext = preview;
            step = 2;
          });
          final evidence = await lateStep!.future;
          if (!mounted) throw const ApiException('ยกเลิกการลงเวลา');
          return evidence;
        },
        onFaceCaptured: (image) {
          if (mounted) setState(() => facePhoto = base64Decode(image));
        },
        onLocationChecked: (check) async {
          if (!mounted) throw const ApiException('ยกเลิกการลงเวลา');
          setState(() => location = check);
          if (check.inside || check.approvedOffsite) {
            nextStep = Completer<void>();
            await nextStep!.future;
            if (!mounted) throw const ApiException('ยกเลิกการลงเวลา');
          }
        },
      );
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    if (nextStep != null && !nextStep!.isCompleted) nextStep!.complete();
    if (lateStep != null && !lateStep!.isCompleted) {
      lateStep!.completeError(const ApiException('ยกเลิกการลงเวลา'));
    }
    lateReason.dispose();
    super.dispose();
  }

  Widget locationPanel() {
    final check = location;
    final areas = check?.areas ?? <WorkArea>[];
    WorkArea? selected;
    double? distance;
    if (check != null) {
      final matching = areas.where(
        (a) => GeofenceService.contains(
          check.latitude,
          check.longitude,
          a.polygon,
        ),
      );
      final candidates = matching.isNotEmpty ? matching.toList() : areas;
      for (final area in candidates) {
        final d = Geolocator.distanceBetween(
          check.latitude,
          check.longitude,
          area.latitude,
          area.longitude,
        );
        if (distance == null || d < distance) {
          selected = area;
          distance = d;
        }
      }
    }
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    final passed = check != null && (check.inside || check.approvedOffsite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(
            5,
            (i) => i.isOdd
                ? Expanded(
                    child: Container(height: 3, color: const Color(0xFFE0E5ED)),
                  )
                : CircleAvatar(
                    radius: 16,
                    backgroundColor: i ~/ 2 <= step
                        ? const Color(0xFF2F66F6)
                        : const Color(0xFFE0E5ED),
                    child: Text(
                      '${i ~/ 2 + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        color: i ~/ 2 <= step
                            ? Colors.white
                            : const Color(0xFF667085),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          step == 0
              ? 'ตรวจสอบตำแหน่ง GPS'
              : step == 1
              ? 'ยืนยันตัวตนด้วยใบหน้า'
              : 'บันทึกเวลาปฏิบัติงาน',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'ตำแหน่งที่อ่านเมื่อเริ่มลงเวลา • ตรวจขอบเขต Polygon',
          style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: check == null
                ? const ColoredBox(
                    color: Color(0xFFE7F3F8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : WorkplaceMap(
                    areas: areas,
                    latitude: check.latitude,
                    longitude: check.longitude,
                    interactive: true,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            children: [
              row('พื้นที่ปฏิบัติงาน', selected?.name ?? 'กำลังตรวจสอบ'),
              const Divider(height: 1),
              row(
                'ระยะจากจุดกึ่งกลาง',
                distance == null ? '—' : '${distance.round()} เมตร',
              ),
              const Divider(height: 1),
              row('ขอบเขตที่กำหนด', 'Polygon ของแผนก'),
              if (check != null) ...[
                const Divider(height: 1),
                row('ความคลาดเคลื่อน GPS', '${check.accuracy.round()} เมตร'),
              ],
            ],
          ),
        ),
        if (check != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: passed ? const Color(0xFFA7F3D0) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  passed
                      ? Icons.check_circle_outline
                      : Icons.location_off_outlined,
                  color: passed ? const Color(0xFF059669) : Colors.red,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    check.inside
                        ? 'อยู่ในพื้นที่กำหนด'
                        : check.approvedOffsite
                        ? 'มีคำขอนอกพื้นที่ที่อนุมัติแล้ว'
                        : 'อยู่นอกพื้นที่กำหนด',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        if (step == 0 && passed && busy)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: FilledButton(
              onPressed: () {
                if (nextStep != null && !nextStep!.isCompleted) {
                  nextStep!.complete();
                }
              },
              child: const Text('ถัดไป • ยืนยันใบหน้า'),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  bool get outsideBlocked =>
      !busy &&
      error != null &&
      location != null &&
      !location!.inside &&
      !location!.approvedOffsite;

  double? distanceToBoundary(AttendanceLocationCheck check) {
    double? nearest;
    // Local tangent-plane approximation suitable for workplace-sized polygons.
    final longitudeScale = 111320 * math.cos(check.latitude * math.pi / 180);
    Offset point(Coordinate p) => Offset(
      (p.lng - check.longitude) * longitudeScale,
      (p.lat - check.latitude) * 111320,
    );
    for (final area in check.areas) {
      for (var i = 0; i < area.polygon.length; i++) {
        final a = point(area.polygon[i]);
        final b = point(area.polygon[(i + 1) % area.polygon.length]);
        final edge = b - a;
        final lengthSquared = edge.dx * edge.dx + edge.dy * edge.dy;
        final t = lengthSquared == 0
            ? 0.0
            : (-(a.dx * edge.dx + a.dy * edge.dy) / lengthSquared).clamp(
                0.0,
                1.0,
              );
        final distance = (a + edge * t).distance;
        if (nearest == null || distance < nearest) nearest = distance;
      }
    }
    return nearest;
  }

  Widget outsidePage() {
    final check = location!;
    final distance = distanceToBoundary(check);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'อยู่นอกพื้นที่ที่กำหนด',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 35),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCECF3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Container(
                        width: 155,
                        height: 155,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFEF777D),
                            width: 9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: .15),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: AreaPreviewPainter(
                                    check.areas,
                                    check.latitude,
                                    check.longitude,
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                color: const Color(0xFFEF4444),
                                child: const Text(
                                  'OUTSIDE GEOFENCE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 52),
                  const Text(
                    'อยู่นอกพื้นที่ปฏิบัติงาน',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    distance == null
                        ? 'ไม่สามารถคำนวณระยะจากขอบเขตได้'
                        : 'ห่างจากขอบพื้นที่ประมาณ ${distance.round()} เมตร',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFB547)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ต้องอยู่ภายในขอบเขต Polygon ของพื้นที่ที่กำหนด หรือมีคำขอปฏิบัติงานนอกพื้นที่ที่อนุมัติแล้ว',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 58),
                  OutlinedButton(
                    onPressed: run,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF202938),
                      minimumSize: const Size(0, 50),
                      side: const BorderSide(color: Color(0xFFE3EAF4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'ตรวจสอบตำแหน่งอีกครั้ง',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        openPage(context, OutsideWorkScreen(data: widget.data)),
                    child: const Text('ขอปฏิบัติงานนอกพื้นที่'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get faceFailure =>
      !busy &&
      error != null &&
      step > 0 &&
      (error.toString().contains('ใบหน้า') ||
          error.toString().contains('Face Recognition'));

  Widget facePage({required bool failed}) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !busy,
      title: Text(
        failed ? 'สถานะการยืนยันตัวตน' : 'ลงเวลาปฏิบัติงาน',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!failed) ...[
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF12B981),
                  child: Text('1', style: TextStyle(color: Colors.white)),
                ),
                Expanded(
                  child: Container(height: 3, color: const Color(0xFF12B981)),
                ),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF2F66F6),
                  child: Text('2', style: TextStyle(color: Colors.white)),
                ),
                Expanded(
                  child: Container(height: 3, color: const Color(0xFFE0E5ED)),
                ),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE0E5ED),
                  child: Text('3'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'ยืนยันตัวตนด้วยใบหน้า',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              facePhoto == null
                  ? 'มองตรงเข้ากล้องและถ่ายภาพใบหน้าให้ชัดเจน'
                  : 'กำลังเปรียบเทียบภาพกับใบหน้าที่ลงทะเบียนไว้',
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            const SizedBox(height: 26),
            Center(
              child: SizedBox(
                width: 215,
                height: 215,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 198,
                      height: 198,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDCE8FF),
                          width: 7,
                        ),
                      ),
                      child: ClipOval(
                        child: facePhoto == null
                            ? const ColoredBox(
                                color: Color(0xFFEAF1FF),
                                child: Icon(
                                  Icons.face_retouching_natural,
                                  size: 80,
                                  color: Color(0xFF2F66F6),
                                ),
                              )
                            : Image.memory(facePhoto!, fit: BoxFit.cover),
                      ),
                    ),
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF2F66F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.light_mode_outlined, color: Color(0xFF12B981)),
                      SizedBox(height: 8),
                      Text(
                        'ใช้แสงสว่างเพียงพอ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.face_outlined, color: Color(0xFF12B981)),
                      SizedBox(height: 8),
                      Text(
                        'ถอดสิ่งบดบังใบหน้า',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_top, color: Color(0xFFFF922B)),
                      SizedBox(height: 8),
                      Text(
                        'กำลังยืนยันตัวตน',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const FilledButton(
              onPressed: null,
              child: Text('กำลังตรวจสอบ กรุณารอสักครู่'),
            ),
          ] else ...[
            const SizedBox(height: 55),
            Center(
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  size: 36,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              widget.checkOut
                  ? 'ไม่สามารถลงเวลาออกได้'
                  : 'ไม่สามารถลงเวลาเข้าได้',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 25),
            const Panel(
              child: Column(
                children: [
                  Icon(
                    Icons.face_retouching_off,
                    size: 70,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'โปรดตรวจสอบให้แสงสว่างเพียงพอ\nถอดสิ่งบดบังใบหน้า เช่น หมวกหรือแว่นกันแดด\nแล้วลองอีกครั้ง',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667085), height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(onPressed: run, child: const Text('ลองอีกครั้ง')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('กลับไปหน้าหลัก'),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> captureEvidence() async {
    setState(() {
      capturingEvidence = true;
      evidenceError = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 4194304) {
          throw const ApiException('ภาพต้องไม่เกิน 4 MB');
        }
        if (mounted) setState(() => evidencePhoto = bytes);
      }
    } catch (e) {
      if (mounted) setState(() => evidenceError = e.toString());
    } finally {
      if (mounted) setState(() => capturingEvidence = false);
    }
  }

  Widget latePage() {
    final waiting = lateStep != null && !lateStep!.isCompleted;
    final minutes = lateContext!['late_minutes'];
    return PopScope(
      canPop: waiting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ลงเวลาปฏิบัติงาน'),
          automaticallyImplyLeading: waiting,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: lateForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF12B981),
                      child: Text('1', style: TextStyle(color: Colors.white)),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: const Color(0xFF12B981),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF12B981),
                      child: Text('2', style: TextStyle(color: Colors.white)),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: const Color(0xFF12B981),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF2F66F6),
                      child: Text('3', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFFFB547)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ตรวจพบว่าคุณลงเวลาเข้างานสาย $minutes นาที',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'แนบรูปภาพและเหตุผลประกอบ',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'กรุณาถ่ายภาพประกอบและระบุเหตุผล เพื่อให้หัวหน้างานตรวจสอบย้อนหลังได้',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Column(
                    children: [
                      if (evidencePhoto != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            evidencePhoto!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFEAF1FF),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: Color(0xFF2F66F6),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'ถ่ายภาพหลักฐานประกอบ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'เช่น สภาพการจราจร สถานที่ หรือหลักฐานอื่น ๆ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667085),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: waiting && !capturingEvidence
                            ? captureEvidence
                            : null,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: Text(
                          capturingEvidence
                              ? 'กำลังเปิดกล้อง...'
                              : evidencePhoto == null
                              ? 'เปิดกล้อง'
                              : 'ถ่ายใหม่',
                        ),
                      ),
                      if (evidenceError != null)
                        Text(
                          evidenceError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'เหตุผลที่มาสาย',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: lateReason,
                  enabled: waiting,
                  maxLines: 3,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    hintText: 'ระบุเหตุผลที่มาสาย',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุเหตุผล'
                      : null,
                ),
                const SizedBox(height: 8),
                Panel(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('เวลาที่ตรวจสอบ'),
                          const Spacer(),
                          Text(
                            timeText(lateContext!['server_datetime']),
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 25),
                      const Row(
                        children: [
                          Text('สถานะรายการ'),
                          Spacer(),
                          Text(
                            'รอหัวหน้างานตรวจสอบ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2F66F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: waiting && !capturingEvidence
                      ? () {
                          if (!lateForm.currentState!.validate()) return;
                          if (evidencePhoto == null) {
                            setState(
                              () => evidenceError = 'กรุณาถ่ายภาพหลักฐานประกอบ',
                            );
                            return;
                          }
                          setState(
                            () => lateStep!.complete({
                              'reason': lateReason.text.trim(),
                              'evidence_image_base64': base64Encode(
                                evidencePhoto!,
                              ),
                            }),
                          );
                        }
                      : null,
                  child: Text(
                    waiting ? 'ส่งหลักฐานและลงเวลา' : 'กำลังบันทึกเวลา...',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'เวลาลงงานใช้เวลาที่เซิร์ฟเวอร์บันทึกหลังส่งหลักฐาน ไม่ใช่เวลาที่แสดงตอนเริ่มตรวจสอบ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF667085)),
                ),
                if (!waiting)
                  const Padding(
                    padding: EdgeInsets.all(15),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget successPage() {
    final event = result!;
    final date = DateTime.tryParse(event.checkDatetime);
    final matching = location?.areas.where((area) => area.id == event.areaId);
    final areaName = matching != null && matching.isNotEmpty
        ? matching.first.name
        : event.areaId ?? '—';
    final pending = ['pending', 'รออนุมัติ'].contains(event.approvalStatus);
    Widget row(
      String label,
      String value, {
      bool prominent = false,
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: prominent ? 22 : 12,
                fontWeight: FontWeight.w800,
                color: color ?? const Color(0xFF202938),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFECFDF5),
                    border: Border.all(
                      color: const Color(0xFFA7F3D0),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF12B981).withValues(alpha: .08),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    size: 44,
                    color: Color(0xFF12B981),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.checkOut
                    ? 'ลงเวลาออกงานสำเร็จ!'
                    : 'ลงเวลาเข้างานสำเร็จ!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12B981),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pending
                    ? 'บันทึกเวลาแล้ว รอหัวหน้างานตรวจสอบหลักฐาน'
                    : 'บันทึกเวลาปฏิบัติงานของคุณเรียบร้อยแล้ว',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE3EAF4)),
                ),
                child: Column(
                  children: [
                    row(
                      'เวลาที่บันทึก',
                      '${timeText(event.checkDatetime)} น.',
                      prominent: true,
                    ),
                    const Divider(height: 1, color: Color(0xFFE3EAF4)),
                    row(
                      'วันที่',
                      date == null
                          ? event.date
                          : '${DateFormat('EEEE d MMMM', 'th').format(date)} ${date.year + 543}',
                    ),
                    const Divider(height: 1, color: Color(0xFFE3EAF4)),
                    row(
                      'สถานที่ยืนยัน',
                      event.offsiteRequestId == null
                          ? areaName
                          : 'นอกสถานที่ • คำขอที่อนุมัติ',
                    ),
                    const Divider(height: 1, color: Color(0xFFE3EAF4)),
                    row(
                      'วิธีการยืนยันตัวตน',
                      event.verificationMethod == 'face_recognition'
                          ? 'ยืนยันใบหน้า + GPS'
                          : event.verificationMethod,
                      color: const Color(0xFF2F66F6),
                    ),
                    if (pending) ...[
                      const Divider(height: 1, color: Color(0xFFE3EAF4)),
                      row(
                        'สถานะอนุมัติ',
                        'รอหัวหน้างานตรวจสอบ',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: const Color(0xFF2563F6),
                ),
                child: const Text('กลับไปที่หน้าหลัก'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => !busy && result != null
      ? successPage()
      : busy && lateContext != null
      ? latePage()
      : (busy && step > 0) || faceFailure
      ? PopScope(
          canPop: !busy,
          child: facePage(failed: faceFailure),
        )
      : outsideBlocked
      ? outsidePage()
      : PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.checkOut ? 'ลงเวลาออกงาน' : 'ลงเวลาเข้างาน'),
              automaticallyImplyLeading: !busy,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result == null) locationPanel(),
                    if (busy && (location == null || step > 0)) ...[
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
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
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
