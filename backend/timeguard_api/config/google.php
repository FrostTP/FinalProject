<?php
require_once __DIR__.'/bootstrap.php';
require_once __DIR__.'/google_rules.php';
function decode_base64url(string $value): string { $v=base64_decode(strtr($value,'-_','+/'),true);if($v===false){fail('Google token ไม่ถูกต้อง',401);}return $v; }
function verify_google_token(string $token): array {
    $c=require __DIR__.'/integrations.php'; if(!$c['google_client_id']){fail('ยังไม่ได้ตั้งค่า Google OAuth Web client ID',503);}
    $parts=explode('.',$token);if(count($parts)!==3){fail('Google token ไม่ถูกต้อง',401);}
    try{$head=json_decode(decode_base64url($parts[0]),true,16,JSON_THROW_ON_ERROR);$claims=json_decode(decode_base64url($parts[1]),true,16,JSON_THROW_ON_ERROR);}catch(JsonException $e){fail('Google token ไม่ถูกต้อง',401);}
    if(!is_array($head)||!is_array($claims)||($head['alg'] ?? '')!=='RS256'||!is_string($head['kid'] ?? null)){fail('Google token ไม่ถูกต้อง',401);}
    // Fixed Google HTTPS certificate endpoint. Never trust a URL supplied by a token.
    $curl=curl_init('https://www.googleapis.com/oauth2/v1/certs');curl_setopt_array($curl,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15,CURLOPT_CONNECTTIMEOUT=>5]);
    $raw=curl_exec($curl);$status=curl_getinfo($curl,CURLINFO_HTTP_CODE);curl_close($curl);
    if($raw===false||$status!==200){fail('ติดต่อ Google เพื่อตรวจสอบ token ไม่ได้',503);}
    $certs=json_decode($raw,true);$cert=$certs[$head['kid']] ?? null;
    if(!is_string($cert)||!google_signature_valid($parts[0].'.'.$parts[1],decode_base64url($parts[2]),$cert)){fail('ลายเซ็น Google token ไม่ถูกต้อง',401);}
    if(!google_claims_valid($claims,$c['google_client_id'],time())){fail('Google token หมดอายุหรือไม่ตรงกับแอป',401);}
    return $claims;
}
