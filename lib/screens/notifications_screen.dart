import 'package:flutter/material.dart';
import '../services/timeguard_service.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final TimeGuardService data;
  const NotificationsScreen({super.key, required this.data});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: const Text('การแจ้งเตือน'),
        automaticallyImplyLeading: false,
      ),
      Expanded(
        child: AsyncView(
          key: ValueKey(revision),
          load: widget.data.notifications,
          builder: (items) => Column(
            children: [
              if (items.isEmpty)
                const Panel(child: Text('ยังไม่มีการแจ้งเตือน')),
              for (final n in items)
                Panel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n.read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: n.read ? Colors.grey : Colors.blue,
                    ),
                    title: Text(n.title),
                    subtitle: Text('${n.body}\n${n.createdAt}'),
                    isThreeLine: true,
                    onTap: () async {
                      try {
                        await widget.data.markRead(n.id);
                        if (mounted) {
                          setState(() => revision++);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, e);
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
