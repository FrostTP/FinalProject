<?php
function event_spec(string $section):array { return match($section){'biometrics'=>['face_biometrics','biometric_id','user_id','อนุมัติข้อมูลใบหน้า'],'offsite'=>['offsite_work_requests','offsite_request_id','employee_id','คำขอปฏิบัติงานนอกสถานที่'],'attendance'=>['attendance_logs','attendance_id','user_id','บันทึกเวลาและการอนุมัติ'],default=>throw new InvalidArgumentException('รายการไม่ถูกต้อง')}; }
function event_record(string $section,string $id,bool $lock=false):array {
 [$t,$k,$owner]=event_spec($section);[$scope,$args]=scope();
 // Never select biometric encodings into presentation code.
 $cols=$section==='biometrics'?'r.biometric_id,r.user_id,r.face_image,r.registration_date,r.approval_status,r.approved_by,r.approved_date,r.status':'r.*';
 $r=q("SELECT $cols,e.full_name employee_name,e.department_id,d.department_name FROM `$t` r JOIN employees e ON e.employee_id=r.`$owner` JOIN departments d ON d.department_id=e.department_id WHERE r.`$k`=?".$scope.($lock?' FOR UPDATE':''),[$id,...$args])->fetch();
 if(!$r)abort_page(404,'ไม่พบข้อมูลหรือไม่มีสิทธิ์เข้าถึง');return $r;
}
function review_event(string $section,string $id,string $decision):void {
 permit($section.'.write');if(!in_array($decision,['approve','reject'],true))throw new InvalidArgumentException('ผลการพิจารณาไม่ถูกต้อง');
 [$t,$k,$owner]=event_spec($section);db()->beginTransaction();$GLOBALS['web_transaction']=true;
 try {
  $r=event_record($section,$id,true);
  if(!in_array($r['approval_status'],['pending','รออนุมัติ'],true)||($section==='biometrics'&&$r['status']!=='active'))throw new InvalidArgumentException('รายการนี้พิจารณาแล้วหรือไม่ได้ใช้งาน');
  $status=$section==='biometrics'?($decision==='approve'?'approved':'rejected'):($decision==='approve'?'อนุมัติ':'ปฏิเสธ');
  q("UPDATE `$t` SET approval_status=?,approved_by=?,approved_date=NOW() WHERE `$k`=?",[$status,current_user()['user_id'],$id]);
  q('INSERT INTO tech_notifications(employee_id,title,body) VALUES(?,?,?)',[$r[$owner],'แจ้งผลการอนุมัติ',$status]);
  audit($decision,$section,$id,['approval_status','approved_by','approved_date']);db()->commit();
 }catch(Throwable $ex){if(db()->inTransaction())db()->rollBack();throw $ex;}
}
function event_filters(string $section):array {
 [$scope,$args]=scope();$where=' WHERE 1=1'.$scope;
 foreach(['department'=>'e.department_id','employee'=>'e.employee_id','approval'=>'r.approval_status'] as $param=>$col){$v=input($param);if($v!==''){$where.=" AND $col=?";$args[]=$v;}}
 if($section==='attendance') {
  $from=input('from',date('Y-m-01'));$to=input('to',date('Y-m-d'));
  foreach([$from,$to] as $v){$d=DateTimeImmutable::createFromFormat('!Y-m-d',$v);if(!$d||$d->format('Y-m-d')!==$v)throw new InvalidArgumentException('ช่วงวันที่ไม่ถูกต้อง');}
  if($from>$to)throw new InvalidArgumentException('วันเริ่มต้องไม่หลังวันสิ้นสุด');
  $where.=' AND r.check_datetime>=? AND r.check_datetime<DATE_ADD(?,INTERVAL 1 DAY)';array_push($args,$from,$to);
  foreach(['area'=>'r.area_id','check_type'=>'r.check_type','late'=>'r.is_late','zone'=>'r.zone_status'] as $param=>$col){$v=input($param);if($v!==''){$where.=" AND $col=?";$args[]=$v;}}
 }
 return [$where,$args];
}
function event_columns(string $section):array {return match($section){
 'biometrics'=>['employee_name'=>'พนักงาน','registration_date'=>'วันที่ลงทะเบียน','approval_status'=>'การอนุมัติ','status'=>'สถานะ'],
 'offsite'=>['employee_name'=>'พนักงาน','request_date'=>'วันที่ขอ','work_date_start'=>'เริ่มปฏิบัติงาน','work_date_end'=>'สิ้นสุด','location_description'=>'สถานที่','reason'=>'เหตุผล','approval_status'=>'การอนุมัติ'],
 'attendance'=>['employee_name'=>'พนักงาน','check_datetime'=>'วัน / เวลา','check_type'=>'ประเภท','area_name'=>'พื้นที่','zone_status'=>'สถานะพื้นที่','is_late'=>'มาสาย','verification_method'=>'วิธียืนยัน','approval_status'=>'การอนุมัติ']};}
