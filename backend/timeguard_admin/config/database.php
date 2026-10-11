<?php
declare(strict_types=1);
$api = getenv('TIMEGUARD_API_ROOT') ?: dirname(__DIR__, 2).'/timeguard_api';
if (is_file(__DIR__.'/local.php')) { $local = require __DIR__.'/local.php'; $api = $local['api_root'] ?? $api; }
define('TG_API_ROOT', $api);
function db(): PDO {
    static $pdo;
    if (!$pdo) {
        $c = require TG_API_ROOT.'/config/database.php';
        $pdo = new PDO("mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4", $c['user'], $c['password'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
        $pdo->exec("SET time_zone='+07:00'");
    }
    return $pdo;
}
function q(string $sql, array $args=[]): PDOStatement { $s=db()->prepare($sql); $s->execute($args); return $s; }
