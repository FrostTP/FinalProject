param([string]$Destination='C:\xampp\htdocs\timeguard_admin')
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'timeguard_admin'
$target=[IO.Path]::GetFullPath($Destination)
if ($target -ne 'C:\xampp\htdocs\timeguard_admin') { throw 'This deployment is scoped to C:\xampp\htdocs\timeguard_admin.' }
if (-not (Test-Path 'C:\xampp\htdocs\timeguard_api\config\database.php')) { throw 'Install the existing API beside the admin first.' }
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
if(Test-Path -LiteralPath $target){
 $backup=Join-Path $PSScriptRoot "..\build\backups\web-before-$stamp"
 New-Item -ItemType Directory -Path $backup -Force | Out-Null
 Copy-Item -LiteralPath $target -Destination $backup -Recurse
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
Get-ChildItem -LiteralPath $source -Recurse -File -Force | ForEach-Object {
 $relative=$_.FullName.Substring($source.Length).TrimStart('\')
 if($relative -notin @('config\local.php','config\campus-layer.local.json','config\campus-layer.lock')){
  $dest=Join-Path $target $relative
  New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
  Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
 }
}
Write-Output 'Back office deployed: http://localhost/timeguard_admin/ (API and mobile files unchanged).'
