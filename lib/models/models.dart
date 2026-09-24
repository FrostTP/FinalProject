import 'dart:convert';

typedef Json = Map<String, dynamic>;
int asInt(dynamic v) => int.parse(v.toString());
double asDouble(dynamic v) => double.parse(v.toString());
bool asBool(dynamic v) => v == true || v == 1 || v == '1';

/// Core E. Never contains employee passwords or a role column.
class Employee {
  final String employeeId, fullName, email, departmentId, status, createdDate;
  final String? googleUid, phone;
  Employee.fromJson(Json j)
    : employeeId = j['employee_id'],
      fullName = j['full_name'],
      email = j['email'],
      departmentId = j['department_id'],
      status = j['status'],
      createdDate = j['created_date'],
      googleUid = j['google_uid'],
      phone = j['phone'];
  Json toJson() => {
    'employee_id': employeeId,
    'full_name': fullName,
    'email': email,
    'google_uid': googleUid,
    'phone': phone,
    'department_id': departmentId,
    'status': status,
    'created_date': createdDate,
  };
}

/// Authentication envelope only; does not merge E/A/H/S in storage.
class SessionUser {
  final String id, role;
  final Json profile;
  SessionUser.fromJson(Json j)
    : id = j['id'],
      role = j['role'],
      profile = Map<String, dynamic>.from(j['profile']);
  String get name => profile['full_name'];
  String get email => profile['email'];
  String get phone => profile['phone'] ?? '';
  String get position => profile['department_id'] ?? role;
  Json toJson() => {'id': id, 'role': role, 'profile': profile};
}

class Coordinate {
  final double lat, lng;
  const Coordinate(this.lat, this.lng);
  Coordinate.fromJson(Json j)
    : lat = asDouble(j['lat']),
      lng = asDouble(j['lng']);
  Json toJson() => {'lat': lat, 'lng': lng};
}

/// Core G. Assignment metadata is returned separately by the area endpoint.
class WorkArea {
  final String id, name, departmentId, status, createdDate;
  final double latitude, longitude;
  final List<Coordinate> polygon;
  WorkArea.fromJson(Json j)
    : id = j['area_id'],
      name = j['area_name'],
      departmentId = j['department_id'],
      status = j['status'],
      createdDate = j['created_date'],
      latitude = asDouble(j['center_latitude']),
      longitude = asDouble(j['center_longitude']),
      polygon =
          ((j['polygon_coordinates'] is String
                      ? jsonDecode(j['polygon_coordinates'])
                      : j['polygon_coordinates'])
                  as List)
              .map((p) => Coordinate.fromJson(p))
              .toList();
  Json toJson() => {
    'area_id': id,
    'area_name': name,
    'department_id': departmentId,
    'polygon_coordinates': jsonEncode(polygon.map((p) => p.toJson()).toList()),
    'center_latitude': latitude,
    'center_longitude': longitude,
    'status': status,
    'created_date': createdDate,
  };
}

class EmployeeArea {
  final String employeeAreaId, employeeId, areaId, effectiveDate, status;
  final String? endDate;
  final bool isPrimary;
  EmployeeArea.fromJson(Json j)
    : employeeAreaId = j['employee_area_id'],
      employeeId = j['employee_id'],
      areaId = j['area_id'],
      effectiveDate = j['effective_date'],
      status = j['status'],
      endDate = j['end_date'],
      isPrimary = asBool(j['is_primary']);
  bool validOn(String date) =>
      status == 'active' &&
      effectiveDate.compareTo(date) <= 0 &&
      (endDate == null || endDate!.compareTo(date) >= 0);
  Json toJson() => {
    'employee_area_id': employeeAreaId,
    'employee_id': employeeId,
    'area_id': areaId,
    'is_primary': isPrimary,
    'effective_date': effectiveDate,
    'end_date': endDate,
    'status': status,
  };
}

/// Core AT: one row per event, including its own photo, polygon and offsite reference.
class AttendanceEvent {
  final String id,
      userId,
      checkType,
      checkDatetime,
      verificationMethod,
      zoneStatus,
      approvalStatus;
  final String? areaId,
      deviceInfo,
      evidencePhoto,
      reason,
      approvedBy,
      approvedDate,
      offsiteRequestId;
  final double latitude, longitude;
  final bool isLate;
  AttendanceEvent.fromJson(Json j)
    : id = j['attendance_id'],
      userId = j['user_id'],
      areaId = j['area_id'],
      checkType = j['check_type'],
      checkDatetime = j['check_datetime'],
      latitude = asDouble(j['latitude']),
      longitude = asDouble(j['longitude']),
      verificationMethod = j['verification_method'],
      zoneStatus = j['zone_status'],
      deviceInfo = j['device_info'],
      isLate = asBool(j['is_late']),
      evidencePhoto = j['evidence_photo'],
      reason = j['reason'],
      approvalStatus = j['approval_status'],
      approvedBy = j['approved_by'],
      approvedDate = j['approved_date'],
      offsiteRequestId = j['offsite_request_id'];
  String get date => checkDatetime.substring(0, 10);
  Json toJson() => {
    'attendance_id': id,
    'user_id': userId,
    'area_id': areaId,
    'check_type': checkType,
    'check_datetime': checkDatetime,
    'latitude': latitude,
    'longitude': longitude,
    'verification_method': verificationMethod,
    'zone_status': zoneStatus,
    'device_info': deviceInfo,
    'is_late': isLate,
    'evidence_photo': evidencePhoto,
    'reason': reason,
    'approval_status': approvalStatus,
    'approved_by': approvedBy,
    'approved_date': approvedDate,
    'offsite_request_id': offsiteRequestId,
  };
}

