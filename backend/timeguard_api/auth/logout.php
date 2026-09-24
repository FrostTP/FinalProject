<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');user();query('DELETE FROM tech_auth_tokens WHERE token_hash=?',[bearer_hash()]);respond();
