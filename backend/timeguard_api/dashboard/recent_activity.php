<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();
respond(query('SELECT * FROM attendance_logs WHERE user_id=? ORDER BY check_datetime DESC,attendance_id DESC LIMIT 10',[$u['id']])->fetchAll());
