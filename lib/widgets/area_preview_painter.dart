import 'package:flutter/material.dart';
import '../models/models.dart';

/// Geographic polygon preview, not map tiles or a fabricated GPS location.
class AreaPreviewPainter extends CustomPainter {
  final List<WorkArea> areas;
  final double? lat, lng;
  AreaPreviewPainter(this.areas, this.lat, this.lng);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7F3F8),
    );
    final grid = Paint()
      ..color = const Color(0xFFD5E7EF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final points = areas.expand((a) => a.polygon).toList();
    if (points.isEmpty) return;
    if (lat != null && lng != null) points.add(Coordinate(lat!, lng!));
    var minX = points.first.lng,
        maxX = minX,
        minY = points.first.lat,
        maxY = minY;
    for (final p in points) {
      if (p.lng < minX) minX = p.lng;
      if (p.lng > maxX) maxX = p.lng;
      if (p.lat < minY) minY = p.lat;
      if (p.lat > maxY) maxY = p.lat;
    }
    final dx = maxX - minX, dy = maxY - minY;
    final scaleX = (size.width - 32) / (dx == 0 ? .0001 : dx);
    final scaleY = (size.height - 24) / (dy == 0 ? .0001 : dy);
    final scale = scaleX < scaleY ? scaleX : scaleY;
    Offset project(double latitude, double longitude) => Offset(
      size.width / 2 + (longitude - (maxX + minX) / 2) * scale,
      size.height / 2 - (latitude - (maxY + minY) / 2) * scale,
    );
    for (final area in areas) {
      if (area.polygon.length < 3) continue;
      final path = Path();
      for (var i = 0; i < area.polygon.length; i++) {
        final p = project(area.polygon[i].lat, area.polygon[i].lng);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0x3312B981));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF12B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    if (lat != null && lng != null) {
      final p = project(lat!, lng!);
      canvas.drawCircle(p, 9, Paint()..color = Colors.white);
      canvas.drawCircle(p, 6, Paint()..color = const Color(0xFF2563F6));
    }
  }

  @override
  bool shouldRepaint(covariant AreaPreviewPainter oldDelegate) => true;
}
