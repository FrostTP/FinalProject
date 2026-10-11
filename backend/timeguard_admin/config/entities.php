<?php
// Static metadata: identifiers never come from request parameters.
function entities(): array {
 $status=['สถานะ','select',['active'=>'ใช้งาน','inactive'=>'ปิดใช้งาน']];
 $person=['full_name'=>['ชื่อ–นามสกุล','text',100],'email'=>['อีเมล','email',100],'phone'=>['โทรศัพท์','optional',15]];
 $staff=$person+['username'=>['ชื่อผู้ใช้','text',50],'password'=>['รหัสผ่านใหม่ (เว้นว่างเพื่อคงเดิม)','password',72],'status'=>$status];
 return [
 'employees'=>['employees','employee_id','E','พนักงาน',$person+['google_uid'=>['Google UID','optional',50],'department_id'=>['แผนก','department'],'status'=>$status]],
 'departments'=>['departments','department_id','D','แผนก',['department_name'=>['ชื่อแผนก','text',100],'department_code'=>['รหัสย่อแผนก','text',20],'description'=>['รายละเอียด','optional',255],'status'=>$status]],
 'admins'=>['admins','admin_id','A','ผู้ดูแลระบบ',$staff],
 'hr'=>['human_resources','hr_id','H','ฝ่ายบุคคล',$staff],
 'supervisors'=>['supervisors','supervisor_id','S','หัวหน้างาน',$staff+['department_id'=>['แผนกที่ดูแล','department']]],
 'geofences'=>['geofence_areas','area_id','G','พื้นที่ปฏิบัติงาน',['area_name'=>['ชื่อพื้นที่','text',100],'department_id'=>['แผนก','department'],'status'=>$status,'polygon_coordinates'=>['ขอบเขตพื้นที่','polygon']]],
 'work_areas'=>['employee_work_areas','employee_area_id','EA','กำหนดพื้นที่พนักงาน',['employee_id'=>['พนักงาน','employee'],'area_id'=>['พื้นที่ปฏิบัติงาน','area'],'is_primary'=>['ประเภทพื้นที่','select',['0'=>'พื้นที่รอง','1'=>'พื้นที่หลัก']],'effective_date'=>['วันที่เริ่มใช้งาน','date'],'end_date'=>['วันที่สิ้นสุด (ถ้ามี)','optional-date'],'status'=>$status]],
 'settings'=>['system_configurations','config_id','CFG','ตั้งค่าระบบ',['config_name'=>['ชื่อการตั้งค่า','text',100],'config_type'=>['ประเภท (attendance สำหรับเวลางาน)','text',20],'start_time'=>['เวลาเริ่มงาน','time'],'start_late'=>['เวลาเริ่มถือว่าสาย','time'],'description'=>['รายละเอียด','optional',255]]]
 ];
}
function entity_path(string $section):string { return in_array($section,['admins','hr','supervisors'])?'users/'.$section.'/':$section.'/'; }
function field_options(array $spec):array {
 return match($spec[1]) {
 'select'=>$spec[2],
 'department'=>q('SELECT department_id,CONCAT(department_name, CASE WHEN status=\'inactive\' THEN \' (ปิดใช้งาน)\' ELSE \'\' END) label FROM departments ORDER BY department_name')->fetchAll(PDO::FETCH_KEY_PAIR),
 'employee'=>q('SELECT employee_id,CONCAT(full_name,\' · \',employee_id) FROM employees ORDER BY full_name')->fetchAll(PDO::FETCH_KEY_PAIR),
 'area'=>q('SELECT area_id,CONCAT(area_name, CASE WHEN status=\'inactive\' THEN \' (ปิดใช้งาน)\' ELSE \'\' END) FROM geofence_areas ORDER BY area_name')->fetchAll(PDO::FETCH_KEY_PAIR),
 default=>[]};
}
