import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('กรุณาเปิดตำแหน่ง GPS');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException('กรุณาเปิดสิทธิ์ตำแหน่งในการตั้งค่าแอป');
    }
    if (permission == LocationPermission.denied) {
      throw const ApiException('ต้องอนุญาตตำแหน่ง GPS เพื่อลงเวลา');
    }
  }

  Stream<Position> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    ),
  );

  Future<Position> current() async {
    await ensurePermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (p.accuracy > 100) {
        throw const ApiException(
          'GPS คลาดเคลื่อนเกิน 100 เมตร กรุณาลองใหม่ในที่โล่ง',
        );
      }
      return p;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('ไม่สามารถยืนยันตำแหน่ง GPS ได้ กรุณาลองใหม่');
    }
  }
}
