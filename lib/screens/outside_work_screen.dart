import 'package:flutter/material.dart';
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
  bool busy = false;
  int revision = 0;
  @override
  void dispose() {
    location.dispose();
    reason.dispose();
    super.dispose();
  }

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

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.data.createRequest({
        'work_date_start': DateFormat('yyyy-MM-dd').format(start),
        'work_date_end': DateFormat('yyyy-MM-dd').format(end),
        'location_description': location.text.trim(),
        'reason': reason.text.trim(),
      });
      if (mounted) {
        location.clear();
        reason.clear();
        setState(() => revision++);
        showMessage(context, 'ส่งคำขอเรียบร้อยแล้ว');
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
    appBar: AppBar(title: const Text('ปฏิบัติงานนอกพื้นที่')),
    body: AsyncView(
      key: ValueKey(revision),
      load: () => widget.data.requests(),
      builder: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'สร้างคำขอใหม่',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy ? null : dates,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${DateFormat('dd/MM/yyyy').format(start)} – ${DateFormat('dd/MM/yyyy').format(end)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: location,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'รายละเอียดสถานที่',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'กรอกสถานที่' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reason,
                    maxLength: 255,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'เหตุผล'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'กรอกเหตุผล' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'กำลังส่ง...' : 'ส่งคำขออนุมัติ'),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'คำขอของฉัน',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty) const Panel(child: Text('ยังไม่มีคำขอ')),
          for (final r in items)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.location,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${r.start} – ${r.end}'),
                  StatusBadge(r.status),
                  Text(r.reason),
                  if (r.approvedDate != null)
                    Text('พิจารณาเมื่อ ${r.approvedDate}'),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
