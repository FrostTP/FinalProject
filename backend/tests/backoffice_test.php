<?php
// Creates and drops ONLY an isolated random database. Never mutates the real database.
declare(strict_types=1);
$config=getenv('TG_TEST_CONFIG')?:'C:/xampp/htdocs/timeguard_api/config/database.php';
$c=require $config;
$pdo=new PDO("mysql:host={$c['host']};port={$c['port']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$name='timeguard_webtest_'.bin2hex(random_bytes(5)); $server=null; $count=0;$port=(int)(getenv('TG_TEST_PORT')?:18766);
$existing=@fsockopen('127.0.0.1',$port);
if($existing){fclose($existing);throw new RuntimeException('Test port already in use. Stop the preview or set TG_TEST_PORT to a free port.');}
function check(bool $ok,string $label):void { global $count; if(!$ok)throw new RuntimeException($label); echo 'PASS '.$label.PHP_EOL; $count++; }
function request(string $path,?array $data=null,array &$jar=[],int $expected=200):string {
 global $port; $ch=curl_init('http://127.0.0.1:'.$port.'/'.$path);
 curl_setopt_array($ch,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_HEADER=>true,CURLOPT_TIMEOUT=>15,CURLOPT_COOKIE=>implode('; ',array_map(fn($k,$v)=>$k.'='.$v,array_keys($jar),$jar))]);
 if($data!==null)curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>http_build_query($data)]);
 $raw=curl_exec($ch); if($raw===false)throw new RuntimeException(curl_error($ch)); $status=curl_getinfo($ch,CURLINFO_HTTP_CODE); $size=curl_getinfo($ch,CURLINFO_HEADER_SIZE); curl_close($ch);
 preg_match_all('/Set-Cookie: ([^=;]+)=([^;]*)/i',substr($raw,0,$size),$cookies,PREG_SET_ORDER); foreach($cookies as $cookie)$jar[$cookie[1]]=$cookie[2];
 check($status===$expected,$path.' HTTP '.$expected.' (actual '.$status.')'); return substr($raw,$size);
}
function token(string $html):string { preg_match('/name="csrf" value="([a-f0-9]+)"/',$html,$m); if(!isset($m[1]))throw new RuntimeException('Missing CSRF'); return $m[1]; }
function login(string $role):array { $jar=[]; $html=request('auth/login.php',null,$jar); request('auth/login.php',['csrf'=>token($html),'role'=>$role,'username'=>$role,'password'=>'123456'],$jar,302); return $jar; }
try {
 $pdo->exec(str_replace('timeguard_db',$name,file_get_contents(__DIR__.'/../timeguard_api/database/timeguard.sql')));
 $pdo->exec(file_get_contents(__DIR__.'/../timeguard_admin/database/001_web_audit.sql'));
 foreach($c as $key=>$value)putenv('TIMEGUARD_DB_'.strtoupper($key).'='.$value); putenv('TIMEGUARD_DB_NAME='.$name);
 putenv('TIMEGUARD_API_ROOT='.realpath(__DIR__.'/../timeguard_api'));
 $server=proc_open([PHP_BINARY,'-S','127.0.0.1:'.$port,'-t',realpath(__DIR__.'/../timeguard_admin')],[0=>['pipe','r'],1=>['file',__DIR__.'/backoffice-server.log','a'],2=>['file',__DIR__.'/backoffice-server.log','a']],$pipes);
 for($i=0;$i<40;$i++){ $s=@fsockopen('127.0.0.1',$port); if($s){fclose($s);break;}usleep(100000); }
 $anon=[]; request('dashboard/',null,$anon,302); request('auth/login.php',['role'=>'admin','username'=>'admin','password'=>'123456'],$anon,419);
 $admin=login('admin');$hr=login('hr');$supervisor=login('supervisor');
 foreach([$admin,$hr,$supervisor] as $jar) { $html=request('dashboard/',null,$jar);check(str_contains($html,'ภาพรวมการปฏิบัติงาน'),'dashboard rendered'); }
 if(is_file(__DIR__.'/../timeguard_admin/employees/index.php')) {
  request('employees/?edit=1',null,$admin,403);request('users/admins/',null,$hr,403);
  $h=request('employees/?edit=1',null,$hr);$csrf=token($h);
  $employee=['csrf'=>$csrf,'id'=>'','full_name'=>'Test employee','email'=>'webtest@example.com','phone'=>'','google_uid'=>'','department_id'=>'D0001','status'=>'active'];
  request('employees/',$employee,$hr,302);request('employees/',$employee,$hr,409);
  $employeeId=$pdo->query("SELECT employee_id FROM employees WHERE email='webtest@example.com'")->fetchColumn();
  check((bool)$employeeId,'employee persisted');request('employees/?id='.$employeeId,null,$hr);
  request('departments/?edit=1',null,$admin);request('users/supervisors/?edit=1',null,$admin);
  $pdo->exec("INSERT INTO departments VALUES('DOTHER','Other','OTH','', 'active',CURDATE())");
  $pdo->exec("UPDATE employees SET department_id='DOTHER' WHERE employee_id='$employeeId'");
  request('employees/?id='.$employeeId,null,$supervisor,404);
  $h=request('employees/',null,$supervisor);check(!str_contains($h,'Test employee'),'supervisor employee list scoped');
  request('employees/',array_replace($employee,['csrf'=>token($h)]),$supervisor,403);
  check((int)$pdo->query('SELECT COUNT(*) FROM tech_web_audit_logs')->fetchColumn()===1,'audit committed with employee');
  $polygon=[['lat'=>16.43,'lng'=>102.82],['lat'=>16.44,'lng'=>102.82],['lat'=>16.44,'lng'=>102.83],['lat'=>16.43,'lng'=>102.83]];
  $area=['csrf'=>$csrf,'id'=>'','area_name'=>'Web polygon','department_id'=>'D0001','status'=>'active','polygon_coordinates'=>json_encode($polygon)];
  request('geofences/?edit=1',null,$hr);request('geofences/',$area,$hr,302);
  $areaRow=$pdo->query("SELECT * FROM geofence_areas WHERE area_name='Web polygon'")->fetch(PDO::FETCH_ASSOC);
  check(abs((float)$areaRow['center_latitude']-16.435)<.000001,'polygon center calculated on server');
  request('geofences/?id='.$areaRow['area_id'].'&edit=1',null,$hr);
  request('geofences/',array_replace($area,['id'=>$areaRow['area_id'],'area_name'=>'Updated polygon']),$hr,302);
  request('geofences/',array_replace($area,['polygon_coordinates'=>'[]']),$hr,422);
  request('geofences/',array_replace($area,['polygon_coordinates'=>json_encode([$polygon[0],$polygon[2],$polygon[1],$polygon[3]])]),$hr,422);
  $h=request('dashboard/',null,$admin);request('geofences/',array_replace($area,['csrf'=>token($h)]),$admin,403);
  $assignment=['csrf'=>$csrf,'id'=>'','employee_id'=>$employeeId,'area_id'=>$areaRow['area_id'],'is_primary'=>'1','effective_date'=>'2026-01-01','end_date'=>'','status'=>'active'];
  request('work_areas/?edit=1',null,$hr);request('work_areas/',$assignment,$hr,302);
  request('work_areas/',$assignment,$hr,422);
  request('work_areas/',array_replace($assignment,['is_primary'=>'0']),$hr,422);
  request('work_areas/',array_replace($assignment,['effective_date'=>'2026-02-01','end_date'=>'2026-01-01']),$hr,422);
  $assignmentId=$pdo->query("SELECT employee_area_id FROM employee_work_areas WHERE employee_id='$employeeId'")->fetchColumn();
  request('work_areas/',array_replace($assignment,['id'=>$assignmentId,'status'=>'inactive']),$hr,302);
  request('work_areas/',array_replace($assignment,['is_primary'=>'0']),$hr,302);
 }
 if(is_file(__DIR__.'/../timeguard_admin/biometrics/index.php')) {
  $pdo->exec("INSERT INTO face_biometrics VALUES('FTEST','E0001','storage/missing.jpg','PRIVATE_ENCODING',NOW(),'pending',NULL,NULL,'active')");
  $h=request('biometrics/?id=FTEST',null,$hr);check(!str_contains($h,'PRIVATE_ENCODING'),'encoding never rendered');
  request('biometrics/',null,$admin,403);
  request('biometrics/',['csrf'=>token($h),'id'=>'FTEST','decision'=>'approve'],$hr,302);
  $row=$pdo->query("SELECT * FROM face_biometrics WHERE biometric_id='FTEST'")->fetch(PDO::FETCH_ASSOC);check($row['approval_status']==='approved'&&$row['approved_by']==='H0001','HR approval attribution');
  request('biometrics/',['csrf'=>token($h),'id'=>'FTEST','decision'=>'reject'],$hr,409);
 }
 if(is_file(__DIR__.'/../timeguard_admin/offsite/index.php')) {
  $pdo->exec("INSERT INTO offsite_work_requests VALUES('OSTEST','E0001',NOW(),CURDATE(),CURDATE(),'Client office','Meeting','รออนุมัติ',NULL,NULL)");
  $st=$pdo->prepare("INSERT INTO offsite_work_requests VALUES('OSOTHER',?,NOW(),CURDATE(),CURDATE(),'Other','Other','รออนุมัติ',NULL,NULL)");$st->execute([$employeeId]);
  $h=request('offsite/?id=OSTEST',null,$supervisor);
  request('offsite/?id=OSOTHER',null,$supervisor,404);
  request('offsite/',['csrf'=>token($h),'id'=>'OSOTHER','decision'=>'approve'],$supervisor,404);
  request('offsite/',['csrf'=>token($h),'id'=>'OSTEST','decision'=>'approve'],$supervisor,302);
  check($pdo->query("SELECT approved_by FROM offsite_work_requests WHERE offsite_request_id='OSTEST'")->fetchColumn()==='S0001','supervisor approval attribution');
 }
 if(is_file(__DIR__.'/../timeguard_admin/attendance/index.php')) {
  $st=$pdo->prepare("INSERT INTO attendance_logs VALUES(?,?, 'G0001','เข้างาน',NOW(),13.7563,100.5018,'face_recognition','outside','test',1,'storage/missing.jpg','Reason','รออนุมัติ',NULL,NULL,NULL)");$st->execute(['ATTEST','E0001']);$st->execute(['ATOTHER',$employeeId]);
  $h=request('attendance/?id=ATTEST',null,$supervisor);check(str_contains($h,'data-point='),'attendance map data rendered');
  request('attendance/?id=ATOTHER',null,$supervisor,404);request('attendance/image.php?kind=attendance&id=ATOTHER',null,$supervisor,404);
  request('attendance/',['csrf'=>token($h),'id'=>'ATTEST','decision'=>'reject'],$supervisor,302);
  check($pdo->query("SELECT approval_status FROM attendance_logs WHERE attendance_id='ATTEST'")->fetchColumn()==='ปฏิเสธ','attendance rejection');
  request('attendance/?from=bad-date',null,$hr,422);request('attendance/?zone=outside&late=1',null,$hr);
 }
 if(is_file(__DIR__.'/../timeguard_admin/reports/index.php')) {
  foreach(['summary','late','department','employee','area','offsite','abnormal'] as $report)request('reports/?report='.$report,null,$hr);
  $csv=request('reports/?export=csv',null,$supervisor);check(str_contains($csv,'ATTEST')&&!str_contains($csv,'ATOTHER'),'CSV scoped by department');
  request('reports/?print=1',null,$supervisor);request('settings/',null,$supervisor,403);
  $h=request('settings/?id=CFG0001&edit=1',null,$admin);
  $setting=['csrf'=>token($h),'id'=>'CFG0001','config_name'=>'Work time','config_type'=>'attendance','start_time'=>'08:00','start_late'=>'08:15','description'=>'Test'];
  request('settings/',$setting,$admin,302);request('settings/',array_replace($setting,['start_late'=>'07:00']),$admin,422);
  check($pdo->query("SELECT start_late FROM system_configurations WHERE config_id='CFG0001'")->fetchColumn()==='08:15:00','settings persisted');
 }
 // Security and staff CRUD checks.
 $h=request('users/hr/?edit=1',null,$admin);$adminCsrf=token($h);
 $staff=['csrf'=>$adminCsrf,'id'=>'','full_name'=>'<script>alert(1)</script>','username'=>'web_hr','password'=>'test-password-123','email'=>'hr-test@example.com','phone'=>'','status'=>'active'];
 request('users/hr/',$staff,$admin,302);$staffRow=$pdo->query("SELECT * FROM human_resources WHERE username='web_hr'")->fetch(PDO::FETCH_ASSOC);
 check(password_verify($staff['password'],$staffRow['password_hash']),'staff password hashed');
 $h=request('users/hr/?id='.$staffRow['hr_id'],null,$admin);check(str_contains($h,'&lt;script&gt;')&&!str_contains($h,'<script>alert(1)</script>'),'XSS escaped');check(!str_contains($h,$staffRow['password_hash']),'password hash not shown');
 request('users/hr/',array_replace($staff,['id'=>$staffRow['hr_id'],'password'=>'','full_name'=>'Updated HR']),$admin,302);
 check($pdo->query("SELECT password_hash FROM human_resources WHERE username='web_hr'")->fetchColumn()===$staffRow['password_hash'],'blank password preserves hash');
 request('employees/',['csrf'=>'bad'],$hr,419);request('auth/logout.php',null,$admin,405);
 $supervisorHash=password_hash('changed-test-password',PASSWORD_DEFAULT);$st=$pdo->prepare("UPDATE supervisors SET password_hash=? WHERE supervisor_id='S0001'");$st->execute([$supervisorHash]);request('dashboard/',null,$supervisor,302);
 $pdo->exec("UPDATE human_resources SET status='inactive' WHERE hr_id='H0001'");request('dashboard/',null,$hr,302);
 $html=request('dashboard/',null,$admin); request('auth/logout.php',['csrf'=>token($html)],$admin,302);request('dashboard/',null,$admin,302);
 echo "TOTAL $count checks passed\n";
 if(getenv('TG_WEB_PREVIEW')==='1'){echo "Preview ready at http://127.0.0.1:$port/ (synthetic data only). Press Enter to stop and remove test database.\n";fgets(STDIN);}
}finally { if(is_resource($server)) {proc_terminate($server);proc_close($server);} if(preg_match('/^timeguard_webtest_[a-f0-9]{10}$/D',$name))$pdo->exec("DROP DATABASE IF EXISTS `$name`"); }
