<?php
require __DIR__.'/../timeguard_api/config/google_rules.php';
$count=0;function check(bool $v,string $name):void{global $count;if(!$v){throw new RuntimeException($name);}echo "PASS $name\n";$count++;}
$c=['aud'=>'web-client','iss'=>'https://accounts.google.com','exp'=>2000,'iat'=>1000,'sub'=>'1234567890','email_verified'=>true];
check(google_claims_valid($c,'web-client',1500),'valid claims');
foreach(['aud'=>'another-client','iss'=>'https://attacker.example','exp'=>1500,'iat'=>1601,'sub'=>'','email_verified'=>false] as $key=>$value){check(!google_claims_valid(array_replace($c,[$key=>$value]),'web-client',1500),'reject '.$key);}
$options=['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA];
if(is_file('C:/xampp/apache/conf/openssl.cnf')){$options['config']='C:/xampp/apache/conf/openssl.cnf';}
$key=openssl_pkey_new($options);if($key===false){throw new RuntimeException('OpenSSL test key creation failed');}
$public=openssl_pkey_get_details($key)['key'];openssl_sign('header.payload',$signature,$key,OPENSSL_ALGO_SHA256);
check(google_signature_valid('header.payload',$signature,$public),'RS256 signature');check(!google_signature_valid('header.changed',$signature,$public),'tampered token rejected');
echo "SUCCESS $count Google verifier rules (local keys, not live OAuth)\n";
