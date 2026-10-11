<?php
require __DIR__.'/../includes/bootstrap.php';
if(current_user())redirect('dashboard/'); $error='';
if($_SERVER['REQUEST_METHOD']==='POST') {
 check_csrf();
 try {
  $role=input('role'); [$table,$key]=identity($role); $name=input('username'); $password=$_POST['password']??'';
  if(!is_string($password)||strlen($password)>1024||mb_strlen($name)>50)throw new InvalidArgumentException('ข้อมูลไม่ถูกต้อง');
  $attempt=throttle_login($role,$name); $r=q("SELECT * FROM `$table` WHERE username=? AND status='active'",[$name])->fetch();
  if(!$r||!password_verify($password,$r['password_hash']))throw new InvalidArgumentException('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
  session_regenerate_id(true); $_SESSION=[]; $_SESSION['user']=['user_id'=>$r[$key],'full_name'=>$r['full_name'],'role'=>$role];
  $_SESSION['credential_version']=hash('sha256',$r['password_hash']); $_SESSION['started']=$_SESSION['last_seen']=time();
  q("UPDATE `$table` SET last_login_date=NOW() WHERE `$key`=?",[$r[$key]]); q('DELETE FROM tech_login_attempts WHERE attempt_key=?',[$attempt]); redirect('dashboard/');
 }catch(InvalidArgumentException $ex){$error=$ex->getMessage();}
}
?><!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>เข้าสู่ระบบ · TimeGuard</title><link rel="stylesheet" href="<?=e(url('assets/vendor/bootstrap.min.css'))?>"><link rel="stylesheet" href="<?=e(url('assets/css/app.css'))?>"></head><body><div class="login-shell"><section class="login-story"><div class="eyebrow text-white">TIMEGUARD MANAGEMENT</div><h1>ทุกเวลางาน<br>ยืนยันได้</h1><p>จัดการบุคลากร พื้นที่ปฏิบัติงาน และการลงเวลา<br>เพื่อการทำงานที่เป็นระบบและตรวจสอบได้</p></section><section class="login-form"><div class="card"><div class="card-body p-4 p-md-5"><div class="brand mb-4">TimeGuard</div><h1 class="h4">เข้าสู่ระบบจัดการ</h1><p class="text-secondary mb-4">สำหรับผู้ดูแลระบบ ฝ่ายบุคคล และหัวหน้างาน</p><?php if($error):?><div class="alert alert-danger" role="alert"><?=e($error)?></div><?php endif;?><form method="post"><?php csrf_field();?><label class="form-label" for="role">บทบาท</label><select class="form-select mb-3" name="role" id="role"><?php foreach(['admin'=>'ผู้ดูแลระบบ','hr'=>'ฝ่ายบุคคล','supervisor'=>'หัวหน้างาน'] as $v=>$label):?><option value="<?=e($v)?>" <?=input('role','admin')===$v?'selected':''?>><?=e($label)?></option><?php endforeach;?></select><label class="form-label" for="username">ชื่อผู้ใช้</label><input class="form-control mb-3" name="username" id="username" maxlength="50" autocomplete="username" required value="<?=e(input('username'))?>"><label class="form-label" for="password">รหัสผ่าน</label><input class="form-control mb-4" type="password" name="password" id="password" autocomplete="current-password" required><button class="btn btn-primary w-100 py-2">เข้าสู่ระบบ</button></form><p class="small text-secondary mt-4 mb-0">พนักงานใช้งานผ่านแอป TimeGuard ด้วยบัญชี Google</p></div></div></section></div></body></html>
