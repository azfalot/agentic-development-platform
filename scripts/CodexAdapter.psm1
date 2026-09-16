function Get-CodexCapabilities {
  param([string]$Executable = 'codex')
  $command = Get-Command $Executable -ErrorAction SilentlyContinue
  if (-not $command) { throw 'CODEX_UNAVAILABLE' }
  $version = & $command.Source --version 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'CODEX_VERSION_DISCOVERY_FAILED' }
  $help = & $command.Source exec --help 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'CODEX_EXEC_CAPABILITY_DISCOVERY_FAILED' }
  $match = [regex]::Match(($help -join "`n"), '\[possible values: ([^\]]+)\]')
  if (-not $match.Success) { throw 'CODEX_SANDBOX_CAPABILITY_DISCOVERY_FAILED' }
  [pscustomobject]@{
    codex_available = $true
    codex_path = $command.Source
    codex_version = ($version -join '')
    exec_available = [bool]($help -match 'Run Codex non-interactively')
    supported_sandbox_modes = @($match.Groups[1].Value -split ',\s*' | ForEach-Object { $_.Trim() })
    configured_windows_sandbox = 'elevated'
  }
}

function New-CodexExecutionContract {
  param($Capabilities, [string]$PermissionProfile, [string]$Prompt, [string]$WorkingDirectory)
  $mode = @{ 'scoped-write' = 'workspace-write'; 'read-only' = 'read-only' }[$PermissionProfile]
  if (-not $mode -or $mode -notin $Capabilities.supported_sandbox_modes) { throw 'PREFLIGHT_FAILED_UNSUPPORTED_SANDBOX' }
  if (-not (Test-Path -LiteralPath $WorkingDirectory)) { throw 'PREFLIGHT_FAILED_WORKDIR' }
  [pscustomobject]@{
    executable = $Capabilities.codex_path
    arguments = @('exec', '--sandbox', $mode, '--cd', $WorkingDirectory, $Prompt)
    working_directory = $WorkingDirectory
    environment = @{}
    sandbox = $mode
    mode = $mode
  }
}

function Get-CodexSpecificationId {
  param($Specification)
  $material = (@($Specification.executable) + @($Specification.arguments) + @($Specification.working_directory) + @($Specification.sandbox)) -join "`n"
  $bytes = [Text.Encoding]::UTF8.GetBytes($material)
  ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Resolve-CodexExecutionSpecification {
  param([string]$Executable = 'codex', [string]$PermissionProfile, [string]$Prompt, [string]$WorkingDirectory)
  $capabilities = Get-CodexCapabilities -Executable $Executable
  $specification = New-CodexExecutionContract -Capabilities $capabilities -PermissionProfile $PermissionProfile -Prompt $Prompt -WorkingDirectory $WorkingDirectory
  $specification | Add-Member -NotePropertyName adapter -NotePropertyValue 'CodexAdapter'
  $specification | Add-Member -NotePropertyName engine -NotePropertyValue 'codex'
  $specification | Add-Member -NotePropertyName engine_version -NotePropertyValue $capabilities.codex_version
  $specification | Add-Member -NotePropertyName capabilities -NotePropertyValue $capabilities
  $specification | Add-Member -NotePropertyName specification_id -NotePropertyValue (Get-CodexSpecificationId $specification)
  $specification
}

function Test-CodexWorkspaceSandbox {
  param($Capabilities, [string]$WorkingDirectory)
  if (-not (Test-Path -LiteralPath $WorkingDirectory)) { throw 'PREFLIGHT_FAILED_WORKDIR' }
  $cmdPath = Join-Path $env:WINDIR 'System32\cmd.exe'
  if (-not (Test-Path -LiteralPath $cmdPath)) { throw 'PREFLIGHT_FAILED_SYSTEM_COMMAND' }
  $output = & $Capabilities.codex_path sandbox --permission-profile ':workspace' --cd $WorkingDirectory -- $cmdPath /d /c 'echo AGENTHUB_SANDBOX_PROBE_OK' 2>&1
  $exitCode = $LASTEXITCODE
  $text = $output -join "`n"
  [pscustomobject]@{
    cli_accepted = ($Capabilities.exec_available -and ('workspace-write' -in $Capabilities.supported_sandbox_modes))
    sandbox_operational = ($exitCode -eq 0 -and $text -match 'AGENTHUB_SANDBOX_PROBE_OK')
    exit_code = $exitCode
    detail = if ($exitCode -eq 0) { 'sandbox child process completed' } else { $text }
  }
}

function Test-CodexExecutionSpecification {
  param($Specification)
  if ($Specification.adapter -ne 'CodexAdapter' -or -not $Specification.specification_id) { throw 'PREFLIGHT_FAILED_ADAPTER_SPECIFICATION' }
  if ($Specification.arguments -notcontains '--sandbox' -or -not $Specification.sandbox) { throw 'PREFLIGHT_FAILED_ADAPTER_SPECIFICATION' }
  $sandbox = Test-CodexWorkspaceSandbox -Capabilities $Specification.capabilities -WorkingDirectory $Specification.working_directory
  [pscustomobject]@{
    specification_id = $Specification.specification_id
    cli_accepted = $sandbox.cli_accepted
    sandbox_operational = $sandbox.sandbox_operational
    detail = $sandbox.detail
  }
}

Export-ModuleMember -Function Get-CodexCapabilities,New-CodexExecutionContract,Resolve-CodexExecutionSpecification,Test-CodexExecutionSpecification,Test-CodexWorkspaceSandbox
