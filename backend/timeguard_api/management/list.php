<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=user();roles($u,['supervisor','hr','admin']);$kind=$_GET['kind'] ?? 'requests';
$scope=$u['role']==='supervisor' ? ' AND e.department_id=?' : '';$args=$scope ? [$u['profile']['department_id']] : [];
switch($kind){
case 'requests':respond(query('SELECT o.*,e.full_name employee_name FROM offsite_work_requests o JOIN employees e ON e.employee_id=o.employee_id WHERE 1=1'.$scope.' ORDER BY request_date DESC LIMIT 200',$args)->fetchAll());
case 'attendance':
 $from=date_value($_GET+['from'=>date('Y-m-01')],'from');$to=date_value($_GET+['to'=>date('Y-m-d')],'to');if($from>$to){fail('ช่วงวันไม่ถูกต้อง');}
 respond(query('SELECT a.*,e.full_name employee_name FROM attendance_logs a JOIN employees e ON e.employee_id=a.user_id WHERE check_datetime>=? AND check_datetime<DATE_ADD(?,INTERVAL 1 DAY)'.$scope.' ORDER BY check_datetime DESC LIMIT 1000',array_merge([$from,$to],$args))->fetchAll());
case 'biometrics':roles($u,['hr']);respond(query('SELECT f.biometric_id,f.user_id,f.face_image,f.registration_date,f.approval_status,f.approved_by,f.approved_date,f.status,e.full_name employee_name FROM face_biometrics f JOIN employees e ON e.employee_id=f.user_id ORDER BY registration_date DESC')->fetchAll());
case 'employees':roles($u,['hr','admin']);respond(query('SELECT * FROM employees ORDER BY employee_id')->fetchAll());
case 'areas':roles($u,['hr','admin']);respond(query('SELECT * FROM geofence_areas ORDER BY area_id')->fetchAll());
case 'assignments':roles($u,['hr','admin']);respond(query('SELECT * FROM employee_work_areas ORDER BY employee_id,is_primary DESC')->fetchAll());
case 'departments':roles($u,['hr','admin']);respond(query('SELECT * FROM departments ORDER BY department_id')->fetchAll());
case 'settings':roles($u,['admin']);respond(query('SELECT * FROM system_configurations ORDER BY config_id')->fetchAll());
case 'admins':case 'hrs':case 'supervisors':
 roles($u,['admin']);[$table,$id]=identity_spec(['admins'=>'admin','hrs'=>'hr','supervisors'=>'supervisor'][$kind]);
 $rows=query("SELECT * FROM `$table` ORDER BY `$id`")->fetchAll();foreach($rows as &$row){unset($row['password_hash']);}respond($rows);
default:fail('รายการไม่ถูกต้อง');
}
