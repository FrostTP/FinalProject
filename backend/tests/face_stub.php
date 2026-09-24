<?php
// Test process ONLY; not deployed under timeguard_api. Does not implement face recognition.
header('Content-Type: application/json');
if(($_SERVER['HTTP_AUTHORIZATION'] ?? '')!=='Bearer '.getenv('TIMEGUARD_FACE_SERVICE_KEY')){http_response_code(401);echo '{}';exit;}
$body=json_decode(file_get_contents('php://input'),true);
if($_SERVER['REQUEST_URI']==='/encode'){echo json_encode(['encoding'=>array_fill(0,128,0.1)]);}
elseif($_SERVER['REQUEST_URI']==='/verify'){echo json_encode(['verified'=>hash('sha256',$body['image_base64'] ?? '')===getenv('TIMEGUARD_TEST_IMAGE_HASH')]);}
else{http_response_code(404);echo '{}';}
