<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();
$r=query("SELECT COUNT(DISTINCT DATE(check_datetime)) present,COALESCE(SUM(is_late),0) late FROM attendance_logs WHERE user_id=? AND check_type='เข้างาน' AND check_datetime>=DATE_FORMAT(CURDATE(),'%Y-%m-01') AND check_datetime<NOW()",[$u['id']])->fetch();
$r['absent']=null;respond($r); // DD has no work-calendar or absence table: do not invent absence counts.
