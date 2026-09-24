<?php
require_once __DIR__.'/bootstrap.php';
function face_image_bytes(array $b): string {
    $v=$b['image_base64'] ?? null;if(!is_string($v)||strlen($v)>5600000){fail('รูปใบหน้าต้องไม่เกิน 4 MB');}
    $bytes=base64_decode($v,true);if($bytes===false||strlen($bytes)>4194304){fail('รูปภาพไม่ถูกต้อง');}
    $size=@getimagesizefromstring($bytes);
    if(!$size||!in_array($size['mime'],['image/jpeg','image/png'],true)||$size[0]>4096||$size[1]>4096||$size[0]<80||$size[1]<80){fail('ต้องเป็นภาพ JPEG/PNG ขนาด 80–4096 พิกเซล');}
    return $bytes;
}
function face_call(string $path,array $data): array {
    $c=require __DIR__.'/integrations.php';
    if(strlen($c['face_service_key'])<32){fail('ยังไม่ได้ตั้งค่าบริการ Face Recognition',503);}
    $url=rtrim($c['face_service_url'],'/').'/'.$path;
    $curl=curl_init($url);curl_setopt_array($curl,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>json_encode($data),CURLOPT_HTTPHEADER=>['Content-Type: application/json','Authorization: Bearer '.$c['face_service_key']],CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>30,CURLOPT_CONNECTTIMEOUT=>5]);
    $raw=curl_exec($curl);$status=curl_getinfo($curl,CURLINFO_HTTP_CODE);curl_close($curl);
    if($raw===false||$status>=500||$status===401){fail('บริการ Face Recognition ไม่พร้อมใช้งาน',503);}
    if($status!==200){fail('ภาพใบหน้าไม่ผ่านการตรวจสอบ ต้องเห็นใบหน้าเดียวชัดเจน',422);}
    $result=json_decode($raw,true);if(!is_array($result)){fail('ข้อมูลจากบริการใบหน้าไม่ถูกต้อง',502);}return $result;
}
function valid_encoding($encoding): bool {
    if(!is_array($encoding)||count($encoding)!==128){return false;}
    foreach($encoding as $n){if(!is_numeric($n)||!is_finite((float)$n)){return false;}}return true;
}
function save_face_image(string $bytes): string {
    $name=bin2hex(random_bytes(24)).'.'.(getimagesizefromstring($bytes)['mime']==='image/png' ? 'png' : 'jpg');
    $dir=__DIR__.'/../storage';if(!is_dir($dir)){mkdir($dir,0700,true);}
    if(file_put_contents($dir.'/'.$name,$bytes,LOCK_EX)===false){throw new RuntimeException('Cannot save protected image');}
    return 'storage/'.$name;
}
