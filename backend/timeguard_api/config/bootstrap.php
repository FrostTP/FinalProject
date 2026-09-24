<?php
declare(strict_types=1);
date_default_timezone_set('Asia/Bangkok');
header('Content-Type: application/json; charset=utf-8'); header('Cache-Control: no-store'); header('X-Content-Type-Options: nosniff');
require_once __DIR__.'/rules.php';
function respond($data=null,string $message='Success',int $status=200): never { http_response_code($status); echo json_encode(['success'=>$status<400,'message'=>$message,'data'=>$data],JSON_UNESCAPED_UNICODE); exit; }
function fail(string $message,int $status=422): never { if(isset($GLOBALS['pdo']) && $GLOBALS['pdo']->inTransaction()) { $GLOBALS['pdo']->rollBack(); } respond(null,$message,$status); }
set_exception_handler(function(Throwable $e){error_log((string)$e);fail('เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์ กรุณาติดต่อผู้ดูแล',500);});
function db(): PDO {
    if(!isset($GLOBALS['pdo'])) {
        $c=require __DIR__.'/database.php';
        $GLOBALS['pdo']=new PDO("mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
        $GLOBALS['pdo']->exec("SET time_zone='+07:00'");
    } return $GLOBALS['pdo'];
}
function query(string $sql,array $args=[]): PDOStatement {$s=db()->prepare($sql);$s->execute($args);return $s;}
function body(): array {
    if((int)($_SERVER['CONTENT_LENGTH'] ?? 0)>7500000) {fail('รูปภาพหรือข้อมูลมีขนาดใหญ่เกินไป',413);}
    try {$b=json_decode(file_get_contents('php://input'),true,32,JSON_THROW_ON_ERROR);}catch(JsonException $e){fail('JSON ไม่ถูกต้อง',400);}
    if(!is_array($b)){fail('JSON ไม่ถูกต้อง',400);}return $b;
}
function method(string $method): void {if($_SERVER['REQUEST_METHOD']!==$method){header('Allow: '.$method);fail('Method not allowed',405);}}
function text_value(array $b,string $key,int $max=255): string {$v=$b[$key] ?? null;if(!is_string($v)||trim($v)===''||mb_strlen(trim($v))>$max){fail('ข้อมูลไม่ถูกต้อง: '.$key);}return trim($v);}
function optional_text(array $b,string $key,int $max=255): ?string {if(!isset($b[$key])||$b[$key]===''){return null;}return text_value($b,$key,$max);}
function number_value(array $b,string $key,float $min,float $max): float {$v=$b[$key] ?? null;if(is_bool($v)||!is_numeric($v)||!is_finite((float)$v)||$v<$min||$v>$max){fail('ข้อมูลไม่ถูกต้อง: '.$key);}return (float)$v;}
function id_value(array $b,string $key='id'): string {$v=text_value($b,$key,10);if(!preg_match('/^[A-Za-z0-9_-]{1,10}$/D',$v)){fail('รหัสไม่ถูกต้อง: '.$key);}return $v;}
function next_id(string $prefix): string {
    query('INSERT INTO tech_id_sequences(prefix,next_value) VALUES(?,LAST_INSERT_ID(1001)) ON DUPLICATE KEY UPDATE next_value=LAST_INSERT_ID(next_value+1)',[$prefix]);
    $number=(string)db()->lastInsertId(); if(strlen($number)>10-strlen($prefix)){fail('รหัสเต็ม กรุณาติดต่อผู้ดูแล',503);}
    return $prefix.str_pad($number,10-strlen($prefix),'0',STR_PAD_LEFT);
}
function identity_spec(string $role): array {
    return match($role){'employee'=>['employees','employee_id'],'admin'=>['admins','admin_id'],'hr'=>['human_resources','hr_id'],'supervisor'=>['supervisors','supervisor_id'],default=>throw new InvalidArgumentException('Invalid role')};
}
function public_user(array $row,string $role): array {unset($row['password_hash']);[$table,$key]=identity_spec($role);return ['role'=>$role,'id'=>$row[$key],'profile'=>$row];}
function bearer_hash(): string {$h=$_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';if(!preg_match('/^Bearer ([a-f0-9]{64})$/i',$h,$m)){fail('กรุณาเข้าสู่ระบบ',401);}return hash('sha256',$m[1]);}
function user(): array {
    $t=query('SELECT * FROM tech_auth_tokens WHERE token_hash=? AND expires_at>NOW()',[bearer_hash()])->fetch();
    if(!$t){fail('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',401);}
    foreach(['employee','admin','hr','supervisor'] as $role){[$table,$key]=identity_spec($role);if($t[$key]!==null){$u=query("SELECT * FROM `$table` WHERE `$key`=? AND status='active'",[$t[$key]])->fetch();if(!$u){fail('บัญชีไม่พร้อมใช้งาน',401);}return public_user($u,$role);}}
    fail('เซสชันไม่ถูกต้อง',401);
}
function roles(array $u,array $roles): void {if(!in_array($u['role'],$roles,true)){fail('ไม่มีสิทธิ์ใช้งาน',403);}}
function employee(): array {$u=user();roles($u,['employee']);return $u;}
function issue_token(array $row,string $role): array {[$table,$key]=identity_spec($role);$token=bin2hex(random_bytes(32));query("INSERT INTO tech_auth_tokens(token_hash,`$key`,expires_at) VALUES(?,?,DATE_ADD(NOW(),INTERVAL 7 DAY))",[hash('sha256',$token),$row[$key]]);return ['token'=>$token,'user'=>public_user($row,$role)];}
function notice(string $employeeId,string $title,string $body): void {query('INSERT INTO tech_notifications(employee_id,title,body) VALUES(?,?,?)',[$employeeId,$title,$body]);}
function valid_date(string $v): bool {$d=DateTimeImmutable::createFromFormat('!Y-m-d',$v);return $d && $d->format('Y-m-d')===$v;}
function date_value(array $b,string $key): string {$v=text_value($b,$key,10);if(!valid_date($v)){fail('วันไม่ถูกต้อง: '.$key);}return $v;}
function active_areas(string $id): array {return query("SELECT g.*,ea.employee_area_id,ea.is_primary,ea.effective_date,ea.end_date FROM employee_work_areas ea JOIN geofence_areas g ON g.area_id=ea.area_id WHERE ea.employee_id=? AND ea.status='active' AND g.status='active' AND ea.effective_date<=CURDATE() AND (ea.end_date IS NULL OR ea.end_date>=CURDATE()) ORDER BY ea.is_primary DESC,ea.employee_area_id",[$id])->fetchAll();}
function today_events(string $id): array {return query('SELECT * FROM attendance_logs WHERE user_id=? AND check_datetime>=CURDATE() AND check_datetime<DATE_ADD(CURDATE(),INTERVAL 1 DAY) ORDER BY check_datetime,attendance_id',[$id])->fetchAll();}
function throttle(string $key): void {
    db()->beginTransaction();query('INSERT IGNORE INTO tech_login_attempts VALUES(?,0,NOW())',[$key]);
    $r=query('SELECT * FROM tech_login_attempts WHERE attempt_key=? FOR UPDATE',[$key])->fetch();
    if(strtotime($r['window_start'])<time()-900){query('UPDATE tech_login_attempts SET attempts=0,window_start=NOW() WHERE attempt_key=?',[$key]);$r['attempts']=0;}
    if($r['attempts']>=10){fail('ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอ 15 นาที',429);}
    query('UPDATE tech_login_attempts SET attempts=attempts+1 WHERE attempt_key=?',[$key]);db()->commit();
}
