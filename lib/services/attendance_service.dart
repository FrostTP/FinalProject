import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'timeguard_service.dart';
import 'location_service.dart';
import 'geofence_service.dart';
import 'face_service.dart';

class AttendanceLocationCheck {
  final double latitude, longitude, accuracy;
  final List<WorkArea> areas;
  final bool inside, approvedOffsite;
  const AttendanceLocationCheck(
    this.latitude,
    this.longitude,
    this.accuracy,
    this.areas,
    this.inside,
    this.approvedOffsite,
  );
}

class AttendanceService {
  final TimeGuardService data;
  AttendanceService(this.data);
  Future<AttendanceEvent> submit(
    bool checkOut,
    void Function(String) progress, {
    Future<void> Function(AttendanceLocationCheck)? onLocationChecked,
    void Function(String)? onFaceCaptured,
    Future<Json> Function(Json)? onLate,
  }) async {
    if (data.api.token == null) {
      throw const ApiException('กรุณาเข้าสู่ระบบ');
    }
    progress('กำลังตรวจสอบ GPS และ Polygon');
    var p = await LocationService().current();
    final areas = await data.areas();
    if (areas.isEmpty) {
      throw const ApiException(
        'แผนกยังไม่มีพื้นที่ที่ใช้งานได้ กรุณาติดต่อ HR',
      );
    }
    final inside = areas.any(
      (a) => GeofenceService.contains(p.latitude, p.longitude, a.polygon),
    );
    final approvedOffsite =
        !inside && (await data.requests(active: true)).isNotEmpty;
    if (onLocationChecked != null) {
      await onLocationChecked(
        AttendanceLocationCheck(
          p.latitude,
          p.longitude,
          p.accuracy,
          areas,
          inside,
          approvedOffsite,
        ),
      );
    }
    if (!inside && !approvedOffsite) {
      throw const ApiException(
        'อยู่นอกพื้นที่แผนก และไม่มีคำขอนอกพื้นที่ที่อนุมัติในวันนี้',
      );
    }
    if ((await data.enrollment()).status != 'approved') {
      throw const ApiException('กรุณาลงทะเบียนใบหน้าและรอ HR อนุมัติก่อน');
    }
    progress('ถ่ายภาพใบหน้าเพื่อเปรียบเทียบ');
    final image = await FaceService().capture();
    onFaceCaptured?.call(image);
    Json lateEvidence = {};
    if (!checkOut && onLate != null) {
      progress('กำลังเปรียบเทียบใบหน้า');
      final preview = Map<String, dynamic>.from(
        await data.api.post('attendance/preview.php', {'image_base64': image}),
      );
      if (preview['is_late'] == true) {
        progress('แนบรูปภาพและเหตุผลประกอบ');
        lateEvidence = await onLate(preview);
      }
    }
    p = await LocationService().current();
    progress('กำลังเปรียบเทียบใบหน้าและบันทึกเวลากับเซิร์ฟเวอร์');
    return AttendanceEvent.fromJson(
      await data.api
          .post('attendance/${checkOut ? 'check_out' : 'check_in'}.php', {
            'latitude': p.latitude,
            'longitude': p.longitude,
            'accuracy': p.accuracy,
            'device_info': 'TimeGuard/${defaultTargetPlatform.name}',
            'image_base64': image,
            ...lateEvidence,
          }),
    );
  }
}