function filter_form(string $section):void {
 [$s,$a]=scope();$employees=q('SELECT e.employee_id,e.full_name FROM employees e WHERE 1=1'.$s.' ORDER BY e.full_name',$a)->fetchAll(PDO::FETCH_KEY_PAIR);
 $departments=current_user()['role']==='supervisor'?q('SELECT department_id,department_name FROM departments WHERE department_id=?',[current_user()['department_id']])->fetchAll(PDO::FETCH_KEY_PAIR):field_options(['','department']);
 $filters=['employee'=>['พนักงาน',$employees],'department'=>['แผนก',$departments],'approval'=>['การอนุมัติ',$section==='biometrics'?['pending'=>'รออนุมัติ','approved'=>'อนุมัติ','rejected'=>'ปฏิเสธ']:['รออนุมัติ'=>'รออนุมัติ','อนุมัติ'=>'อนุมัติ','ปฏิเสธ'=>'ปฏิเสธ']]];
 if($section==='attendance'){$filters+=['check_type'=>['ประเภท',['เข้างาน'=>'เข้างาน','ออกงาน'=>'ออกงาน']],'late'=>['มาสาย',['1'=>'มาสาย','0'=>'ไม่สาย']],'zone'=>['พื้นที่',['inside'=>'ในพื้นที่','outside'=>'นอกพื้นที่']]];if(current_user()['role']!=='supervisor')$filters['area']=['พื้นที่ปฏิบัติงาน',field_options(['','area'])];else $filters['area']=['พื้นที่ปฏิบัติงาน',q('SELECT DISTINCT g.area_id,g.area_name FROM geofence_areas g JOIN employee_work_areas ea ON ea.area_id=g.area_id JOIN employees e ON e.employee_id=ea.employee_id WHERE e.department_id=?',[current_user()['department_id']])->fetchAll(PDO::FETCH_KEY_PAIR)];}
 ?><form method="get" class="filter-form no-print mb-4"><input type="hidden" name="report" value="<?=e(input('report','summary'))?>"><?php if($section==='attendance'):foreach(['from'=>'ตั้งแต่วันที่','to'=>'ถึงวันที่'] as $key=>$label):?><label><?=e($label)?><input class="form-control mt-1" type="date" name="<?=$key?>" value="<?=e(input($key,$key==='from'?date('Y-m-01'):date('Y-m-d')))?>" required></label><?php endforeach;endif;?><?php foreach($filters as $key=>[$label,$options]):?><label><?=e($label)?><select class="form-select mt-1" name="<?=e($key)?>"><option value="">ทั้งหมด</option><?php foreach($options as $value=>$text):?><option value="<?=e($value)?>" <?=input($key)===(string)$value?'selected':''?>><?=e($text)?></option><?php endforeach;?></select></label><?php endforeach;?><button class="btn btn-primary">แสดงข้อมูล</button><a class="btn btn-outline-secondary" href="?">ล้างตัวกรอง</a></form><?php
}
