<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
$options=getopt('',['config:']);$c=require ($options['config'] ?? __DIR__.'/timeguard_api/config/database.php');
try {
 $pdo=new PDO("mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
 $dir=__DIR__.'/../build/backups';if(!is_dir($dir)){mkdir($dir,0700,true);}
 $path=$dir.'/database-before-full-names-'.date('Ymd-His').'-'.bin2hex(random_bytes(3)).'.sql';
 $out=fopen($path,'xb');if(!$out){throw new RuntimeException('Cannot create backup');}
 fwrite($out,"-- Pre-rename backup. Restore into a separate empty database. Contains private data.\nSET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS=0;\n");
 $pdo->exec('START TRANSACTION WITH CONSISTENT SNAPSHOT');
 $total=0;
 foreach($pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN) as $table){
  $q='`'.str_replace('`','``',$table).'`';$ddl=$pdo->query('SHOW CREATE TABLE '.$q)->fetch(PDO::FETCH_NUM)[1];fwrite($out,$ddl.";\n");$count=0;
  $s=$pdo->query('SELECT * FROM '.$q);
  while($row=$s->fetch(PDO::FETCH_ASSOC)){$cols=implode(',',array_map(fn($k)=>'`'.str_replace('`','``',$k).'`',array_keys($row)));$values=implode(',',array_map(fn($v)=>$v===null?'NULL':$pdo->quote((string)$v),array_values($row)));fwrite($out,"INSERT INTO $q ($cols) VALUES ($values);\n");$count++;}
  echo $table.': '.$count." rows backed up\n";$total+=$count;
 }
 $pdo->commit();fwrite($out,"SET FOREIGN_KEY_CHECKS=1;\n");fclose($out);echo 'Backup: '.realpath($path).PHP_EOL.'Total rows: '.$total.PHP_EOL;
}catch(Throwable $e){fwrite(STDERR,$e->getMessage().PHP_EOL);exit(1);}
