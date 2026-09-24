<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');$u=employee();$b=body();
$start=date_value($b,'work_date_start');$end=date_value($b,'work_date_end');if($start<date('Y-m-d')||$end<$start){fail('ช่วงวันไม่ถูกต้อง');}
$location=text_value($b,'location_description',255);$reason=text_value($b,'reason',255);
db()->beginTransaction();$id=next_id('OS');query("INSERT INTO offsite_work_requests VALUES(?,?,NOW(),?,?,?,?,'รออนุมัติ',NULL,NULL)",[$id,$u['id'],$start,$end,$location,$reason]);notice($u['id'],'ส่งคำขอนอกพื้นที่แล้ว',$location);db()->commit();respond(['offsite_request_id'=>$id],'บันทึกคำขอแล้ว',201);
