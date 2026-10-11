<?php
require __DIR__.'/../includes/bootstrap.php';require __DIR__.'/../includes/repository.php';require __DIR__.'/../includes/events.php';permit('reports');$section='reports';$title='รายงานการปฏิบัติงาน';
try{[$where,$args]=event_filters('attendance');}catch(InvalidArgumentException $ex){abort_page(422,$ex->getMessage());}
$join=' FROM attendance_logs r JOIN employees e ON e.employee_id=r.user_id JOIN departments d ON d.department_id=e.department_id LEFT JOIN geofence_areas g ON g.area_id=r.area_id';
$mode=input('report','summary');$modes=['summary'=>'สรุปการลงเวลา','late'=>'พนักงานมาสาย','department'=>'แยกตามแผนก','employee'=>'แยกตามพนักงาน','area'=>'แยกตามพื้นที่','offsite'=>'ปฏิบัติงานนอกสถานที่','abnormal'=>'นอกพื้นที่ / รอพิจารณา'];
if(!isset($modes[$mode]))abort_page(422,'ประเภทรายงานไม่ถูกต้อง');
if($mode==='late')$where.=' AND r.is_late=1';
if($mode==='offsite')$where.=' AND r.offsite_request_id IS NOT NULL';
if($mode==='abnormal')$where.=" AND (r.zone_status='outside' OR r.approval_status<>'อนุมัติ')";
$group=match($mode){'department'=>'d.department_id,d.department_name','employee'=>'e.employee_id,e.full_name','area'=>'g.area_id,g.area_name',default=>null};
if($group){$label=match($mode){'department'=>'d.department_name','employee'=>'e.full_name','area'=>'g.area_name'};$sql="SELECT $label label,COUNT(*) events,COUNT(DISTINCT r.user_id) employees,SUM(r.check_type='เข้างาน') checkins,SUM(r.check_type='ออกงาน') checkouts,SUM(r.is_late=1) late,SUM(r.zone_status='outside') outside".$join.$where.' GROUP BY '.$group.' ORDER BY label';$cols=['label'=>'กลุ่ม','events'=>'เหตุการณ์','employees'=>'พนักงาน','checkins'=>'เข้างาน','checkouts'=>'ออกงาน','late'=>'มาสาย','outside'=>'นอกพื้นที่'];}
else{$sql='SELECT r.attendance_id,e.full_name employee_name,d.department_name,r.check_datetime,r.check_type,g.area_name,r.zone_status,r.is_late,r.approval_status,r.offsite_request_id'.$join.$where.' ORDER BY r.check_datetime DESC,r.attendance_id DESC';$cols=['attendance_id'=>'รหัส','employee_name'=>'พนักงาน','department_name'=>'แผนก','check_datetime'=>'วัน / เวลา','check_type'=>'ประเภท','area_name'=>'พื้นที่','zone_status'=>'สถานะพื้นที่','is_late'=>'มาสาย','approval_status'=>'การอนุมัติ','offsite_request_id'=>'คำขอนอกสถานที่'];}
if(input('export')==='csv'){
 header('Content-Type: text/csv; charset=utf-8');header('Content-Disposition: attachment; filename="timeguard-'.date('Ymd').'.csv"');$out=fopen('php://output','w');fwrite($out,"\xEF\xBB\xBF");fputcsv($out,array_values($cols));
 // Unbuffered fetch keeps exports bounded in memory. Prefix formula-like cells for spreadsheet safety.
 db()->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY,false);$statement=q($sql,$args);
 while($row=$statement->fetch()){$values=[];foreach($cols as $k=>$label){$v=(string)($row[$k]??'');if(preg_match('/^[\s]*[=+@\-]/u',$v))$v="'".$v;$values[]=$v;}fputcsv($out,$values);}fclose($out);exit;
}
$summary=q("SELECT COUNT(*) events,COUNT(DISTINCT r.user_id) employees,COALESCE(SUM(r.is_late=1),0) late,COALESCE(SUM(r.zone_status='outside'),0) outside".$join.$where,$args)->fetch();
$count=$group?(int)scalar('SELECT COUNT(*) FROM ('.$sql.') report_rows',$args):(int)$summary['events'];$printing=input('print')==='1';
// Print all selected rows rather than silently printing only a page; cap very large jobs explicitly.
if($printing&&$count>5000)abort_page(422,'รายงานพิมพ์ได้ไม่เกิน 5,000 แถว กรุณาลดช่วงวันที่ หรือส่งออก CSV');
$pages=max(1,(int)ceil($count/50));$page=min($pages,max(1,(int)input('page','1')));$offset=($page-1)*50;
$rows=q($sql.($printing?'':" LIMIT 50 OFFSET $offset"),$args)->fetchAll();require __DIR__.'/../includes/header.php';
?>
<section class="reports-page">
    <nav class="report-types no-print" aria-label="ประเภทรายงาน">
        <?php foreach ($modes as $reportKey => $reportLabel): ?>
            <a class="btn btn-sm <?= $reportKey === $mode ? 'btn-primary' : 'btn-outline-secondary' ?>"
               <?= $reportKey === $mode ? 'aria-current="page"' : '' ?>
               href="?<?=e(http_build_query(array_merge($_GET, ['report' => $reportKey, 'page' => 1])))?>">
                <?=e($reportLabel)?>
            </a>
        <?php endforeach; ?>
    </nav>

    <div class="card report-filters no-print">
        <div class="card-body">
            <h2 class="h6 mb-3">ตัวกรองรายงาน</h2>
            <?php filter_form('attendance'); ?>
        </div>
    </div>

    <div class="report-context">
        <div>
            <h2 class="h5 mb-2"><?=e($modes[$mode])?></h2>
            <p class="text-secondary mb-0">
                <?=e(date('d/m/Y', strtotime(input('from', date('Y-m-01')))))?>
                – <?=e(date('d/m/Y', strtotime(input('to', date('Y-m-d')))))?>
                · <?= current_user()['role'] === 'supervisor' ? 'เฉพาะแผนกที่ดูแล' : 'ตามตัวกรององค์กร' ?>
            </p>
        </div>
        <div class="report-actions no-print">
            <a class="btn btn-outline-primary" href="?<?=e(http_build_query(array_merge($_GET, ['export' => 'csv'])))?>">
                <i class="bi bi-download" aria-hidden="true"></i> ส่งออก CSV
            </a>
            <?php if ($printing): ?>
                <button class="btn btn-primary" data-print><i class="bi bi-printer" aria-hidden="true"></i> พิมพ์รายงาน</button>
            <?php else: ?>
                <a class="btn btn-primary" href="?<?=e(http_build_query(array_merge($_GET, ['print' => '1'])))?>">
                    <i class="bi bi-printer" aria-hidden="true"></i> มุมมองพิมพ์
                </a>
            <?php endif; ?>
        </div>
    </div>

    <div class="report-metrics">
        <?php foreach ([
            'events' => ['เหตุการณ์ลงเวลา', 'clock-history', 'blue'],
            'employees' => ['พนักงาน', 'people', 'green'],
            'late' => ['เหตุการณ์มาสาย', 'alarm', 'orange'],
            'outside' => ['เหตุการณ์นอกพื้นที่', 'geo-alt', 'red'],
        ] as $metricKey => [$metricLabel, $metricIcon, $metricTone]): ?>
            <article class="card report-metric">
                <div class="card-body">
                    <div class="report-metric-top">
                        <span class="metric-label"><?=e($metricLabel)?></span>
                        <span class="report-metric-icon report-tone-<?=e($metricTone)?>">
                            <i class="bi bi-<?=e($metricIcon)?>" aria-hidden="true"></i>
                        </span>
                    </div>
                    <div class="metric-value"><?=e(number_format((int)$summary[$metricKey]))?></div>
                </div>
            </article>
        <?php endforeach; ?>
    </div>

    <div class="card report-results">
        <div class="card-header report-results-header">
            <span>รายละเอียดรายงาน</span>
            <span class="text-secondary fw-normal"><?=e(number_format($count))?> รายการ</span>
        </div>
        <div class="table-responsive">
            <table class="table mb-0">
                <thead><tr><?php foreach ($cols as $columnLabel): ?><th scope="col"><?=e($columnLabel)?></th><?php endforeach; ?></tr></thead>
                <tbody>
                    <?php foreach ($rows as $reportRow): ?>
                        <tr><?php foreach ($cols as $columnKey => $columnLabel): ?><td><?=e($reportRow[$columnKey] ?? '—')?></td><?php endforeach; ?></tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        <?php if (!$rows): ?>
            <div class="empty report-empty"><i class="bi bi-inbox" aria-hidden="true"></i><p class="mb-1">ไม่พบข้อมูลตามตัวกรอง</p><small>ลองเลือกช่วงวันที่หรือเงื่อนไขอื่น</small></div>
        <?php endif; ?>
        <?php if (!$printing): ?>
            <div class="card-body report-pagination no-print">
                <span class="text-secondary">หน้า <?=e($page)?> / <?=e($pages)?></span>
                <div class="d-flex gap-2">
                    <?php foreach ([$page - 1 => 'ก่อนหน้า', $page + 1 => 'ถัดไป'] as $targetPage => $pageLabel): ?>
                        <?php if ($targetPage < 1 || $targetPage > $pages) continue; ?>
                        <a class="btn btn-sm btn-outline-secondary" href="?<?=e(http_build_query(array_merge($_GET, ['page' => $targetPage])))?>"><?=e($pageLabel)?></a>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
</section>
<?php require __DIR__.'/../includes/footer.php'; ?>
