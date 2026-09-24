param([string]$Destination = 'C:\xampp\htdocs\timeguard_api')
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'timeguard_api'))
$target = [IO.Path]::GetFullPath($Destination)
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Expected existing API directory.' }
$backup = Join-Path (Split-Path $PSScriptRoot) ('build\backups\api-before-full-names-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $backup) { throw 'Backup already exists.' }
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Get-ChildItem -LiteralPath $target -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $backup -Recurse }
Get-ChildItem -LiteralPath $source -File -Recurse -Force | ForEach-Object {
    $relative = $_.FullName.Substring($source.Length + 1)
    if ($relative -in @('config\local.php', 'config\integrations.local.php')) { return }
    if ($relative.StartsWith('storage\') -and $relative -ne 'storage\.htaccess') { return }
    $output = Join-Path $target $relative
    New-Item -ItemType Directory -Path (Split-Path $output) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $output -Force
}
Write-Output "API synchronized. Existing local settings and images retained. Backup: $backup"
