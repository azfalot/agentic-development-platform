param(
  [string]$PlatformHome = $(if($env:AGENT_PLATFORM_HOME){$env:AGENT_PLATFORM_HOME}else{Join-Path $HOME '.agent-platform'}),
  [switch]$ConfirmInstall
)
$ErrorActionPreference='Stop'
if(-not $ConfirmInstall){throw 'INSTALL_CONFIRMATION_REQUIRED: rerun with -ConfirmInstall after reviewing the destination.'}
if(Test-Path -LiteralPath $PlatformHome){throw "INSTALL_TARGET_EXISTS: $PlatformHome"}
$source=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Path $PlatformHome | Out-Null
try {
  Get-ChildItem -LiteralPath $source -Force | Where-Object {$_.Name -ne '.git'} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $PlatformHome $_.Name) -Recurse -Force
  }
  Write-Output "INSTALLED_AGENT_PLATFORM_HOME=$PlatformHome"
} catch {
  Remove-Item -LiteralPath $PlatformHome -Recurse -Force -ErrorAction SilentlyContinue
  throw
}
