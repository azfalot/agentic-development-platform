$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$target=Join-Path ([IO.Path]::GetTempPath()) ('agent-platform-install-'+[guid]::NewGuid())
try {
  & (Join-Path $root 'scripts\bootstrap.ps1') -PlatformHome $target -ConfirmInstall
  Assert (Test-Path (Join-Path $target 'scripts\agenthub.ps1')) 'Bootstrap did not install AgentHub'
  $failed=$false;try {& (Join-Path $root 'scripts\bootstrap.ps1') -PlatformHome $target -ConfirmInstall}catch{$failed=$true}
  Assert $failed 'Bootstrap overwrote an existing installation'
  $nested=Join-Path $root '.bootstrap-nested-target';$failed=$false;try {& (Join-Path $root 'scripts\bootstrap.ps1') -PlatformHome $nested -ConfirmInstall}catch{$failed=$true}
  Assert $failed 'Bootstrap accepted an installation target inside its source tree'
  Write-Output 'Bootstrap tests passed.'
} finally {if(Test-Path $target){Remove-Item -LiteralPath $target -Recurse -Force}}
exit 0
