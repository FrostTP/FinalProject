<?php
require_once __DIR__.'/../config/google.php';method('POST');$b=body();
throttle(hash('sha256','google:'.($_SERVER['REMOTE_ADDR'] ?? 'unknown')));
$claims=verify_google_token(text_value($b,'id_token',12000));
// HR must provision the Google subject. Do not silently bind by email.
$row=query("SELECT * FROM employees WHERE google_uid=? AND status='active'",[$claims['sub']])->fetch();
if(!$row){fail('บัญชี Google นี้ยังไม่ผูกกับพนักงาน กรุณาแจ้ง HR พร้อม Google UID: '.$claims['sub'],403);}
respond(issue_token($row,'employee'));
