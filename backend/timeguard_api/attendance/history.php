<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();$month=$_GET['month'] ?? date('Y-m');
if(!is_string($month)||!preg_match('/^\d{4}-(0[1-9]|1[0-2])$/D',$month)){fail('เดือนไม่ถูกต้อง');}
respond(query('SELECT * FROM attendance_logs WHERE user_id=? AND check_datetime>=? AND check_datetime<DATE_ADD(?,INTERVAL 1 MONTH) ORDER BY check_datetime DESC,attendance_id DESC',[$u['id'],$month.'-01',$month.'-01'])->fetchAll());
