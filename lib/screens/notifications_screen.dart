import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final TimeGuardService data;
  const NotificationsScreen({super.key, required this.data});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Notice>> notifications;
  final marking = <int>{};
  static const ink = Color(0xFF202938);
  static const muted = Color(0xFF667085);
  @override
  void initState() {
    super.initState();
    notifications = widget.data.notifications();
  }

  Future<void> refresh() async {
    final request = widget.data.notifications();
    setState(() => notifications = request);
    try {
      await request;
    } catch (_) {
      /* Error displayed by FutureBuilder. */
    }
  }

  Future<void> read(Notice notice) async {
    if (notice.read || marking.contains(notice.id)) return;
    setState(() => marking.add(notice.id));
    try {
      await widget.data.markRead(notice.id);
      if (mounted) await refresh();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => marking.remove(notice.id));
    }
  }

  String dayLabel(DateTime? date) {
    if (date == null) return 'ก่อนหน้านี้';
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'วันนี้';
    if (day == today.subtract(const Duration(days: 1))) return 'เมื่อวาน';
    return '${DateFormat('d MMMM', 'th').format(day)} ${day.year + 543}';
  }

  Widget item(Notice notice) {
    final title = notice.title;
    final (icon, color) = title.contains('สาย')
        ? (Icons.schedule_rounded, const Color(0xFFFF922B))
        : title.contains('ออกงาน')
        ? (Icons.logout_rounded, const Color(0xFFEF4444))
        : title.contains('เข้างาน')
        ? (Icons.login_rounded, const Color(0xFF12B981))
        : title.contains('อนุมัติ')
        ? (Icons.fact_check_outlined, const Color(0xFF2F66F6))
        : (Icons.announcement_rounded, const Color(0xFF2F66F6));
    final date = DateTime.tryParse(notice.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE3EAF4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: marking.contains(notice.id) ? null : () => read(notice),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(icon, size: 23, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: ink,
                          fontWeight: notice.read
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.body,
                        style: const TextStyle(
                          fontSize: 11,
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text(
                      date == null ? '—' : DateFormat('HH:mm').format(date),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                    if (marking.contains(notice.id))
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 9,
                          height: 9,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      )
                    else if (!notice.read)
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2F66F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget empty() => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircleAvatar(
        radius: 54,
        backgroundColor: Color(0xFFECFDF5),
        child: Icon(
          Icons.notifications_none_rounded,
          size: 46,
          color: Color(0xFF12B981),
        ),
      ),
      SizedBox(height: 24),
      Text(
        'ไม่มีการแจ้งเตือนใหม่',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink),
      ),
      SizedBox(height: 10),
      Text(
        'ขณะนี้คุณไม่มีรายการแจ้งเตือน\nรายการจะปรากฏเมื่อระบบมีข้อมูลสำหรับคุณ',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 13, height: 1.6),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Text(
          'การแจ้งเตือน',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Notice>>(
          future: notifications,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingPanel();
            }
            if (snapshot.hasError) {
              return Center(child: ErrorPanel(snapshot.error!, refresh));
            }
            final items = [...snapshot.data!]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final groups = <String, List<Notice>>{};
            for (final notice in items) {
              groups
                  .putIfAbsent(
                    dayLabel(DateTime.tryParse(notice.createdAt)),
                    () => [],
                  )
                  .add(notice);
            }
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
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final group in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 3, 4, 13),
                              child: Text(
                                group.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ),
                            ...group.value.map(item),
                          ],
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
