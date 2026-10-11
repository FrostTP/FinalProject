<?php
require __DIR__.'/../includes/bootstrap.php';require __DIR__.'/../includes/repository.php';permit('employees.link');check_csrf();$id=input('id');record('employees',$id);$uid=input('google_uid');
if(strlen($uid)>50||($uid!==''&&!preg_match('/^[0-9]+$/D',$uid)))abort_page(422,'Google UID ต้องเป็นตัวเลขไม่เกิน 50 หลัก');
db()->beginTransaction();$GLOBALS['web_transaction']=true;
try{q('UPDATE employees SET google_uid=? WHERE employee_id=?',[$uid?:null,$id]);audit('link','employees',$id,['google_uid']);db()->commit();flash('บันทึกการผูกบัญชีสำเร็จ');redirect('employees/?id='.rawurlencode($id));}catch(PDOException $ex){db()->rollBack();if($ex->getCode()==='23000')abort_page(409,'Google UID นี้ถูกใช้แล้ว');throw $ex;}
