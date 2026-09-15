function Get-CodexCapabilities {
  param([string]$Executable='codex')
  $cmd=Get-Command $Executable -ErrorAction SilentlyContinue;if(-not$cmd){throw 'CODEX_UNAVAILABLE'}
  $version=& $cmd.Source --version 2>&1;if($LASTEXITCODE -ne 0){throw 'CODEX_VERSION_DISCOVERY_FAILED'}
  $help=& $cmd.Source exec --help 2>&1;if($LASTEXITCODE -ne 0){throw 'CODEX_EXEC_CAPABILITY_DISCOVERY_FAILED'}
  $m=[regex]::Match(($help -join "`n"),'\[possible values: ([^\]]+)\]');if(-not$m.Success){throw 'CODEX_SANDBOX_CAPABILITY_DISCOVERY_FAILED'}
  $modes=@($m.Groups[1].Value -split ',\s*'|ForEach-Object{$_.Trim()})
  [pscustomobject]@{codex_available=$true;codex_path=$cmd.Source;codex_version=($version -join '');exec_available=($help -match 'Run Codex non-interactively');supported_sandbox_modes=$modes;configured_windows_sandbox='elevated'}
}
function New-CodexExecutionContract {
  param($Capabilities,[string]$PermissionProfile,[string]$Prompt,[string]$WorkingDirectory)
  $mode=@{'scoped-write'='workspace-write';'read-only'='read-only'}[$PermissionProfile];if(-not$mode -or $mode -notin $Capabilities.supported_sandbox_modes){throw 'PREFLIGHT_FAILED_UNSUPPORTED_SANDBOX'}
  if(-not(Test-Path -LiteralPath $WorkingDirectory)){throw 'PREFLIGHT_FAILED_WORKDIR'}
  [pscustomobject]@{file=$Capabilities.codex_path;arguments=@('exec','--sandbox',$mode,'--cd',$WorkingDirectory,$Prompt);working_directory=$WorkingDirectory;mode=$mode}
}
function Test-CodexWorkspaceSandbox {
  param($Capabilities,[string]$WorkingDirectory)
  if(-not(Test-Path -LiteralPath $WorkingDirectory)){throw 'PREFLIGHT_FAILED_WORKDIR'}
  $cmdPath = Join-Path $env:WINDIR 'System32\cmd.exe'
  if(-not(Test-Path -LiteralPath $cmdPath)){throw 'PREFLIGHT_FAILED_SYSTEM_COMMAND'}
  # This uses Codex's documented sandbox harness only; it never calls `codex exec` or a model.
  $output = & $Capabilities.codex_path sandbox --permission-profile ':workspace' --cd $WorkingDirectory -- $cmdPath /d /c 'echo AGENTHUB_SANDBOX_PROBE_OK' 2>&1
  $exitCode = $LASTEXITCODE
  $text = $output -join "`n"
  [pscustomobject]@{
    cli_accepted = ($Capabilities.exec_available -and ('workspace-write' -in $Capabilities.supported_sandbox_modes))
    sandbox_operational = ($exitCode -eq 0 -and $text -match 'AGENTHUB_SANDBOX_PROBE_OK')
    exit_code = $exitCode
    detail = if($exitCode -eq 0){'sandbox child process completed'}else{$text}
  }
}
Export-ModuleMember -Function Get-CodexCapabilities,New-CodexExecutionContract,Test-CodexWorkspaceSandbox
