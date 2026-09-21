Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ProjectEnvironmentDiscovery.psm1') -Force

function Get-EnvironmentDeclaration {
  param([hashtable]$Contract, [string]$WorkingDirectory = '', $Discovery = $null)
  if ($Contract.ContainsKey('environment') -and $Contract.environment -is [hashtable] -and $Contract.environment.Count -gt 0) {
    if ($Contract.environment.ContainsKey('required_commands') -and $Contract.environment.ContainsKey('dependencies') -and $Contract.environment.ContainsKey('services') -and $Contract.environment.ContainsKey('verification_commands') -and $Contract.environment.ContainsKey('preparation')) {
      return $Contract.environment
    }
    if ($WorkingDirectory) {
      return Resolve-InferredEnvironmentDeclaration -Contract $Contract -WorkingDirectory $WorkingDirectory -Discovery $Discovery
    }
    return $Contract.environment
  }
  if ($WorkingDirectory) {
    return Resolve-InferredEnvironmentDeclaration -Contract $Contract -WorkingDirectory $WorkingDirectory -Discovery $Discovery
  }
  return @{ required_commands = @(); dependencies = @(); services = @(); verification_commands = @(); preparation = @{ allowed = $false; actions = @() } }
}

function Test-EnvironmentWriteCapability {
  param([string]$WorkingDirectory, [string]$FilesystemPermission)
  $sandbox = Test-EnvironmentSandboxCapability -WorkingDirectory $WorkingDirectory -FilesystemPermission $FilesystemPermission
  [pscustomobject]@{ passed = ($sandbox.writable -and $sandbox.compatible); detail = $sandbox.detail }
}

function Test-EnvironmentEndpoint {
  param([hashtable]$Endpoint)
  try {
    $timeout = if ($Endpoint.ContainsKey('timeout_seconds')) { [int]$Endpoint.timeout_seconds } else { 5 }
    $response = Invoke-WebRequest -Uri $Endpoint.url -UseBasicParsing -TimeoutSec $timeout
    $expected = if ($Endpoint.ContainsKey('expected_status')) { [int]$Endpoint.expected_status } else { 200 }
    return [pscustomobject]@{ passed = ($response.StatusCode -eq $expected); detail = "HTTP $($response.StatusCode)" }
  } catch { return [pscustomobject]@{ passed = $false; detail = $_.Exception.Message } }
}

function Get-EnvironmentReadiness {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Contract,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    $Discovery = $null
  )
  if (-not $Discovery) {
    $Discovery = Get-ProjectEnvironmentDiscovery -WorkingDirectory $WorkingDirectory -Contract $Contract
  }
  $environment = Get-EnvironmentDeclaration -Contract $Contract -WorkingDirectory $WorkingDirectory -Discovery $Discovery
  $checks = [System.Collections.Generic.List[object]]::new()
  
  $hasWorktree = $false
  try {
    if (Test-Path -LiteralPath $WorkingDirectory) {
      $gitDir = [IO.Path]::Combine($WorkingDirectory, '.git')
      $hasWorktree = (Test-Path -LiteralPath $gitDir)
    }
  } catch {}
  $checks.Add([pscustomobject]@{ kind = 'repository'; name = 'worktree'; required = $true; prepare_action = $null; passed = $hasWorktree; detail = $WorkingDirectory })
  
  $write = if ($Discovery -and $Discovery.sandbox) { [pscustomobject]@{ passed = ($Discovery.sandbox.writable -and $Discovery.sandbox.compatible); detail = $Discovery.sandbox.detail } } else { Test-EnvironmentWriteCapability -WorkingDirectory $WorkingDirectory -FilesystemPermission $Contract.permissions.filesystem }
  $checks.Add([pscustomobject]@{ kind = 'filesystem'; name = 'write-capability'; required = $true; prepare_action = $null; passed = $write.passed; detail = $write.detail })
  
  foreach ($command in @($environment.required_commands)) {
    $required = if ($command.ContainsKey('required')) { [bool]$command.required } else { $true }
    $passed = [bool](Get-Command $command.name -ErrorAction SilentlyContinue)
    $checks.Add([pscustomobject]@{ kind = 'command'; name = $command.name; required = $required; prepare_action = if ($command.ContainsKey('prepare_action')) { $command.prepare_action } else { $null }; passed = $passed; detail = if ($passed) { 'available' } else { 'not found on PATH' } })
  }
  foreach ($dependency in @($environment.dependencies)) {
    $required = if ($dependency.ContainsKey('required')) { [bool]$dependency.required } else { $true }
    $path = [IO.Path]::Combine($WorkingDirectory, $dependency.path)
    $passed = $false
    try {
      if (Test-Path -LiteralPath $path) {
        $passed = $true
        if (Test-Path -PathType Container -LiteralPath $path) {
          $hasItems = (Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
          if (-not $hasItems) { $passed = $false }
        }
      }
    } catch { $passed = $false }
    $checks.Add([pscustomobject]@{ kind = 'dependency'; name = $dependency.name; required = $required; prepare_action = if ($dependency.ContainsKey('prepare_action')) { $dependency.prepare_action } else { $null }; passed = $passed; detail = $path })
  }
  foreach ($verification in @($environment.verification_commands)) {
    $required = if ($verification.ContainsKey('required')) { [bool]$verification.required } else { $true }
    $file = $verification.file
    $passed = [bool](Get-Command $file -ErrorAction SilentlyContinue)
    if (-not $passed) {
      try {
        $localFile = [IO.Path]::Combine($WorkingDirectory, $file)
        $passed = (Test-Path -LiteralPath $localFile) -or (Test-Path -LiteralPath $file)
      } catch {}
    }
    $checks.Add([pscustomobject]@{ kind = 'verification-command'; name = $verification.name; required = $required; prepare_action = if ($verification.ContainsKey('prepare_action')) { $verification.prepare_action } else { $null }; passed = $passed; detail = if ($passed) { 'resolvable' } else { "executable not found: $file" } })
  }
  foreach ($service in @($environment.services)) {
    $required = if ($service.ContainsKey('required')) { [bool]$service.required } else { $true }
    $endpoint = Test-EnvironmentEndpoint -Endpoint $service
    $checks.Add([pscustomobject]@{ kind = 'service'; name = $service.name; required = $required; prepare_action = if ($service.ContainsKey('prepare_action')) { $service.prepare_action } else { $null }; passed = $endpoint.passed; detail = $endpoint.detail })
  }
  $failed = @($checks | Where-Object { $_.required -and -not $_.passed })
  $actions = @($environment.preparation.actions)
  $preparationAllowed = [bool]$environment.preparation.allowed
  $reparable = @(
    foreach ($failure in $failed) {
      $actionId = $failure.prepare_action
      if ($actionId -and $preparationAllowed -and @($actions | Where-Object { $_.id -eq $actionId }).Count -gt 0) { $failure }
    }
  )
  $state = if ($failed.Count -eq 0) { 'READY' } elseif ($reparable.Count -eq $failed.Count) { 'PREPARABLE' } else { 'BLOCKED' }
  [pscustomobject]@{ state = $state; checks = @($checks); blockers = @($failed); preparation_allowed = $preparationAllowed; discovery = $Discovery }
}

