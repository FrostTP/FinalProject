<?php
require_once __DIR__.'/../config/entities.php';
require_once TG_API_ROOT.'/config/rules.php';
require_once __DIR__.'/geofence_layers.php';
function audit(string $action,string $entity,string $id,array $fields=[]):void {
 $u=require_login();
 // Field names only: never copy passwords, face encodings, photos or OAuth identifiers into logs.
 q('INSERT INTO tech_web_audit_logs(actor_id,actor_role,action,entity,record_id,changed_fields) VALUES(?,?,?,?,?,?)',[$u['user_id'],$u['role'],$action,$entity,$id,json_encode(array_values($fields))]);
}
function web_id(string $prefix):string {
 q('INSERT INTO tech_id_sequences(prefix,next_value) VALUES(?,LAST_INSERT_ID(1001)) ON DUPLICATE KEY UPDATE next_value=LAST_INSERT_ID(next_value+1)',[$prefix]);
 $n=(string)db()->lastInsertId(); if(strlen($n)>10-strlen($prefix))throw new InvalidArgumentException('รหัสเต็ม กรุณาติดต่อผู้ดูแล');
 return $prefix.str_pad($n,10-strlen($prefix),'0',STR_PAD_LEFT);
}
function record(string $section,string $id,bool $lock=false):array {
 [$table,$key]=entities()[$section];
 [$where,$args]=$section==='employees'?scope('t'):['',[]];
 $r=q("SELECT t.* FROM `$table` t WHERE t.`$key`=?".$where.($lock?' FOR UPDATE':''),[$id,...$args])->fetch();
 if(!$r)abort_page(404,'ไม่พบข้อมูลหรือไม่มีสิทธิ์เข้าถึง'); return $r;
}
function persist_record(string $section,string $id,array $body):string {
 permit($section.'.write'); [$table,$key,$prefix,$label,$fields]=entities()[$section];
 $values=[];
 foreach($fields as $name=>$spec) {
  [$label,$type]=$spec; $v=$body[$name]??'';
  if(!is_string($v))throw new InvalidArgumentException('ข้อมูลไม่ถูกต้อง: '.$label); $v=trim($v);
  if($type==='password') {
   if($v===''&&$id!=='')continue;
   if(strlen($v)<8||strlen($v)>72)throw new InvalidArgumentException('รหัสผ่านต้องมี 8–72 ไบต์');
   $values['password_hash']=password_hash($v,PASSWORD_DEFAULT);continue;
  }
  if(in_array($type,['select','department','employee','area'])) {
   if(!array_key_exists($v,field_options($spec)))throw new InvalidArgumentException('กรุณาเลือก '.$label);
  }elseif($type==='polygon') {
   $p=json_decode($v,true);
   if(!is_array($p)||!array_is_list($p)||!polygon_valid($p))throw new InvalidArgumentException('กรุณากำหนด Polygon 3–200 จุด ไม่ซ้ำ ไม่ตัดกัน และมีพื้นที่');
   $p=array_map(fn($point)=>['lat'=>(float)$point['lat'],'lng'=>(float)$point['lng']],$p);
   $v=json_encode($p); // Center calculated on server; never trust hidden center fields.
   $values['center_latitude']=array_sum(array_column($p,'lat'))/count($p);
   $values['center_longitude']=array_sum(array_column($p,'lng'))/count($p);
  }elseif(in_array($type,['date','optional-date'])) {
   if($v===''&&$type==='optional-date'){$values[$name]=null;continue;}
   $date=DateTimeImmutable::createFromFormat('!Y-m-d',$v);
   if(!$date||$date->format('Y-m-d')!==$v)throw new InvalidArgumentException('วันที่ไม่ถูกต้อง: '.$label);
  }elseif($type==='time') {
   if($v===''){$values[$name]=null;continue;}
   if(strlen($v)===5)$v.=':00';
   if(!preg_match('/^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$/D',$v))throw new InvalidArgumentException('เวลาไม่ถูกต้อง');
  }else {
   if($v===''&&$type!=='optional')throw new InvalidArgumentException('กรุณากรอก '.$label);
   if(mb_strlen($v)>$spec[2])throw new InvalidArgumentException('ข้อมูลยาวเกินไป: '.$label);
   if($type==='email'&&!filter_var($v,FILTER_VALIDATE_EMAIL))throw new InvalidArgumentException('อีเมลไม่ถูกต้อง');
   if($type==='optional'&&$v==='')$v=null;
  }
  $values[$name]=$v;
 }
 db()->beginTransaction(); $GLOBALS['web_transaction']=true;
 try {
  // Same employee-row lock as the mobile attendance API for assignment changes.
  if($section==='work_areas')q('SELECT employee_id FROM employees WHERE employee_id=? FOR UPDATE',[$values['employee_id']]);
  $old=$id!==''?record($section,$id,true):null;
  if($section==='admins'&&$id===current_user()['user_id']&&$values['status']!=='active')throw new InvalidArgumentException('ไม่สามารถปิดบัญชีตนเอง');
  if($section==='work_areas') {
   if($values['area_id']===campus_area_id())throw new InvalidArgumentException('ขอบเขตมหาวิทยาลัยเป็นชั้นหลัก กรุณามอบหมายพื้นที่ทำงานของแผนกแทน');
   if($old&&$old['employee_id']!==$values['employee_id'])throw new InvalidArgumentException('ไม่สามารถย้ายรายการไปพนักงานอื่น');
   if($values['end_date']!==null&&$values['end_date']<$values['effective_date'])throw new InvalidArgumentException('วันสิ้นสุดต้องไม่ก่อนวันเริ่ม');
   if($values['status']==='active') {
    if(!q('SELECT g.area_id FROM geofence_areas g JOIN employees e ON e.department_id=g.department_id WHERE e.employee_id=? AND g.area_id=?',[$values['employee_id'],$values['area_id']])->fetch())throw new InvalidArgumentException('พื้นที่ทำงานต้องอยู่ในแผนกของพนักงาน');
    foreach([['employees','employee_id',$values['employee_id']],['geofence_areas','area_id',$values['area_id']]] as [$t,$k,$v])if(!q("SELECT `$k` FROM `$t` WHERE `$k`=? AND status='active'",[$v])->fetch())throw new InvalidArgumentException('พนักงานและพื้นที่ต้องมีสถานะใช้งาน');
    if($values['is_primary']==='1'&&q("SELECT employee_area_id FROM employee_work_areas WHERE employee_id=? AND status='active' AND is_primary=1 AND employee_area_id<>?",[$values['employee_id'],$id])->fetch())throw new InvalidArgumentException('พนักงานมีพื้นที่หลักที่ใช้งานอยู่แล้ว');
    if(q("SELECT employee_area_id FROM employee_work_areas WHERE employee_id=? AND area_id=? AND status='active' AND employee_area_id<>? AND effective_date<=? AND (end_date IS NULL OR end_date>=?)",[$values['employee_id'],$values['area_id'],$id,$values['end_date']??'9999-12-31',$values['effective_date']])->fetch())throw new InvalidArgumentException('พื้นที่นี้ถูกมอบหมายในช่วงวันที่ทับซ้อนแล้ว');
   }
  }
  if($section==='settings') {
   // Serialize attendance configuration creation across sessions without adding core columns.
   q("INSERT IGNORE INTO tech_id_sequences VALUES('CFG',1000)");q("SELECT prefix FROM tech_id_sequences WHERE prefix='CFG' FOR UPDATE");
   if($old&&$old['config_type']==='attendance'&&$values['config_type']!=='attendance')throw new InvalidArgumentException('ห้ามเปลี่ยนประเภทการตั้งค่าเวลางานที่ใช้งานอยู่');
   if($values['config_type']==='attendance') {
    if(!$values['start_time']||!$values['start_late']||$values['start_late']<$values['start_time'])throw new InvalidArgumentException('ต้องกำหนดเวลาเริ่มและเกณฑ์มาสายไม่ก่อนเริ่มงาน');
    if(q("SELECT config_id FROM system_configurations WHERE config_type='attendance' AND config_id<>?",[$id])->fetch())throw new InvalidArgumentException('มีการตั้งเวลา attendance แล้ว กรุณาแก้ไขรายการเดิม');
   }
   $values['updated_date']=date('Y-m-d H:i:s');
  }elseif(!$old&&$section!=='work_areas')$values['created_date']=date($section==='geofences'?'Y-m-d H:i:s':'Y-m-d');
  if($old) { $assign=implode(',',array_map(fn($k)=>"`$k`=?",array_keys($values))); q("UPDATE `$table` SET $assign WHERE `$key`=?",[...array_values($values),$id]); }
  else { $id=web_id($prefix);$values=[$key=>$id]+$values; $cols=implode(',',array_map(fn($k)=>"`$k`",array_keys($values)));$marks=implode(',',array_fill(0,count($values),'?'));q("INSERT INTO `$table`($cols) VALUES($marks)",array_values($values)); }
  audit($old?'update':'create',$section,$id,array_keys($values));db()->commit();return $id;
 }catch(Throwable $ex){if(db()->inTransaction())db()->rollBack();throw $ex;}
}
