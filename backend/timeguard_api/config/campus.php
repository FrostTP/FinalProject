<?php
declare(strict_types=1);
// University boundary uses an existing G polygon selected by HR in the web UI.
function required_campus_area(): array {
    $file=getenv('TIMEGUARD_CAMPUS_LAYER_FILE')?:dirname(__DIR__,2).'/timeguard_admin/config/campus-layer.local.json';
    $config=is_file($file)?json_decode((string)file_get_contents($file),true):null;
    $id=is_array($config)?($config['area_id']??null):null;
    if(!is_string($id)||$id==='')fail('ยังไม่ได้กำหนดขอบเขตมหาวิทยาลัย กรุณาให้ HR กำหนดพื้นที่หลักก่อนลงเวลา',503);
    $area=query("SELECT area_id,polygon_coordinates FROM geofence_areas WHERE area_id=? AND status='active'",[$id])->fetch();
    if(!$area)fail('ขอบเขตมหาวิทยาลัยไม่พร้อมใช้งาน กรุณาติดต่อ HR',503);
    $polygon=json_decode($area['polygon_coordinates'],true);
    if(!is_array($polygon)||!array_is_list($polygon)||!polygon_valid($polygon))fail('ขอบเขตมหาวิทยาลัยไม่ถูกต้อง กรุณาติดต่อ HR',503);
    return ['area_id'=>$area['area_id'],'polygon'=>$polygon];
}
