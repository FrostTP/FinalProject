<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();
respond(query("SELECT biometric_id,user_id,face_image,registration_date,approval_status,approved_by,approved_date,status FROM face_biometrics WHERE user_id=? AND status='active' ORDER BY registration_date DESC,biometric_id DESC LIMIT 1",[$u['id']])->fetch() ?: ['approval_status'=>'not_registered']);
