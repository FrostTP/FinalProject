param([string]$Destination = 'C:\xampp\htdocs\timeguard_api')
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'timeguard_api'
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) {
    throw "Destination already exists: $target. Review and merge changes manually to preserve local configuration."
}
Copy-Item -LiteralPath $source -Destination $target -Recurse
Write-Output "API copied to $target. Configure config/local.php and import database/timeguard.sql in phpMyAdmin."
