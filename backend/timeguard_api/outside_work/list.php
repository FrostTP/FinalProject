<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();
$filter=($_GET['active'] ?? '')==='1' ? " AND approval_status='อนุมัติ' AND work_date_start<=CURDATE() AND work_date_end>=CURDATE()" : '';
respond(query('SELECT * FROM offsite_work_requests WHERE employee_id=?'.$filter.' ORDER BY request_date DESC LIMIT 200',[$u['id']])->fetchAll());
