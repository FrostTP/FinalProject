<?php
declare(strict_types=1);
// CLI only. Dry-run by default. Performs RENAME TABLE, never DROP/TRUNCATE/reseed.
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
$options=getopt('',['config:','apply']);
$configPath=$options['config'] ?? __DIR__.'/timeguard_api/config/database.php';
$c=require $configPath;
try {
    $pdo=new PDO("mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    $map=require __DIR__.'/timeguard_api/config/table_names.php';
    $actual=$pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
    $lookup=[];foreach($actual as $name){$lookup[strtolower($name)]=$name;}
    $pairs=[];$errors=[];
    foreach($map as $old=>$new){
        $source=$lookup[strtolower($old)] ?? null;$target=$lookup[$new] ?? null;
        if($source!==null && $target!==null){$errors[]="$old -> $new: both names exist; review legacy tables first";}
        elseif($source!==null){$pairs[]='`'.$source.'` TO `'.$new.'`';}
        elseif($target===null){$errors[]="$old -> $new: source and target are missing";}
    }
    echo 'Database: '.$c['name'].PHP_EOL;
    if($errors){throw new RuntimeException(implode(PHP_EOL,$errors));}
    if(!$pairs){echo "All tables already use full names. No changes.\n";exit;}
    $sql='RENAME TABLE '.implode(', ',$pairs);
    echo $sql.";\n";
    if(!array_key_exists('apply',$options)){echo "Dry run only. Back up the database and stop API traffic before running with --apply.\n";exit;}
    $pdo->exec($sql);
    echo "Renamed tables. Rows, IDs and foreign keys retained. Deploy matching PHP API before resuming traffic.\n";
}catch(Throwable $e){fwrite(STDERR,$e->getMessage().PHP_EOL);exit(1);}
