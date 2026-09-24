<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');$u=employee();$b=body();$id=filter_var($b['id'] ?? null,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);if($id===false){fail('รหัสไม่ถูกต้อง');}
if(!query('SELECT id FROM tech_notifications WHERE id=? AND employee_id=?',[$id,$u['id']])->fetch()){fail('ไม่พบการแจ้งเตือน',404);}query('UPDATE tech_notifications SET read_at=COALESCE(read_at,NOW()) WHERE id=? AND employee_id=?',[$id,$u['id']]);respond();
