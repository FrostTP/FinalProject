<?php
declare(strict_types=1);
function identity(string $role): array { return match($role) { 'admin'=>['admins','admin_id'], 'hr'=>['human_resources','hr_id'], 'supervisor'=>['supervisors','supervisor_id'], default=>throw new InvalidArgumentException('บทบาทไม่ถูกต้อง') }; }
function current_user(): ?array {
    static $loaded=false,$user=null;
    if ($loaded) return $user;
    $loaded=true; $s=$_SESSION['user']??null;
    if (!$s || time()-($_SESSION['last_seen']??0)>1800 || time()-($_SESSION['started']??0)>28800) { unset($_SESSION['user']); return null; }
    [$table,$key]=identity($s['role']);
    $row=q("SELECT * FROM `$table` WHERE `$key`=? AND status='active'",[$s['user_id']])->fetch();
    if (!$row || !hash_equals($_SESSION['credential_version']??'',hash('sha256',$row['password_hash']))) { unset($_SESSION['user']); return null; }
    unset($row['password_hash']); $_SESSION['last_seen']=time();
    return $user=$row+['user_id'=>$row[$key],'role'=>$s['role']];
}
function require_login(): array { $u=current_user(); if (!$u) redirect('auth/login.php'); return $u; }
function allowed(string $cap): bool {
    $rules=[
        'dashboard'=>['admin','hr','supervisor'],'employees'=>['admin','hr','supervisor'],
        'employees.write'=>['hr'],'employees.link'=>['admin','hr'],
        'departments'=>['admin','hr'],'departments.write'=>['admin','hr'],
        'admins'=>['admin'],'admins.write'=>['admin'],'hr'=>['admin'],'hr.write'=>['admin'],
        'supervisors'=>['admin'],'supervisors.write'=>['admin'],
        'geofences'=>['admin','hr'],'geofences.write'=>['hr'],
        'work_areas'=>['admin','hr'],'work_areas.write'=>['hr'],
        'biometrics'=>['hr'],'biometrics.write'=>['hr'],
        'offsite'=>['admin','hr','supervisor'],'offsite.write'=>['supervisor'],
        'attendance'=>['admin','hr','supervisor'],'attendance.write'=>['supervisor'],
        'reports'=>['admin','hr','supervisor'],'settings'=>['admin'],'settings.write'=>['admin']
    ];
    return in_array(current_user()['role']??'',$rules[$cap]??[],true);
}
function permit(string $cap): void { require_login(); if (!allowed($cap)) abort_page(403,'คุณไม่มีสิทธิ์ดำเนินการนี้'); }
function scope(string $alias='e'): array { $u=require_login(); return $u['role']==='supervisor' ? [" AND $alias.department_id=?",[$u['department_id']]] : ['',[]]; }
function csrf(): string { return $_SESSION['csrf']??=bin2hex(random_bytes(32)); }
function csrf_field(): void { echo '<input type="hidden" name="csrf" value="'.e(csrf()).'">'; }
function check_csrf(): void { if ($_SERVER['REQUEST_METHOD']!=='POST') abort_page(405,'ต้องใช้ POST'); if (!is_string($_POST['csrf']??null)||!hash_equals(csrf(),$_POST['csrf'])) abort_page(419,'แบบฟอร์มหมดอายุ กรุณาโหลดหน้าใหม่'); }
function throttle_login(string $role,string $username): string {
    $key=hash('sha256','web:'.$role.':'.$username.':'.($_SERVER['REMOTE_ADDR']??''));
    db()->beginTransaction();
    q('INSERT IGNORE INTO tech_login_attempts VALUES(?,0,NOW())',[$key]);
    $r=q('SELECT * FROM tech_login_attempts WHERE attempt_key=? FOR UPDATE',[$key])->fetch();
    if (strtotime($r['window_start'])<time()-900) { q('UPDATE tech_login_attempts SET attempts=0,window_start=NOW() WHERE attempt_key=?',[$key]); $r['attempts']=0; }
    if ($r['attempts']>=10) { db()->rollBack(); throw new InvalidArgumentException('ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอ 15 นาที'); }
    q('UPDATE tech_login_attempts SET attempts=attempts+1 WHERE attempt_key=?',[$key]); db()->commit(); return $key;
}
