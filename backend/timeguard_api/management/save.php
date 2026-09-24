<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');$u=user();roles($u,['hr','admin']);$b=body();$kind=$b['kind'] ?? '';
function status_value(array $b): string {$v=$b['status'] ?? 'active';if(!in_array($v,['active','inactive'],true)){fail('สถานะไม่ถูกต้อง');}return $v;}
function exists_id(string $table,string $key,string $id): void {if(!query("SELECT `$key` FROM `$table` WHERE `$key`=?",[$id])->fetch()){fail('ไม่พบรหัส '.$id,404);}}
function persist(string $table,string $key,array $values,array $b): string {
    if(isset($b[$key])){$id=id_value($b,$key);exists_id($table,$key,$id);$assign=implode(',',array_map(fn($c)=>"`$c`=?",array_keys($values)));query("UPDATE `$table` SET $assign WHERE `$key`=?",[...array_values($values),$id]);}
    else{$prefix=array_search($table,require __DIR__.'/../config/table_names.php',true);if($prefix===false){throw new InvalidArgumentException('Unknown core table');}$id=next_id($prefix);$values=[$key=>$id]+$values;$cols=implode(',',array_map(fn($c)=>"`$c`",array_keys($values)));$marks=implode(',',array_fill(0,count($values),'?'));query("INSERT INTO `$table`($cols) VALUES($marks)",array_values($values));}return $id;
}
db()->beginTransaction();
switch($kind){
case 'employee':
 $email=text_value($b,'email',100);if(!filter_var($email,FILTER_VALIDATE_EMAIL)){fail('อีเมลไม่ถูกต้อง');}
 if(array_key_exists('password',$b)||array_key_exists('password_hash',$b)){fail('E ไม่มีรหัสผ่าน ใช้ Google OAuth เท่านั้น');}
 $dep=id_value($b,'department_id');exists_id('departments','department_id',$dep);
 $values=['full_name'=>text_value($b,'full_name',100),'email'=>$email,'google_uid'=>optional_text($b,'google_uid',50),'phone'=>optional_text($b,'phone',15),'department_id'=>$dep,'status'=>status_value($b)];
 if(!isset($b['employee_id'])){$values['created_date']=date('Y-m-d');}
 $id=persist('employees','employee_id',$values,$b);break;
case 'area':
 $dep=id_value($b,'department_id');exists_id('departments','department_id',$dep);$p=$b['polygon_coordinates'] ?? null;
 if(is_string($p)){$p=json_decode($p,true);}if(!is_array($p)||!array_is_list($p)||!polygon_valid($p)){fail('Polygon ต้องมี 3–200 จุด ไม่ซ้ำ ไม่ตัดกัน และมีพื้นที่');}
 $values=['area_name'=>text_value($b,'area_name',100),'department_id'=>$dep,'polygon_coordinates'=>json_encode($p),'center_latitude'=>number_value($b,'center_latitude',-90,90),'center_longitude'=>number_value($b,'center_longitude',-180,180),'status'=>status_value($b)];
 if(!isset($b['area_id'])){$values['created_date']=date('Y-m-d H:i:s');}$id=persist('geofence_areas','area_id',$values,$b);break;
case 'assignment':
 $employee=id_value($b,'employee_id');$area=id_value($b,'area_id');exists_id('employees','employee_id',$employee);exists_id('geofence_areas','area_id',$area);
 query('SELECT employee_id FROM employees WHERE employee_id=? FOR UPDATE',[$employee]);
 if(isset($b['employee_area_id'])){$old=query('SELECT employee_id FROM employee_work_areas WHERE employee_area_id=? FOR UPDATE',[id_value($b,'employee_area_id')])->fetch();if(!$old||$old['employee_id']!==$employee){fail('ไม่สามารถย้าย assignment ไปพนักงานอื่น');}}
 $start=date_value($b,'effective_date');$end=optional_text($b,'end_date',10);if($end!==null&&(!valid_date($end)||$end<$start)){fail('ช่วงวันมอบหมายไม่ถูกต้อง');}
 $primary=$b['is_primary'] ?? false;if(!in_array($primary,[true,false,1,0,'1','0'],true)){fail('is_primary ต้องเป็น boolean');}$primary=(int)(bool)$primary;$status=status_value($b);
 if($primary&&$status==='active'&&query("SELECT employee_area_id FROM employee_work_areas WHERE employee_id=? AND status='active' AND is_primary=1 AND employee_area_id<>?",[$employee,$b['employee_area_id'] ?? ''])->fetch()){fail('พนักงานมีพื้นที่หลักที่ active อยู่แล้ว กรุณาแก้ไขรายการเดิมก่อน',409);}
 $id=persist('employee_work_areas','employee_area_id',['employee_id'=>$employee,'area_id'=>$area,'is_primary'=>$primary,'effective_date'=>$start,'end_date'=>$end,'status'=>$status],$b);break;
case 'department':
 roles($u,['admin']);$v=['department_name'=>text_value($b,'department_name',100),'department_code'=>text_value($b,'department_code',20),'description'=>optional_text($b,'description'),'status'=>status_value($b)];if(!isset($b['department_id'])){$v['created_date']=date('Y-m-d');}$id=persist('departments','department_id',$v,$b);break;
case 'setting':
 roles($u,['admin']);$v=['config_name'=>text_value($b,'config_name',100),'config_type'=>text_value($b,'config_type',20),'start_time'=>optional_text($b,'start_time',8),'start_late'=>optional_text($b,'start_late',8),'description'=>optional_text($b,'description'),'updated_date'=>date('Y-m-d H:i:s')];
 foreach(['start_time','start_late'] as $key){if($v[$key]!==null&&!preg_match('/^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$/D',$v[$key])){fail('เวลาไม่ถูกต้อง');}}
 if($v['config_type']==='attendance'&&(!$v['start_time']||!$v['start_late']||$v['start_late']<$v['start_time'])){fail('เกณฑ์มาสายต้องไม่ก่อนเวลาเริ่มงาน');}
 if($v['config_type']==='attendance'&&query("SELECT config_id FROM system_configurations WHERE config_type='attendance' AND config_id<>?",[$b['config_id'] ?? ''])->fetch()){fail('มีการตั้งเวลา attendance แล้ว กรุณาแก้ไขรายการเดิม',409);}
 $id=persist('system_configurations','config_id',$v,$b);break;
case 'admin':case 'hr':case 'supervisor':
 roles($u,['admin']);[$table,$key]=identity_spec($kind);$email=text_value($b,'email',100);if(!filter_var($email,FILTER_VALIDATE_EMAIL)){fail('อีเมลไม่ถูกต้อง');}
 $v=['full_name'=>text_value($b,'full_name',100),'username'=>text_value($b,'username',50),'email'=>$email,'phone'=>optional_text($b,'phone',15),'status'=>status_value($b)];
 if($kind==='supervisor'){$v['department_id']=id_value($b,'department_id');exists_id('departments','department_id',$v['department_id']);}
 if(!isset($b[$key])||isset($b['password'])){$password=text_value($b,'password',72);if(strlen($password)<8){fail('รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร');}$v['password_hash']=password_hash($password,PASSWORD_DEFAULT);}
 if(!isset($b[$key])){$v['created_date']=date('Y-m-d');}
 if($kind==='admin'&&($b[$key] ?? '')===$u['id']&&$v['status']!=='active'){fail('ไม่สามารถปิดบัญชีตนเอง');}
 $id=persist($table,$key,$v,$b);break;
default:fail('รายการไม่ถูกต้อง');
}
db()->commit();respond(['id'=>$id]);
