import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/timeguard_service.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../services/home_route_observer.dart';
import '../widgets/common.dart';
import '../widgets/workplace_map.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  int revision = 0;
  double? latitude, longitude;
  bool locating = false;
  String? locationError;
  StreamSubscription<Position>? _positions;
  ModalRoute<dynamic>? _route;
  int _locationGeneration = 0;
  bool _foreground = true;
  bool tracking = false;
  DateTime? positionUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _route?.isCurrent == true) locate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      homeRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) homeRouteObserver.subscribe(this, route);
    }
  }

  void stopLocation() {
    _locationGeneration++;
    final subscription = _positions;
    _positions = null;
    unawaited(subscription?.cancel());
    tracking = false;
    locating = false;
  }

  @override
  void didPushNext() {
    stopLocation();
  }

  @override
  void didPopNext() {
    if (_foreground) locate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _route?.isCurrent == true) {
      locate();
    } else {
      stopLocation();
    }
  }

  @override
  void dispose() {
    stopLocation();
    homeRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
    stopLocation();
    final generation = _locationGeneration;
    bool active() =>
        mounted &&
        generation == _locationGeneration &&
        _foreground &&
        _route?.isCurrent == true;
    if (!active()) return;
    setState(() {
      locating = true;
      locationError = null;
      latitude = longitude = null;
      positionUpdated = null;
    });
    try {
      final service = LocationService();
      await service.ensurePermission();
      if (!active()) return;
      _positions = service.watch().listen(
        (p) {
          if (!active()) return;
          setState(() {
            locating = false;
            tracking = true;
            if (p.accuracy > 100) {
              latitude = longitude = null;
              locationError =
                  'GPS คลาดเคลื่อนเกิน 100 เมตร กรุณาไปบริเวณที่โล่ง';
              return;
            }
            locationError = null;
            latitude = p.latitude;
            longitude = p.longitude;
            positionUpdated = DateTime.now();
          });
        },
        onError: (Object error) {
          if (!active()) return;
          stopLocation();
          setState(() {
            latitude = longitude = null;
            locationError = 'ไม่สามารถติดตาม GPS ได้ กรุณาเปิด GPS แล้วลองใหม่';
          });
        },
        onDone: () {
          if (!active()) return;
          stopLocation();
          setState(() {});
        },
      );
    } catch (e) {
      if (active()) {
        setState(() {
          locationError = e.toString();
          locating = false;
        });
      }
    }
  }

  Future<void> showLocationPreview(List<WorkArea> areas) async {
    final lat = latitude, lng = longitude;
    final updated = positionUpdated;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ตำแหน่งที่ทำงาน',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'ลากเพื่อเลื่อนดู • ใช้สองนิ้วเพื่อซูมเข้า–ออก',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: WorkplaceMap(
                    areas: areas,
                    latitude: lat,
                    longitude: lng,
                    interactive: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                updated == null
                    ? 'ยังไม่มีตำแหน่ง GPS'
                    : 'พิกัดเมื่อเปิดภาพ • ${DateFormat('HH:mm:ss').format(updated)}',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView(
                  children: [
                    for (final area in areas)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: blue,
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              area.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (lat != null && lng != null)
                            Text(
                              GeofenceService.contains(lat, lng, area.polygon)
                                  ? 'อยู่ในพื้นที่'
                                  : 'นอกพื้นที่',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                        ],
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

  static const blue = Color(0xFF2563F6);
  static const ink = Color(0xFF202938);
  static const muted = Color(0xFF667085);
  static const green = Color(0xFF12B981);

  Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3EAF4)),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFE5EDFF),
              child: Text(
                widget.auth.employee!.name.characters.firstOrNull ?? 'T',
                style: const TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี, ${widget.auth.employee!.name}',
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    widget.auth.employee!.position,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE3EAF4)),
              ),
              child: IconButton(
                onPressed: widget.onNotifications,
                tooltip: 'การแจ้งเตือน',
                icon: const Icon(Icons.notifications_outlined, color: ink),
              ),
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
            final checkedIn = today?.checkIn != null;
            final completed = today?.checkOut != null;
            final late = today?.status == 'late';
            final tone = late
                ? const Color(0xFFFF922B)
                : checkedIn
                ? green
                : muted;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card(
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: .09),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          checkedIn ? Icons.check_rounded : Icons.schedule,
                          color: tone,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'สถานะวันนี้',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            Text(
                              completed
                                  ? 'ออกงาน ${timeText(today?.checkOut)}'
                                  : checkedIn
                                  ? 'เข้างาน ${timeText(today?.checkIn)}'
                                  : 'ยังไม่ได้ลงเวลา',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      badge(
                        checkedIn ? (late ? 'มาสาย' : 'สำเร็จ') : 'รอลงเวลา',
                        tone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                card(
                  Column(
                    children: [
                      const ClockWidget(),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            elevation: 3,
                            shadowColor: blue.withValues(alpha: .3),
                            minimumSize: const Size(0, 50),
                          ),
                          onPressed: completed
                              ? null
                              : () async {
                                  await openPage(
                                    context,
                                    AttendanceScreen(
                                      data: widget.data,
                                      checkOut: checkedIn,
                                    ),
                                  );
                                  if (mounted) setState(() => revision++);
                                },
                          child: Text(
                            completed
                                ? 'ลงเวลาครบแล้ววันนี้'
                                : checkedIn
                                ? 'ลงเวลาออกงาน'
                                : 'ลงเวลาเข้างาน',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            backgroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Color(0xFFEDF2FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => openPage(
                            context,
                            OutsideWorkScreen(data: widget.data),
                          ),
                          child: const Text(
                            'ขอปฏิบัติงานนอกสถานที่',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    stat('มาทำงาน', summary.present, green),
                    const SizedBox(width: 10),
                    stat('มาสาย', summary.late, const Color(0xFFFF922B)),
                    const SizedBox(width: 10),
                    stat('ขาดงาน', summary.absent, const Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  summary.absent == null
                      ? 'สรุปเดือนนี้ • ยังไม่มีปฏิทินสำหรับคำนวณวันขาดงาน'
                      : 'สรุปการลงเวลาประจำเดือนนี้',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
                const SizedBox(height: 14),
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ตำแหน่งที่ทำงาน',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (areas.isEmpty)
                        const Text(
                          'แผนกยังไม่ได้กำหนดพื้นที่ปฏิบัติงาน',
                          style: TextStyle(color: muted),
                        )
                      else ...[
                        Semantics(
                          button: true,
                          label: 'เปิดภาพตำแหน่งเพื่อเลื่อนและซูม',
                          child: GestureDetector(
                            onTap: () => showLocationPreview(areas),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: SizedBox(
                                height: 110,
                                width: double.infinity,
                                child: WorkplaceMap(
                                  areas: areas,
                                  latitude: latitude,
                                  longitude: longitude,
                                  onTap: () => showLocationPreview(areas),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          positionUpdated == null
                              ? 'ภาพขอบเขตพื้นที่แผนก • กำลังรอตำแหน่ง GPS'
                              : 'ตำแหน่งปัจจุบัน • อัปเดต ${DateFormat('HH:mm:ss').format(positionUpdated!)}',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                        for (final a in areas)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: blue,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    a.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                if (latitude != null)
                                  badge(
                                    GeofenceService.contains(
                                          latitude!,
                                          longitude!,
                                          a.polygon,
                                        )
                                        ? 'อยู่ในพื้นที่'
                                        : 'นอกพื้นที่',
                                    GeofenceService.contains(
                                          latitude!,
                                          longitude!,
                                          a.polygon,
                                        )
                                        ? green
                                        : muted,
                                  ),
                              ],
                            ),
                          ),
                      ],
                      if (locationError != null)
                        Text(
                          locationError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 16),
                const Text(
                  'กิจกรรมล่าสุด',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  card(
                    const Text(
                      'ยังไม่มีประวัติการลงเวลา',
                      style: TextStyle(color: muted),
                    ),
                  ),
                for (final a in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card(
                      Row(
                        children: [
                          const Icon(
                            Icons.login_rounded,
                            color: green,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'บันทึกเวลาปฏิบัติงาน',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${a.date} • เข้า ${timeText(a.checkIn)} • ออก ${timeText(a.checkOut)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          badge(
                            statusText(a.status),
                            a.status == 'late'
                                ? const Color(0xFFFF922B)
                                : green,
                          ),
                        ],
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      openPage(context, BiometricScreen(data: widget.data)),
                  icon: const Icon(Icons.face_retouching_natural, size: 18),
                  label: const Text('ลงทะเบียนใบหน้า'),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
    ),
  );
  Widget stat(String label, int? value, Color color) => Expanded(
    child: card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value?.toString() ?? '—',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          '${DateFormat('HH:mm').format(now)} น.',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202938),
          ),
        ),
        Text(
          '${DateFormat('EEEE d MMMM', 'th').format(now)} ${now.year + 543}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
      ],
    );
  }
}
