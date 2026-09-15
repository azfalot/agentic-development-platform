$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$canonical = 'C:\Users\Hokaido\.agents'; $legacy = 'C:\Users\Hokaido\.agents-global'
Assert (Test-Path -LiteralPath (Join-Path $canonical 'DEPRECATION.md')) 'Canonical deprecation record is missing'
Assert ((Get-FileHash -Algorithm SHA256 (Join-Path $canonical 'policies\01-shared-postgres.md')).Hash -eq (Get-FileHash -Algorithm SHA256 (Join-Path $legacy 'policies\01-shared-postgres.md')).Hash) 'Legacy shared-postgres policy was not proven equivalent'
$active = @('C:\Users\Hokaido\.codex\config.toml','C:\Users\Hokaido\.gemini\config') | Where-Object { Test-Path -LiteralPath $_ }
foreach ($item in $active) { $matches = rg -l -F 'agents-global' $item 2>$null; Assert (-not $matches) "Active configuration references legacy platform: $matches" }
$legacySync = Join-Path $legacy 'scripts\sync-agent-policies.ps1'
Assert ((Get-Content -Raw -LiteralPath $legacySync) -match 'DEPRECATED') 'Legacy synchronizer is still active'
$trackedConfigs = @('C:\Users\Hokaido\.codex\config.toml','C:\Users\Hokaido\.gemini\config\rules\global-platform-policies.md') | Where-Object { Test-Path -LiteralPath $_ }
$before = @{}; foreach ($item in $trackedConfigs) { $before[$item] = (Get-FileHash -Algorithm SHA256 -LiteralPath $item).Hash }
& powershell.exe -NoProfile -File $legacySync 2>$null; $legacyExit = $LASTEXITCODE
Assert ($legacyExit -ne 0) 'Legacy synchronizer unexpectedly succeeded'
foreach ($item in $trackedConfigs) { Assert ($before[$item] -eq (Get-FileHash -Algorithm SHA256 -LiteralPath $item).Hash) "Legacy synchronizer changed active configuration: $item" }
Write-Output 'Canonical-platform tests passed.'
exit 0
