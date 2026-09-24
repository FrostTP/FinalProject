<?php
declare(strict_types=1);
// Override with Apache environment variables or a local.php file (never commit credentials).
$config = ['host' => getenv('TIMEGUARD_DB_HOST') ?: '127.0.0.1',
    'port' => getenv('TIMEGUARD_DB_PORT') ?: '3306',
    'name' => getenv('TIMEGUARD_DB_NAME') ?: 'timeguard_db',
    'user' => getenv('TIMEGUARD_DB_USER') ?: 'root',
    'password' => getenv('TIMEGUARD_DB_PASSWORD') ?: ''];
if (is_file(__DIR__ . '/local.php')) { $config = array_replace($config, require __DIR__ . '/local.php'); }
foreach (['host','port','name','user','password'] as $key) {
    $value = getenv('TIMEGUARD_DB_' . strtoupper($key));
    if ($value !== false) { $config[$key] = $value; }
}
return $config;
