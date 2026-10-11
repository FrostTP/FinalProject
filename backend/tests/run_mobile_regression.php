<?php
// Run the existing isolated mobile API tests using the installed DB connection.
$c=require(getenv('TG_TEST_CONFIG')?:'C:/xampp/htdocs/timeguard_api/config/database.php');
foreach($c as $key=>$value)putenv('TIMEGUARD_DB_'.strtoupper($key).'='.$value);
require __DIR__.'/integration_test.php';
