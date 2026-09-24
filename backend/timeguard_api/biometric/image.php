<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=user();roles($u,['employee','hr']);
$row=$u['role']==='employee'
 ? query("SELECT face_image FROM face_biometrics WHERE user_id=? AND status='active' ORDER BY registration_date DESC,biometric_id DESC LIMIT 1",[$u['id']])->fetch()
 : query('SELECT face_image FROM face_biometrics WHERE biometric_id=?',[id_value($_GET,'biometric_id')])->fetch();
if(!$row){fail('ไม่พบภาพ',404);}
$name=basename($row['face_image']);if(!preg_match('/^[a-f0-9]{48}\.(jpg|png)$/D',$name)){fail('ไม่พบภาพ',404);}
$file=__DIR__.'/../storage/'.$name;if(!is_file($file)){fail('ไม่พบภาพ',404);}respond(['image_base64'=>base64_encode(file_get_contents($file))]);
