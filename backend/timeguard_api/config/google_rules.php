<?php
declare(strict_types=1);
function google_claims_valid(array $c,string $audience,int $now): bool {
    return ($c['aud'] ?? null)===$audience && in_array($c['iss'] ?? '',['accounts.google.com','https://accounts.google.com'],true)
      && is_numeric($c['exp'] ?? null) && (int)$c['exp']>$now && is_numeric($c['iat'] ?? null) && (int)$c['iat']<=$now+60
      && is_string($c['sub'] ?? null) && $c['sub']!=='' && strlen($c['sub'])<=50 && ($c['email_verified'] ?? false)===true;
}
function google_signature_valid(string $message,string $signature,string $certificate): bool {
    return openssl_verify($message,$signature,$certificate,OPENSSL_ALGO_SHA256)===1;
}
