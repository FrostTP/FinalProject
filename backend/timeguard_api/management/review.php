<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');$u=user();$b=body();$kind=$b['kind'] ?? '';
if($kind==='biometrics'){
 roles($u,['hr']);$table='face_biometrics';$key='biometric_id';$owner='user_id';$approved=['approved','rejected'];
}elseif($kind==='requests'||$kind==='attendance'){
 roles($u,['supervisor']);$table=$kind==='requests' ? 'offsite_work_requests' : 'attendance_logs';$key=$kind==='requests' ? 'offsite_request_id' : 'attendance_id';$owner=$kind==='requests' ? 'employee_id' : 'user_id';$approved=['อนุมัติ','ปฏิเสธ'];
}else{fail('รายการไม่ถูกต้อง');}
$id=id_value($b,$key);$status=$b['approval_status'] ?? '';if(!in_array($status,$approved,true)){fail('สถานะไม่ถูกต้อง');}
db()->beginTransaction();$row=query("SELECT r.*,e.department_id FROM `$table` r JOIN employees e ON e.employee_id=r.`$owner` WHERE r.`$key`=? FOR UPDATE",[$id])->fetch();
if(!$row){fail('ไม่พบรายการ',404);}if($u['role']==='supervisor'&&$row['department_id']!==$u['profile']['department_id']){fail('ไม่ใช่พนักงานในแผนกที่ดูแล',403);}
if(!in_array($row['approval_status'],['pending','รออนุมัติ'],true)||($kind==='biometrics'&&$row['status']!=='active')){fail('รายการได้รับการพิจารณาแล้วหรือไม่ได้ใช้งาน',409);}
query("UPDATE `$table` SET approval_status=?,approved_by=?,approved_date=NOW() WHERE `$key`=?",[$status,$u['id'],$id]);notice($row[$owner],'แจ้งผลการอนุมัติ',$status);db()->commit();respond();
