import '../models/models.dart';
import 'api_service.dart';

class TimeGuardService {
  final ApiService api;
  TimeGuardService(this.api);
  Future<List<AttendanceEvent>> _events(
    String path, [
    Map<String, String>? query,
  ]) async => (await api.get(path, query) as List)
      .map((j) => AttendanceEvent.fromJson(j))
      .toList();
  Future<Attendance?> today() async {
    final events = await _events('attendance/today.php');
    return Attendance.pair(events).firstOrNull;
  }

  Future<List<Attendance>> history(String month) async => Attendance.pair(
    await _events('attendance/history.php', {'month': month}),
  );
  Future<List<Attendance>> recent() async =>
      Attendance.pair(await _events('dashboard/recent_activity.php'));
  Future<Dashboard> summary() async =>
      Dashboard.fromJson(await api.get('dashboard/summary.php'));
  Future<List<WorkArea>> areas() async =>
      (await api.get('location/get_employee_area.php') as List)
          .map((j) => WorkArea.fromJson(j))
          .toList();
  Future<Enrollment> enrollment() async =>
      Enrollment.fromJson(await api.get('biometric/get_status.php'));
  Future<void> registerFace(String image) async {
    await api.post('biometric/register.php', {'image_base64': image});
  }

  Future<List<OutsideRequest>> requests({bool active = false}) async =>
      (await api.get('outside_work/list.php', active ? {'active': '1'} : null)
              as List)
          .map((j) => OutsideRequest.fromJson(j))
          .toList();
  Future<void> createRequest(Json data) async {
    await api.post('outside_work/create.php', data);
  }

  Future<List<Notice>> notifications() async =>
      (await api.get('notifications/list.php') as List)
          .map((j) => Notice.fromJson(j))
          .toList();
  Future<void> markRead(int id) async {
    await api.post('notifications/mark_read.php', {'id': id});
  }
}
