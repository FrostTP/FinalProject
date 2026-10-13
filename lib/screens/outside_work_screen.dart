import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';

class OutsideWorkScreen extends StatefulWidget {
  final TimeGuardService data;
  const OutsideWorkScreen({super.key, required this.data});
  @override
  State<OutsideWorkScreen> createState() => _OutsideWorkScreenState();
}

class _OutsideWorkScreenState extends State<OutsideWorkScreen> {
  final form = GlobalKey<FormState>();
  final location = TextEditingController(), reason = TextEditingController();
  DateTime start = DateTime.now(), end = DateTime.now();
  TimeOfDay departure = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay returning = const TimeOfDay(hour: 16, minute: 30);
  Uint8List? photo;
  bool busy = false, capturing = false;
  int revision = 0;
  bool sent = false;
  String sentLocation = '', sentTime = '', sentDates = '';
  static const muted = Color(0xFF667085);
  static const blue = Color(0xFF2F66F6);
  @override
  void dispose() {
    location.dispose();
    reason.dispose();
    super.dispose();
  }

  String clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  Future<void> dates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (range != null && mounted) {
      setState(() {
        start = range.start;
        end = range.end;
      });
    }
  }

  Future<void> chooseTime(bool leaving) async {
    final time = await showTimePicker(
      context: context,
      initialTime: leaving ? departure : returning,
    );
    if (time != null && mounted) {
      setState(() {
        if (leaving) {
          departure = time;
        } else {
          returning = time;
        }
      });
    }
  }

  Future<void> capture() async {
    setState(() => capturing = true);
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
        if (bytes.length > 4194304) throw Exception('ภาพต้องไม่เกิน 4 MB');
        if (mounted) setState(() => photo = bytes);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (DateUtils.isSameDay(start, end) &&
        returning.hour * 60 + returning.minute <=
            departure.hour * 60 + departure.minute) {
      showMessage(context, 'เวลากลับต้องอยู่หลังเวลาออก');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.data.createRequest({
        'work_date_start': DateFormat('yyyy-MM-dd').format(start),
        'work_date_end': DateFormat('yyyy-MM-dd').format(end),
        'location_description': location.text.trim(),
        'reason': reason.text.trim(),
        'departure_time': clock(departure),
        'return_time': clock(returning),
        if (photo != null) 'evidence_image_base64': base64Encode(photo!),
      });
      if (mounted) {
        sentLocation = location.text.trim();
        sentTime = '${clock(departure)} – ${clock(returning)} น.';
        sentDates =
            '${DateFormat('dd/MM/yyyy').format(start)} – ${DateFormat('dd/MM/yyyy').format(end)}';
        location.clear();
        reason.clear();
        setState(() {
          photo = null;
          revision++;
          sent = true;
        });
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    ),
  );
  InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF4)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF4)),
    ),
    counterText: '',
  );
  Widget timeField(String title, TimeOfDay value, bool leaving) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(title),
        OutlinedButton(
          onPressed: busy ? null : () => chooseTime(leaving),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            alignment: Alignment.centerLeft,
            foregroundColor: const Color(0xFF202938),
            side: const BorderSide(color: Color(0xFFE3EAF4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            '${clock(value)} น.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget sentPage() {
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(width: 16),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    Widget value(String text) => Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: Color(0xFF202938),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE5EDFF),
                    border: Border.all(color: blue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF12B981).withValues(alpha: .09),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    size: 43,
                    color: blue,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'ส่งคำขอสำเร็จ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คำขอปฏิบัติงานนอกสถานที่ถูกส่งแล้ว\nกำลังรอหัวหน้างานพิจารณาอนุมัติ',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE3EAF4)),
                ),
                child: Column(
                  children: [
                    row('สถานที่', value(sentLocation)),
                    row('วันที่ปฏิบัติงาน', value(sentDates)),
                    row('เวลาออก – กลับ', value(sentTime)),
                    row(
                      'สถานะ',
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB547)),
                        ),
                        child: const Text(
                          'รออนุมัติ',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  minimumSize: const Size(0, 52),
                ),
                child: const Text(
                  'กลับไปที่หน้าหลัก',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sent
      ? sentPage()
      : PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'ขอปฏิบัติงานนอกสถานที่',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            body: AsyncView(
              key: ValueKey(revision),
              load: () => widget.data.requests(),
              builder: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'กรอกรายละเอียดการขอปฏิบัติงานนอกพื้นที่\nพร้อมแนบรูปภาพและเหตุผล เพื่อให้หัวหน้างานอนุมัติ',
                    style: TextStyle(fontSize: 13, height: 1.7, color: muted),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        label('สถานที่ / บริษัทที่ไปติดต่อ'),
                        TextFormField(
                          controller: location,
                          enabled: !busy,
                          maxLength: 255,
                          decoration: decoration('เช่น บริษัท เอบีซี จำกัด'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'กรุณาระบุสถานที่'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        label('เหตุผลในการออกปฏิบัติงาน'),
                        TextFormField(
                          controller: reason,
                          enabled: !busy,
                          maxLength: 200,
                          maxLines: 3,
                          decoration: decoration(
                            'เช่น ไปพบลูกค้าเพื่อนำเสนอสินค้า',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'กรุณาระบุเหตุผล'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        label('วันที่ปฏิบัติงาน'),
                        OutlinedButton.icon(
                          onPressed: busy ? null : dates,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            '${DateFormat('dd/MM/yyyy').format(start)} – ${DateFormat('dd/MM/yyyy').format(end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            timeField('เวลาที่ออก', departure, true),
                            const SizedBox(width: 16),
                            timeField('เวลาที่คาดว่าจะกลับ', returning, false),
                          ],
                        ),
                        const SizedBox(height: 18),
                        label('รูปภาพประกอบ (หน้างาน / ใบสั่งงาน) • ถ้ามี'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: const Color(0xFFE3EAF4)),
                          ),
                          child: Column(
                            children: [
                              if (photo != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    photo!,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Color(0xFFEAF1FF),
                                  child: Icon(
                                    Icons.add_a_photo_outlined,
                                    color: blue,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              const Text(
                                'ถ่ายภาพเพื่อแนบไฟล์ประกอบคำขอ',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                              TextButton.icon(
                                onPressed: busy || capturing ? null : capture,
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 17,
                                ),
                                label: Text(
                                  capturing
                                      ? 'กำลังเปิดกล้อง...'
                                      : photo == null
                                      ? 'เปิดกล้อง'
                                      : 'ถ่ายใหม่',
                                ),
                              ),
                              if (photo != null)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() => photo = null),
                                  child: const Text('ลบรูป'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  'คำขอจะส่งให้หัวหน้างานพิจารณาอนุมัติ การลงเวลานอกพื้นที่ต้องมีคำขอที่อนุมัติและอยู่ในช่วงวันที่กำหนด',
                                  style: TextStyle(fontSize: 12, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: busy || capturing ? null : submit,
                          child: Text(busy ? 'กำลังส่งคำขอ...' : 'ส่งคำขอ'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'คำขอของฉัน',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty) const Panel(child: Text('ยังไม่มีคำขอ')),
                  for (final r in items)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.location,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${r.start} – ${r.end}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          StatusBadge(r.status),
                          Text(r.reason, style: const TextStyle(fontSize: 12)),
                          if (r.approvedDate != null)
                            Text(
                              'พิจารณาเมื่อ ${r.approvedDate}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
}
