<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();$id=id_value($_GET,'offsite_request_id');$r=query('SELECT * FROM offsite_work_requests WHERE offsite_request_id=? AND employee_id=?',[$id,$u['id']])->fetch();if(!$r){fail('ไม่พบคำขอ',404);}respond($r);
