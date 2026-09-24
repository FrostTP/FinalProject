import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  final TimeGuardService data;
  const HistoryScreen({super.key, required this.data});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime month = DateTime.now();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: const Text('ประวัติการลงเวลา'),
        automaticallyImplyLeading: false,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy', 'th').format(month),
            style: const TextStyle(fontSize: 18),
          ),
          IconButton(
            onPressed: () =>
                setState(() => month = DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      Expanded(
        child: AsyncView(
          key: ValueKey(month),
          load: () => widget.data.history(DateFormat('yyyy-MM').format(month)),
          builder: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                const Panel(child: Text('ไม่มีประวัติการลงเวลาในเดือนนี้')),
              for (final a in items) AttendanceTile(a),
            ],
          ),
        ),
      ),
    ],
  );
}
