<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();respond(query('SELECT * FROM tech_notifications WHERE employee_id=? ORDER BY id DESC LIMIT 100',[$u['id']])->fetchAll());
