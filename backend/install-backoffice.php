<?php
// CLI only. Adds one explicitly separated technical table; never alters core tables.
if(PHP_SAPI!=='cli')exit(1);
$options=getopt('',['config:','apply']);$path=$options['config']??__DIR__.'/timeguard_api/config/database.php';$c=require $path;
$pdo=new PDO("mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4",$c['user'],$c['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
foreach(require __DIR__.'/timeguard_api/config/table_names.php' as $table){$pdo->query("SELECT 1 FROM `$table` LIMIT 0");}
echo "Verified 11 existing core tables. Target database: {$c['name']}\n";
if(!isset($options['apply'])){echo "Dry run: would CREATE TABLE IF NOT EXISTS tech_web_audit_logs. Use --apply to install.\n";exit;}
$pdo->exec(file_get_contents(__DIR__.'/timeguard_admin/database/001_web_audit.sql'));echo "Installed tech_web_audit_logs. No core table altered.\n";
