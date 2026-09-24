<?php
declare(strict_types=1);
// Coordinates are planar longitude/latitude, for local work-area polygons (no dateline crossing).
function on_segment(float $x,float $y,array $a,array $b): bool {
    $cross=($x-$a['lng'])*($b['lat']-$a['lat'])-($y-$a['lat'])*($b['lng']-$a['lng']);
    return abs($cross)<=1e-10 && $x>=min($a['lng'],$b['lng'])-1e-10 && $x<=max($a['lng'],$b['lng'])+1e-10 && $y>=min($a['lat'],$b['lat'])-1e-10 && $y<=max($a['lat'],$b['lat'])+1e-10;
}
function point_in_polygon(float $lat,float $lng,array $polygon): bool {
    if (count($polygon)<3) { return false; }
    $inside=false;
    for($i=0,$j=count($polygon)-1;$i<count($polygon);$j=$i++) {
        $a=$polygon[$j]; $b=$polygon[$i];
        if(on_segment($lng,$lat,$a,$b)) { return true; }
        if(($a['lat']>$lat)!==($b['lat']>$lat) && $lng<($b['lng']-$a['lng'])*($lat-$a['lat'])/($b['lat']-$a['lat'])+$a['lng']) { $inside=!$inside; }
    }
    return $inside;
}
function polygon_valid(array $p): bool {
    $n=count($p); if($n<3 || $n>200) { return false; }
    $keys=[]; $area=0;
    foreach($p as $v) {
        if(!is_array($v) || !isset($v['lat'],$v['lng']) || !is_numeric($v['lat']) || !is_numeric($v['lng']) || !is_finite((float)$v['lat']) || !is_finite((float)$v['lng']) || abs((float)$v['lat'])>90 || abs((float)$v['lng'])>180) { return false; }
        $keys[]=$v['lat'].','.$v['lng'];
    }
    if(count(array_unique($keys))!==$n) { return false; } // Store open ring, not repeated first vertex.
    for($i=0;$i<$n;$i++) {
        $a=$p[$i];$b=$p[($i+1)%$n];$area+=$a['lng']*$b['lat']-$b['lng']*$a['lat'];
        if(abs($a['lng']-$b['lng'])>180) { return false; }
        for($j=$i+1;$j<$n;$j++) {
            if($j===$i+1 || ($i===0 && $j===$n-1)) { continue; }
            $c=$p[$j];$d=$p[($j+1)%$n];
            $cross=static fn($u,$v,$w)=>($v['lng']-$u['lng'])*($w['lat']-$u['lat'])-($v['lat']-$u['lat'])*($w['lng']-$u['lng']);
            if(on_segment($a['lng'],$a['lat'],$c,$d) || on_segment($b['lng'],$b['lat'],$c,$d) || on_segment($c['lng'],$c['lat'],$a,$b) || on_segment($d['lng'],$d['lat'],$a,$b) || ($cross($a,$b,$c)*$cross($a,$b,$d)<0 && $cross($c,$d,$a)*$cross($c,$d,$b)<0)) { return false; }
        }
    }
    return abs($area)>1e-10;
}
function transition_error(array $events,bool $out): ?string {
    $types=array_column($events,'check_type');
    if($out && !in_array('เข้างาน',$types,true)) { return 'ยังไม่ได้ลงเวลาเข้างาน'; }
    if(in_array($out ? 'ออกงาน' : 'เข้างาน',$types,true)) { return 'ลงเวลาประเภทนี้แล้ววันนี้'; }
    return null;
}
function assignment_valid(array $a,string $date): bool {
    return $a['status']==='active' && $a['effective_date']<=$date && ($a['end_date']===null || $a['end_date']>=$date);
}
