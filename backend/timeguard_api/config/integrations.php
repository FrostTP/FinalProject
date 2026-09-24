<?php
$c=['google_client_id'=>'','face_service_url'=>'http://127.0.0.1:8091','face_service_key'=>''];
if(is_file(__DIR__.'/integrations.local.php')){$c=array_replace($c,require __DIR__.'/integrations.local.php');}
foreach(array_keys($c) as $key){$v=getenv('TIMEGUARD_'.strtoupper($key));if($v!==false){$c[$key]=$v;}}
return $c;
