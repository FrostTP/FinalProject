<?php
require __DIR__.'/../includes/bootstrap.php';require __DIR__.'/../includes/events.php';
$kind=input('kind');if(!in_array($kind,['attendance','biometrics'],true))abort_page(404,'ไม่พบภาพ');permit($kind);
$r=event_record($kind,input('id'));$name=basename($r[$kind==='biometrics'?'face_image':'evidence_photo']);
if(!preg_match('/^[a-f0-9]{48}\.(jpg|png)$/D',$name))abort_page(404,'ไม่พบภาพ');
$base=realpath(TG_API_ROOT.'/storage');$file=realpath(TG_API_ROOT.'/storage/'.$name);
if(!$base||!$file||dirname($file)!==$base||!is_file($file))abort_page(404,'ไม่พบภาพ');
$mime=(new finfo(FILEINFO_MIME_TYPE))->file($file);if(!in_array($mime,['image/jpeg','image/png'],true))abort_page(404,'ไม่พบภาพ');
header('Content-Type: '.$mime);header('Content-Disposition: inline; filename="evidence.'.($mime==='image/png'?'png':'jpg').'"');readfile($file);
