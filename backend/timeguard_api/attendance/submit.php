<?php
require_once __DIR__.'/../config/face.php';method('POST');$u=employee();if(!isset($checkOut)){fail('Not found',404);}$b=body();
$lat=number_value($b,'latitude',-90,90);$lng=number_value($b,'longitude',-180,180);number_value($b,'accuracy',0,100);
$device=text_value($b,'device_info',100);$bytes=face_image_bytes($b);
$face=query("SELECT * FROM face_biometrics WHERE user_id=? AND status='active' AND approval_status='approved'",[$u['id']])->fetch();
if(!$face){fail('ใบหน้ายังไม่ได้รับอนุมัติจาก HR',403);}
$encoding=json_decode($face['face_encoding'],true);if(!valid_encoding($encoding)){fail('ข้อมูลใบหน้าไม่พร้อม กรุณาติดต่อ HR',409);}
// PHP calls the private recognition service. Client booleans/scores are never accepted.
$verification=face_call('verify',['image_base64'=>base64_encode($bytes),'reference_encoding'=>$encoding]);
if(($verification['verified'] ?? false)!==true){fail('ใบหน้าไม่ตรงกับข้อมูลที่ลงทะเบียน',403);}
db()->beginTransaction();query('SELECT employee_id FROM employees WHERE employee_id=? FOR UPDATE',[$u['id']]);
$current=query("SELECT face_encoding FROM face_biometrics WHERE user_id=? AND status='active' AND approval_status='approved' FOR UPDATE",[$u['id']])->fetch();
if(!$current||!hash_equals($face['face_encoding'],$current['face_encoding'])){fail('สถานะใบหน้าเปลี่ยน กรุณาลองใหม่',409);}
$error=transition_error(today_events($u['id']),$checkOut);if($error){fail($error,409);}
$areaId=null;$offsiteId=null;$areas=active_areas($u['id']);
if(!$areas){fail('ไม่พบ EA ที่ใช้งานได้ในวันนี้ กรุณาให้ HR มอบหมายพื้นที่ก่อน',403);}
foreach($areas as $area){$polygon=json_decode($area['polygon_coordinates'],true);if(is_array($polygon)&&polygon_valid($polygon)&&point_in_polygon($lat,$lng,$polygon)){$areaId=$area['area_id'];break;}}
if($areaId===null){$r=query("SELECT offsite_request_id FROM offsite_work_requests WHERE employee_id=? AND approval_status='อนุมัติ' AND work_date_start<=CURDATE() AND work_date_end>=CURDATE() ORDER BY approved_date DESC LIMIT 1 FOR UPDATE",[$u['id']])->fetch();if(!$r){fail('อยู่นอก Polygon และไม่มีคำขอนอกพื้นที่ที่อนุมัติในวันนี้',403);}$offsiteId=$r['offsite_request_id'];}
$zone=$areaId===null ? 'outside' : 'inside';
// AT.area_id remains the employee's assigned reference area when outside it.
$areaId ??= $areas[0]['area_id'];
$cfg=query("SELECT * FROM system_configurations WHERE config_type='attendance' ORDER BY config_id LIMIT 1")->fetch();
if(!$cfg||!$cfg['start_time']||!$cfg['start_late']){fail('ยังไม่ได้กำหนดเวลาเริ่มงานและเกณฑ์มาสายใน CFG',503);}
$id=next_id('AT');$path=save_face_image($bytes);$type=$checkOut ? 'ออกงาน' : 'เข้างาน';
try {
    query("INSERT INTO attendance_logs(attendance_id,user_id,area_id,check_type,check_datetime,latitude,longitude,verification_method,zone_status,device_info,is_late,evidence_photo,reason,approval_status,approved_by,approved_date,offsite_request_id) VALUES(?,?,?,?,NOW(),?,?,'face_recognition',?,?,?,?,NULL,'อนุมัติ',NULL,NULL,?)",[$id,$u['id'],$areaId,$type,$lat,$lng,$zone,$device,!$checkOut && date('H:i:s')>$cfg['start_late'] ? 1 : 0,$path,$offsiteId]);
    notice($u['id'],'ลงเวลา'.$type.'สำเร็จ',date('d/m/Y H:i:s'));$saved=query('SELECT * FROM attendance_logs WHERE attendance_id=?',[$id])->fetch();db()->commit();
}catch(Throwable $e){@unlink(__DIR__.'/../'.$path);throw $e;}
respond($saved);