function Invoke-EnvironmentPreparation {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Contract, [Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)]$Readiness)
  if ($Readiness.state -ne 'PREPARABLE') { return [pscustomobject]@{ attempted = @(); readiness = $Readiness } }
  $environment = Get-EnvironmentDeclaration -Contract $Contract -WorkingDirectory $WorkingDirectory -Discovery $Readiness.discovery
  $requested = @($Readiness.blockers | ForEach-Object { $_.prepare_action } | Select-Object -Unique)
  $attempted = [System.Collections.Generic.List[object]]::new()
  foreach ($id in $requested) {
    $action = @($environment.preparation.actions | Where-Object { $_.id -eq $id }) | Select-Object -First 1
    if (-not $action) { continue }
    $executable = Get-Command $action.file -ErrorAction SilentlyContinue
    if (-not $executable) { $attempted.Add([pscustomobject]@{ id = $id; exit_code = $null; succeeded = $false; detail = "preparation executable not found: $($action.file)" }); continue }
    if ($action.ContainsKey('background') -and $action.background) {
      $process = Start-Process -FilePath $executable.Source -ArgumentList @($action.arguments) -WorkingDirectory $WorkingDirectory -PassThru
      Start-Sleep -Milliseconds 200
      $attempted.Add([pscustomobject]@{ id = $id; exit_code = $null; succeeded = $true; detail = "started process $($process.Id)" })
    } else {
      $process = Start-Process -FilePath $executable.Source -ArgumentList @($action.arguments) -WorkingDirectory $WorkingDirectory -PassThru -Wait -NoNewWindow
      $attempted.Add([pscustomobject]@{ id = $id; exit_code = $process.ExitCode; succeeded = ($process.ExitCode -eq 0); detail = "exit $($process.ExitCode)" })
    }
  }
  $reevaluated = Get-EnvironmentReadiness -Contract $Contract -WorkingDirectory $WorkingDirectory -Discovery $Readiness.discovery
  if (@($attempted | Where-Object { -not $_.succeeded }).Count -gt 0) { $reevaluated.state = 'BLOCKED' }
  [pscustomobject]@{ attempted = @($attempted); readiness = $reevaluated }
}

function Save-EnvironmentReadinessEvidence {
  param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)]$Initial, $Preparation, [Parameter(Mandatory)]$Final, $Discovery = $null)
  $path = Join-Path $WorkingDirectory '.agenthub-readiness-evidence.json'
  $discoveryObj = if ($Discovery) { $Discovery } elseif ($Final -and $Final.discovery) { $Final.discovery } elseif ($Initial -and $Initial.discovery) { $Initial.discovery } else { $null }
  @{ schema_version = 1; recorded_at = (Get-Date).ToUniversalTime().ToString('o'); discovery = $discoveryObj; initial = $Initial; preparation = $Preparation; final = $Final } | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $path -Encoding utf8
  return $path
}

Export-ModuleMember -Function Get-EnvironmentDeclaration, Get-EnvironmentReadiness, Invoke-EnvironmentPreparation, Save-EnvironmentReadinessEvidence, Get-ProjectEnvironmentDiscovery, Test-EnvironmentSandboxCapability, Resolve-InferredEnvironmentDeclaration
