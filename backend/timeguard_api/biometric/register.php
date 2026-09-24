<?php
require_once __DIR__.'/../config/face.php';method('POST');$u=employee();$b=body();$bytes=face_image_bytes($b);
$result=face_call('encode',['image_base64'=>base64_encode($bytes)]);
if(!valid_encoding($result['encoding'] ?? null)){fail('Face encoding ไม่ถูกต้อง',502);}
db()->beginTransaction();query('SELECT employee_id FROM employees WHERE employee_id=? FOR UPDATE',[$u['id']]);
$old=query("SELECT * FROM face_biometrics WHERE user_id=? AND status='active' ORDER BY registration_date DESC,biometric_id DESC LIMIT 1 FOR UPDATE",[$u['id']])->fetch();
if($old && in_array($old['approval_status'],['pending','approved'],true)){fail('มีรายการลงทะเบียนรออนุมัติหรืออนุมัติแล้ว',409);}
$id=next_id('F');$path=save_face_image($bytes);
try {
    query("UPDATE face_biometrics SET status='inactive' WHERE user_id=? AND status='active'",[$u['id']]);
    query("INSERT INTO face_biometrics VALUES(?,?,?,?,NOW(),'pending',NULL,NULL,'active')",[$id,$u['id'],$path,json_encode($result['encoding'])]);
    notice($u['id'],'ส่งภาพใบหน้าเพื่อลงทะเบียนแล้ว','กรุณารอ HR ตรวจสอบและอนุมัติ');db()->commit();
}catch(Throwable $e){@unlink(__DIR__.'/../'.$path);throw $e;}
respond(['biometric_id'=>$id,'approval_status'=>'pending']);
