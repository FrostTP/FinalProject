import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  final TimeGuardService data;
  final VoidCallback? onHome;
  const HistoryScreen({super.key, required this.data, this.onHome});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;
  DateTimeRange? custom;
  late Future<List<Attendance>> history;
  static const blue = Color(0xFF2563F6);
  static const ink = Color(0xFF202938);
  static const muted = Color(0xFF667085);
  DateTime get today {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    history = load();
  }

  DateTimeRange get range {
    final now = today;
    if (filter == 2 && custom != null) return custom!;
    return DateTimeRange(
      start: filter == 0
          ? now.subtract(Duration(days: now.weekday - 1))
          : DateTime(now.year, now.month),
      end: now,
    );
  }

  Future<List<Attendance>> load() async {
    final selected = range;
    final requests = <Future<List<Attendance>>>[];
    var month = DateTime(selected.start.year, selected.start.month);
    while (!month.isAfter(selected.end)) {
      requests.add(widget.data.history(DateFormat('yyyy-MM').format(month)));
      month = DateTime(month.year, month.month + 1);
    }
    final records = (await Future.wait(requests)).expand((items) => items);
    final start = DateFormat('yyyy-MM-dd').format(selected.start);
    final end = DateFormat('yyyy-MM-dd').format(selected.end);
    return records
        .where(
          (a) => a.date.compareTo(start) >= 0 && a.date.compareTo(end) <= 0,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> select(int index) async {
    if (index == 2) {
      final now = today;
      final chosen = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        initialDateRange: custom ?? DateTimeRange(start: now, end: now),
      );
      if (!mounted || chosen == null) return;
      if (chosen.end.difference(chosen.start).inDays > 366) {
        showMessage(context, 'กรุณาเลือกช่วงไม่เกิน 1 ปี');
        return;
      }
      custom = chosen;
    }
    setState(() {
      filter = index;
      history = load();
    });
  }

  Future<void> refresh() async {
    final request = load();
    setState(() => history = request);
    try {
      await request;
    } catch (_) {
      /* FutureBuilder presents the error. */
    }
  }

  Widget record(Attendance item) {
    final late = item.status == 'late';
    final offsite = item.status == 'approved_outside_area';
    final working = item.checkIn != null && item.checkOut == null;
    final color = late
        ? const Color(0xFFF59E0B)
        : offsite
        ? const Color(0xFF8B5CF6)
        : working
        ? blue
        : const Color(0xFF12B981);
    final status = late
        ? 'มาสาย'
        : offsite
        ? 'นอกสถานที่'
        : working
        ? 'ปฏิบัติงาน'
        : 'ตรงเวลา';
    final date = DateTime.tryParse(item.date);
    final pending = item.events.any(
      (e) => ['pending', 'รออนุมัติ'].contains(e.approvalStatus),
    );
    Widget time(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF98A2B3), size: 18),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: muted)),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date == null
                      ? item.date
                      : DateFormat('EEEE d MMM', 'th').format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withValues(alpha: .5)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              time(Icons.login_rounded, 'เข้า ${timeText(item.checkIn)} น.'),
              time(Icons.logout_rounded, 'ออก ${timeText(item.checkOut)} น.'),
            ],
          ),
          if (pending)
            const Padding(
              padding: EdgeInsets.only(top: 9),
              child: Text(
                'รอหัวหน้างานตรวจสอบ',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget empty() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircleAvatar(
        radius: 55,
        backgroundColor: Color(0xFFEAF1FF),
        child: Icon(Icons.assignment_outlined, size: 48, color: blue),
      ),
      const SizedBox(height: 24),
      const Text(
        'ยังไม่มีประวัติการลงเวลา',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 10),
      const Text(
        'ไม่พบรายการในช่วงวันที่เลือก\nเริ่มลงเวลาเมื่ออยู่ในพื้นที่ปฏิบัติงาน',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onHome,
          style: FilledButton.styleFrom(backgroundColor: blue),
          child: const Text('ไปหน้าหลักเพื่อลงเวลา'),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Text(
          'ประวัติการลงเวลา',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EAF4)),
        ),
        child: Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => select(i),
                  style: TextButton.styleFrom(
                    backgroundColor: filter == i ? blue : Colors.white,
                    foregroundColor: filter == i ? Colors.white : muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text(
                    ['สัปดาห์นี้', 'เดือนนี้', 'กำหนดเอง'][i],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (filter == 2)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '${DateFormat('dd/MM/yyyy').format(range.start)} – ${DateFormat('dd/MM/yyyy').format(range.end)}',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ),
      const SizedBox(height: 14),
      Expanded(
        child: FutureBuilder<List<Attendance>>(
          future: history,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingPanel();
            }
            if (snapshot.hasError) {
              return Center(child: ErrorPanel(snapshot.error!, refresh));
            }
            final items = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                onRefresh: refresh,
                child: items.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: empty(),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) => record(items[index]),
                      ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
