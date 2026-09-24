<?php
// Isolated DB only. Synthetic employee tokens and a private face-service stub are test fixtures.
// This validates contracts/authorization, NOT live Google OAuth or biometric accuracy.
declare(strict_types=1);date_default_timezone_set('Asia/Bangkok');
$c=require __DIR__.'/../timeguard_api/config/database.php';$name='timeguard_test_'.bin2hex(random_bytes(5));
$pdo=new PDO("mysql:host={$c['host']};port={$c['port']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$servers=[];$count=0;$storage=realpath(__DIR__.'/../timeguard_api/storage');$oldFiles=glob($storage.'/*');
function check(bool $value,string $name): void {global $count;if(!$value){throw new RuntimeException($name);}echo "PASS $name\n";$count++;}
function api(string $path,?array $body=null,?string $token=null,int $expected=200): mixed {
 global $count;$headers="Content-Type: application/json\r\n".($token?"Authorization: Bearer $token\r\n":'');$ctx=stream_context_create(['http'=>['method'=>$body===null?'GET':'POST','header'=>$headers,'content'=>$body===null?'':json_encode($body),'ignore_errors'=>true,'timeout'=>40]]);
 $raw=file_get_contents('http://127.0.0.1:18764/'.$path,false,$ctx);preg_match('/\s(\d{3})\s/',$http_response_header[0],$m);$data=json_decode($raw,true,32,JSON_THROW_ON_ERROR);
 if((int)$m[1]!==$expected){throw new RuntimeException("$path expected $expected got {$m[1]}: $raw");}echo "PASS $path ($expected)\n";$count++;return $data['data'];
}
function png(int $byte): string { // Synthetic 80x80 PNG, never a real person's face.
 $chunk=static fn($type,$data)=>pack('N',strlen($data)).$type.$data.pack('N',crc32($type.$data));
 return base64_encode("\x89PNG\r\n\x1a\n".$chunk('IHDR',pack('NNCCCCC',80,80,8,2,0,0,0)).$chunk('IDAT',gzcompress(str_repeat("\0".str_repeat(chr($byte),80*3),80))).$chunk('IEND',''));
}
function fixture_token(PDO $db,string $employee): string {$token=bin2hex(random_bytes(32));$s=$db->prepare('INSERT INTO tech_auth_tokens(token_hash,employee_id,expires_at) VALUES(?,?,DATE_ADD(NOW(),INTERVAL 1 HOUR))');$s->execute([hash('sha256',$token),$employee]);return $token;}
try {
 $pdo->exec(str_replace('timeguard_db',$name,file_get_contents(__DIR__.'/../timeguard_api/database/timeguard.sql')));putenv('TIMEGUARD_DB_NAME='.$name);putenv('TIMEGUARD_GOOGLE_CLIENT_ID=');
 // Exercise migration from original aliases, including retained foreign keys/data.
 $tableNames=require __DIR__.'/../timeguard_api/config/table_names.php';
 $before=[];foreach($tableNames as $full){$before[$full]=$pdo->query("SELECT * FROM `$full`")->fetchAll(PDO::FETCH_ASSOC);}
 $reverse=[];foreach($tableNames as $alias=>$full){$reverse[]="`$full` TO `$alias`";}$pdo->exec('RENAME TABLE '.implode(', ',$reverse));
 $migration=proc_open([PHP_BINARY,__DIR__.'/../rename-core-tables.php','--apply'],[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$migrationPipes);
 $migrationOutput=stream_get_contents($migrationPipes[1]);$migrationError=stream_get_contents($migrationPipes[2]);foreach($migrationPipes as $pipe){fclose($pipe);}
 if(proc_close($migration)!==0){throw new RuntimeException('Rename migration failed: '.$migrationError);}
 foreach($tableNames as $full){check($pdo->query("SELECT * FROM `$full`")->fetchAll(PDO::FETCH_ASSOC)===$before[$full],'rename retains '.$full.' data');}
 $image=png(0);putenv('TIMEGUARD_FACE_SERVICE_URL=http://127.0.0.1:18765');putenv('TIMEGUARD_FACE_SERVICE_KEY='.bin2hex(random_bytes(32)));putenv('TIMEGUARD_TEST_IMAGE_HASH='.hash('sha256',$image));
 foreach([[18764,['-t',realpath(__DIR__.'/../timeguard_api')]],[18765,[__DIR__.'/face_stub.php']]] as [$port,$args]){
   $servers[]=proc_open([PHP_BINARY,'-S','127.0.0.1:'.$port,...$args],[0=>['pipe','r'],1=>['file',__DIR__.'/integration-server.log','a'],2=>['file',__DIR__.'/integration-server.log','a']],$pipes);
   for($i=0;$i<40;$i++){$socket=@fsockopen('127.0.0.1',$port);if($socket){fclose($socket);break;}usleep(100000);}
 }
 require __DIR__.'/schema_contract.php';verify_schema_contract($pdo);
 $core=array_values(require __DIR__.'/../timeguard_api/config/table_names.php');foreach($core as $table){check((bool)$pdo->query("SHOW COLUMNS FROM `$table`")->fetch(),'core '.$table);}
 $columns=$pdo->query('SHOW COLUMNS FROM employees')->fetchAll(PDO::FETCH_COLUMN);check(!in_array('password_hash',$columns),'E has no password');
 $columns=$pdo->query('SHOW COLUMNS FROM attendance_logs')->fetchAll(PDO::FETCH_COLUMN);check(!in_array('check_in_time',$columns)&&in_array('check_type',$columns),'AT event contract');
 api('auth/me.php',null,null,401);api('auth/login.php',['role'=>'employee','username'=>'employee','password'=>'123456'],null,403);api('auth/google.php',['id_token'=>'untrusted'],null,503);
 $hr=api('auth/login.php',['role'=>'hr','username'=>'hr','password'=>'123456'])['token'];$admin=api('auth/login.php',['role'=>'admin','username'=>'admin','password'=>'123456'])['token'];$supervisor=api('auth/login.php',['role'=>'supervisor','username'=>'supervisor','password'=>'123456'])['token'];$employee=fixture_token($pdo,'E0001');
 api('attendance/today.php',null,$hr,403);api('management/list.php',null,$employee,403);api('management/list.php?kind=employees',null,$supervisor,403);
 $gps=['latitude'=>13.7563,'longitude'=>100.5018,'accuracy'=>10,'device_info'=>'test','image_base64'=>$image];
 api('attendance/check_in.php',$gps,$employee,403);
 $bio=api('biometric/register.php',['image_base64'=>$image],$employee);api('biometric/register.php',['image_base64'=>$image],$employee,409);
 $status=api('biometric/get_status.php',null,$employee);check(!isset($status['face_encoding']),'encoding not exposed to app');
 api('management/review.php',['kind'=>'biometrics','biometric_id'=>$bio['biometric_id'],'approval_status'=>'approved'],$admin,403);
 api('management/review.php',['kind'=>'biometrics','biometric_id'=>$bio['biometric_id'],'approval_status'=>'approved'],$hr);
 api('management/review.php',['kind'=>'biometrics','biometric_id'=>$bio['biometric_id'],'approval_status'=>'approved'],$hr,409);
 api('biometric/image.php?biometric_id='.$bio['biometric_id'],null,$hr);
 api('attendance/check_out.php',$gps,$employee,409);
 api('attendance/check_in.php',array_replace($gps,['image_base64'=>png(255)]),$employee,403);
 api('attendance/check_in.php',array_replace($gps,['latitude'=>0]),$employee,403);
 api('attendance/check_in.php',array_replace($gps,['latitude'=>91]),$employee,422);
 $pdo->exec("UPDATE employee_work_areas SET effective_date=DATE_ADD(CURDATE(),INTERVAL 1 DAY)");api('attendance/check_in.php',$gps,$employee,403);
 $pdo->exec("UPDATE employee_work_areas SET effective_date=DATE_SUB(CURDATE(),INTERVAL 1 DAY),end_date=DATE_SUB(CURDATE(),INTERVAL 1 DAY)");api('attendance/check_in.php',$gps,$employee,403);
 $pdo->exec("UPDATE employee_work_areas SET effective_date=CURDATE(),end_date=NULL,status='inactive'");api('attendance/check_in.php',$gps,$employee,403);
 $pdo->exec("UPDATE employee_work_areas SET status='active'");
 $assignment=['kind'=>'assignment','employee_id'=>'E0001','area_id'=>'G0001','is_primary'=>true,'effective_date'=>date('Y-m-d'),'status'=>'active'];
 api('management/save.php',$assignment,$hr,409);api('management/save.php',array_replace($assignment,['is_primary'=>false]),$hr);
 $in=api('attendance/check_in.php',array_replace($gps,['employee_id'=>'E_OTHER']),$employee);check($in['user_id']==='E0001','identity from token');
 api('attendance/check_in.php',$gps,$employee,409);$out=api('attendance/check_out.php',$gps,$employee);check($out['attendance_id']!==$in['attendance_id'],'separate AT ids');
 $today=api('attendance/today.php',null,$employee);check(count($today)===2&&$today[0]['check_datetime']===$in['check_datetime'],'checkout preserves checkin');api('attendance/check_out.php',$gps,$employee,409);
 api('attendance/history.php?month='.date('Y-m'),null,$employee);api('dashboard/summary.php',null,$employee);
 $request=['work_date_start'=>date('Y-m-d'),'work_date_end'=>date('Y-m-d',time()+86400),'location_description'=>'ลูกค้า','reason'=>'ประชุม'];$os=api('outside_work/create.php',$request,$employee,201);
 api('management/review.php',['kind'=>'requests','offsite_request_id'=>$os['offsite_request_id'],'approval_status'=>'อนุมัติ'],$hr,403);
 $pdo->exec("INSERT INTO departments VALUES('D0002','Other','OTHER',NULL,'active',CURDATE())");$pdo->exec("UPDATE supervisors SET department_id='D0002' WHERE supervisor_id='S0001'");
 api('management/review.php',['kind'=>'requests','offsite_request_id'=>$os['offsite_request_id'],'approval_status'=>'อนุมัติ'],$supervisor,403);
 $pdo->exec("UPDATE supervisors SET department_id='D0001' WHERE supervisor_id='S0001'");api('management/review.php',['kind'=>'requests','offsite_request_id'=>$os['offsite_request_id'],'approval_status'=>'อนุมัติ'],$supervisor);
 $pdo->exec('DELETE FROM attendance_logs');$outside=array_replace($gps,['latitude'=>0,'longitude'=>0]);$off=api('attendance/check_in.php',$outside,$employee);check($off['area_id']==='G0001'&&$off['zone_status']==='outside'&&$off['offsite_request_id']===$os['offsite_request_id'],'offsite retains assigned area and request reference');
 api('attendance/check_out.php',$outside,$employee);$pdo->exec('DELETE FROM attendance_logs');$pdo->exec('UPDATE offsite_work_requests SET work_date_start=DATE_SUB(CURDATE(),INTERVAL 2 DAY),work_date_end=DATE_SUB(CURDATE(),INTERVAL 1 DAY)');api('attendance/check_in.php',$outside,$employee,403);
 api('employee/update_profile.php',['full_name'=>'ชื่อใหม่','phone'=>'0812345678','google_uid'=>'attacker'],$employee);$me=api('auth/me.php',null,$employee);check($me['profile']['google_uid']===null,'profile cannot change Google identity');
 $notices=api('notifications/list.php',null,$employee);api('notifications/mark_read.php',['id'=>$notices[0]['id']],$employee);
 api('management/save.php',['kind'=>'employee','full_name'=>'New','email'=>'new@test.com','department_id'=>'D0001','password'=>'123456'],$hr,422);
 api('management/save.php',['kind'=>'employee','full_name'=>'New','email'=>'new@test.com','department_id'=>'D0001','google_uid'=>'12345678901234567890'],$hr);
 api('management/list.php?kind=attendance',null,$supervisor);api('auth/logout.php',[],$employee);api('auth/me.php',null,$employee,401);
 echo "SUCCESS: $count checks (Google and recognition use fixtures; not live biometric accuracy)\n";
} finally {
 foreach($servers as $server){if(is_resource($server)){proc_terminate($server);proc_close($server);}}
 foreach(array_diff(glob($storage.'/*'),$oldFiles) as $file){if(preg_match('/^[a-f0-9]{48}\.(jpg|png)$/',basename($file))){unlink($file);}}
 if(preg_match('/^timeguard_test_[a-f0-9]{10}$/D',$name)){$pdo->exec('DROP DATABASE IF EXISTS `'.$name.'`');}
}
