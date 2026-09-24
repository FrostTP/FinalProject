<?php
require_once __DIR__.'/../config/bootstrap.php';method('POST');$u=employee();$b=body();$name=text_value($b,'full_name',100);$phone=optional_text($b,'phone',15);
if($phone!==null&&!preg_match('/^[0-9+() -]+$/',$phone)){fail('เบอร์โทรไม่ถูกต้อง');}
query('UPDATE employees SET full_name=?,phone=? WHERE employee_id=?',[$name,$phone,$u['id']]);respond(user());
