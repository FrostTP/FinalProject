import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// Display only: attendance authorization still uses the existing PHP polygons.
class WorkplaceMap extends StatefulWidget {
  final List<WorkArea> areas;
  final double? latitude, longitude;
  final bool interactive;
  final VoidCallback? onTap;
  const WorkplaceMap({
    super.key,
    required this.areas,
    this.latitude,
    this.longitude,
    this.interactive = false,
    this.onTap,
  });
  @override
  State<WorkplaceMap> createState() => _WorkplaceMapState();
}

class _WorkplaceMapState extends State<WorkplaceMap> {
  final controller = MapController();
  bool ready = false, tileError = false;
  LatLng? get position => widget.latitude == null || widget.longitude == null
      ? null
      : LatLng(widget.latitude!, widget.longitude!);
  List<LatLng> get points => [
    for (final area in widget.areas)
      for (final p in area.polygon) LatLng(p.lat, p.lng),
    ?position,
  ];
  void fit() {
    if (!ready || points.isEmpty) return;
    if (points.length == 1) {
      controller.move(points.first, 17);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(30),
        maxZoom: 18,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WorkplaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive &&
        ready &&
        position != null &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      controller.move(position!, 16);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center =
        position ??
        (widget.areas.isNotEmpty
            ? LatLng(widget.areas.first.latitude, widget.areas.first.longitude)
            : const LatLng(13.7563, 100.5018));
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onTap: (_, _) => widget.onTap?.call(),
            onMapReady: () {
              ready = true;
              if (position == null) fit();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.projectapp.TimeGuard',
              maxNativeZoom: 19,
              errorTileCallback: (_, _, _) {
                if (mounted && !tileError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => tileError = true);
                  });
                }
              },
            ),
            PolygonLayer(
              polygons: [
                for (final area in widget.areas)
                  Polygon(
                    points: area.polygon
                        .map((p) => LatLng(p.lat, p.lng))
                        .toList(),
                    color: const Color(0x3312B981),
                    borderColor: const Color(0xFF12B981),
                    borderStrokeWidth: 3,
                  ),
              ],
            ),
            if (position != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: position!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x332563F6), blurRadius: 7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (widget.interactive)
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'แสดงขอบเขตทั้งหมด',
                  backgroundColor: Colors.white,
                  onPressed: fit,
                  child: const Icon(Icons.fit_screen),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'ไปยังตำแหน่งของฉัน',
                  backgroundColor: Colors.white,
                  onPressed: position == null
                      ? null
                      : () => controller.move(position!, 17),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        if (tileError)
          Positioned(
            top: 5,
            left: 5,
            right: widget.interactive ? 65 : 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'โหลดภาพแผนที่บางส่วนไม่ได้ ตรวจสอบอินเทอร์เน็ต',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
