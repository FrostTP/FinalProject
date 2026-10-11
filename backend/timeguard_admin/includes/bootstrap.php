<?php
declare(strict_types=1);
date_default_timezone_set('Asia/Bangkok');
header('Cache-Control: no-store'); header('X-Content-Type-Options: nosniff'); header('X-Frame-Options: DENY'); header('Referrer-Policy: strict-origin-when-cross-origin');
header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://tile.openstreetmap.org; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
ini_set('session.use_strict_mode','1'); ini_set('session.use_only_cookies','1');
session_name('timeguard_admin');
session_set_cookie_params(['httponly'=>true,'secure'=>(!empty($_SERVER['HTTPS'])&&$_SERVER['HTTPS']!=='off'),'samesite'=>'Lax','path'=>'/']);
session_start();
require_once __DIR__.'/../config/database.php'; require_once __DIR__.'/../config/auth.php';
function e(mixed $v): string { return htmlspecialchars((string)($v??''),ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8'); }
function url(string $path=''): string {
    $root=str_replace('\\','/',realpath(dirname(__DIR__)));
    $script=str_replace('\\','/',$_SERVER['SCRIPT_FILENAME']);
    $relative=substr($script,strlen($root));
    $base=substr($_SERVER['SCRIPT_NAME'],0,-strlen($relative));
    return $base.'/'.ltrim($path,'/');
}
function redirect(string $path): never { header('Location: '.url($path)); exit; }
function abort_page(int $code,string $message): never { http_response_code($code); echo '<!doctype html><html lang="th"><meta charset="utf-8"><title>TimeGuard</title><h1>'.e($message).'</h1><a href="'.e(url()).'">กลับหน้าหลัก</a></html>'; exit; }
set_exception_handler(function(Throwable $ex): void { if (isset($GLOBALS['web_transaction']) && db()->inTransaction()) db()->rollBack(); error_log((string)$ex); abort_page(500,'ระบบไม่พร้อมใช้งาน กรุณาตรวจการเชื่อมต่อฐานข้อมูลหรือติดต่อผู้ดูแล'); });
function flash(string $message): void { $_SESSION['flash']=$message; }
function scalar(string $sql,array $args=[]): mixed { return q($sql,$args)->fetchColumn(); }
function input(string $key,string $default=''): string { $v=$_POST[$key]??$_GET[$key]??$default; if (!is_string($v)) throw new InvalidArgumentException('ข้อมูลไม่ถูกต้อง'); return trim($v); }
function badge(mixed $v): string { $labels=['active'=>'ใช้งาน','inactive'=>'ปิดใช้งาน','approved'=>'อนุมัติ','rejected'=>'ปฏิเสธ','pending'=>'รออนุมัติ','inside'=>'ในพื้นที่','outside'=>'นอกพื้นที่']; $s=(string)$v; $tone=in_array($s,['active','approved','อนุมัติ','inside'])?'success':(in_array($s,['rejected','ปฏิเสธ','outside'])?'danger':'secondary'); return '<span class="badge text-bg-'.$tone.'">'.e($labels[$s]??$s).'</span>'; }
