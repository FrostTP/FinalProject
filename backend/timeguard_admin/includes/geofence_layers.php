<?php
// Display-layer metadata only. Core G and EA retain their approved meanings.
function campus_layer_file(): string { return __DIR__.'/../config/campus-layer.local.json'; }
function campus_area_id(): string {
    $file=campus_layer_file();
    if(!is_file($file))return '';
    $data=json_decode((string)file_get_contents($file),true);
    return is_array($data)&&is_string($data['area_id']??null)?$data['area_id']:'';
}
function geofence_layers(string $exclude=''): array {
    $rows=q("SELECT g.area_id,g.area_name,g.department_id,g.polygon_coordinates,d.department_name FROM geofence_areas g JOIN departments d ON d.department_id=g.department_id WHERE g.status='active' ORDER BY d.department_name,g.area_name")->fetchAll();
    $campus=campus_area_id();$layers=[];
    foreach($rows as $row){
        if($row['area_id']===$exclude)continue;
        $polygon=json_decode($row['polygon_coordinates'],true);
        if(!is_array($polygon)||!polygon_valid($polygon))continue;
        unset($row['polygon_coordinates']);$row['polygon']=$polygon;
        $row['kind']=$row['area_id']===$campus?'campus':'department';
        $layers[]=$row;
    }
    return $layers;
}
