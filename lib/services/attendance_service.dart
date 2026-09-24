import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'timeguard_service.dart';
import 'location_service.dart';
import 'geofence_service.dart';
import 'face_service.dart';

class AttendanceService {
  final TimeGuardService data;
  AttendanceService(this.data);
  Future<AttendanceEvent> submit(
    bool checkOut,
    void Function(String) progress,
  ) async {
    if (data.api.token == null) {
      throw const ApiException('กรุณาเข้าสู่ระบบ');
    }
    progress('กำลังตรวจสอบ GPS และ Polygon');
    var p = await LocationService().current();
    final areas = await data.areas();
    if (!areas.any(
          (a) => GeofenceService.contains(p.latitude, p.longitude, a.polygon),
        ) &&
        (await data.requests(active: true)).isEmpty) {
      throw const ApiException(
        'อยู่นอก Polygon และไม่มีคำขอนอกพื้นที่ที่อนุมัติในวันนี้',
      );
    }
    if ((await data.enrollment()).status != 'approved') {
      throw const ApiException('กรุณาลงทะเบียนใบหน้าและรอ HR อนุมัติก่อน');
    }
    progress('ถ่ายภาพใบหน้าเพื่อเปรียบเทียบ');
    final image = await FaceService().capture();
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
          }),
    );
  }
}
