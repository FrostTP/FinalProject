<?php
require_once __DIR__.'/../config/bootstrap.php';method('GET');$u=employee();respond(active_areas($u['id']));