/// Display-only pairing; never posted to the database as a combined row.
class Attendance {
  final String date;
  final List<AttendanceEvent> events;
  Attendance(this.date, this.events);
  String? get checkIn =>
      events.where((e) => e.checkType == 'เข้างาน').firstOrNull?.checkDatetime;
  String? get checkOut =>
      events.where((e) => e.checkType == 'ออกงาน').firstOrNull?.checkDatetime;
  String get status => events.any((e) => e.isLate)
      ? 'late'
      : events.any((e) => e.offsiteRequestId != null)
      ? 'approved_outside_area'
      : 'present';
  static List<Attendance> pair(List<AttendanceEvent> events) {
    final days = <String, List<AttendanceEvent>>{};
    for (final e in events) {
      (days[e.date] ??= []).add(e);
    }
    return (days.entries
        .map(
          (d) => Attendance(
            d.key,
            d.value..sort((a, b) => a.checkDatetime.compareTo(b.checkDatetime)),
          ),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)));
  }
}

class OutsideRequest {
  final String id,
      employeeId,
      requestDate,
      start,
      end,
      location,
      reason,
      status;
  final String? approvedBy, approvedDate;
  OutsideRequest.fromJson(Json j)
    : id = j['offsite_request_id'],
      employeeId = j['employee_id'],
      requestDate = j['request_date'],
      start = j['work_date_start'],
      end = j['work_date_end'],
      location = j['location_description'],
      reason = j['reason'],
      status = j['approval_status'],
      approvedBy = j['approved_by'],
      approvedDate = j['approved_date'];
  Json toJson() => {
    'offsite_request_id': id,
    'employee_id': employeeId,
    'request_date': requestDate,
    'work_date_start': start,
    'work_date_end': end,
    'location_description': location,
    'reason': reason,
    'approval_status': status,
    'approved_by': approvedBy,
    'approved_date': approvedDate,
  };
}

class Enrollment {
  final String status;
  final String? biometricId,
      userId,
      faceImage,
      faceEncoding,
      registrationDate,
      approvedBy,
      approvedDate,
      recordStatus;
  Enrollment.fromJson(Json j)
    : status = j['approval_status'],
      biometricId = j['biometric_id'],
      userId = j['user_id'],
      faceImage = j['face_image'],
      faceEncoding = j['face_encoding'],
      registrationDate = j['registration_date'],
      approvedBy = j['approved_by'],
      approvedDate = j['approved_date'],
      recordStatus = j['status'];
  Json toJson() => {
    'biometric_id': biometricId,
    'user_id': userId,
    'face_image': faceImage,
    'face_encoding': faceEncoding,
    'registration_date': registrationDate,
    'approval_status': status,
    'approved_by': approvedBy,
    'approved_date': approvedDate,
    'status': recordStatus,
  };
}

class Notice {
  final int id;
  final String title, body, createdAt;
  final String? readAt;
  bool get read => readAt != null;
  Notice.fromJson(Json j)
    : id = asInt(j['id']),
      title = j['title'],
      body = j['body'],
      createdAt = j['created_at'],
      readAt = j['read_at'];
  Json toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt,
    'read_at': readAt,
  };
}

class Dashboard {
  final int present, late;
  final int? absent;
  Dashboard.fromJson(Json j)
    : present = asInt(j['present']),
      late = asInt(j['late']),
      absent = j['absent'] == null ? null : asInt(j['absent']);
  Json toJson() => {'present': present, 'late': late, 'absent': absent};
}

String statusText(String v) =>
    const {
      'present': 'มาทำงาน',
      'late': 'มาสาย',
      'absent': 'ขาดงาน',
      'approved_outside_area': 'ปฏิบัติงานนอกพื้นที่',
      'outside_area': 'นอกพื้นที่',
      'pending': 'รออนุมัติ',
      'approved': 'อนุมัติแล้ว',
      'rejected': 'ไม่อนุมัติ',
      'not_registered': 'ยังไม่ลงทะเบียน',
    }[v] ??
    v;
String timeText(String? v) => v == null
    ? '--:--'
    : v.length >= 16
    ? v.substring(11, 16)
    : v;
