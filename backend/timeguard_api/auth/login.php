<?php
// Backoffice only. Employee passwords are not supported.
require_once __DIR__.'/../config/bootstrap.php';method('POST');$b=body();$role=$b['role'] ?? '';
if(!in_array($role,['admin','hr','supervisor'],true)){fail('พนักงานต้องเข้าสู่ระบบด้วย Google',403);}
$username=text_value($b,'username',50);$password=$b['password'] ?? null;if(!is_string($password)||strlen($password)>1024){fail('รหัสผ่านไม่ถูกต้อง');}
$key=hash('sha256',$role.':'.$username);throttle($key);[$table,$id]=identity_spec($role);
$row=query("SELECT * FROM `$table` WHERE username=? AND status='active'",[$username])->fetch();
if(!$row||!password_verify($password,$row['password_hash'])){fail('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง',401);}
db()->beginTransaction();query("UPDATE `$table` SET last_login_date=NOW() WHERE `$id`=?",[$row[$id]]);query('DELETE FROM tech_login_attempts WHERE attempt_key=?',[$key]);$result=issue_token($row,$role);db()->commit();respond($result);
