$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\AgentExecutionCore.psm1') -Force
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function global:Resolve-MockExecutionSpecification {
  param([string]$Executable,[string]$PermissionProfile,[string]$Prompt,[string]$WorkingDirectory)
  [pscustomobject]@{adapter='MockAdapter';engine='mock';engine_version='1.0';executable=$Executable;arguments=@('mock-exec','--adapter-sentinel',$Prompt);working_directory=$WorkingDirectory;environment=@{};sandbox=$PermissionProfile;specification_id='mock-specification-001'}
}
function global:Test-MockExecutionSpecification { param($Specification)
  if($Specification.arguments[1] -ne '--adapter-sentinel'){throw 'MOCK_SPECIFICATION_MUTATED'}
  [pscustomobject]@{specification_id=$Specification.specification_id;cli_accepted=$true;sandbox_operational=$true;detail='mock preflight passed'}
}
$adapter=@{resolve_function='Resolve-MockExecutionSpecification';test_function='Test-MockExecutionSpecification'}
$context=@{Executable='mock.exe';PermissionProfile='mock-sandbox';Prompt='adapter-owned-boundary';WorkingDirectory=$env:TEMP}
$specification=Resolve-AgentExecutionSpecification -Adapter $adapter -Context $context
$preflight=Test-AgentExecutionSpecification -Adapter $adapter -Specification $specification
$global:AgentHubMockReceived=$null
$runner={param($received)$global:AgentHubMockReceived=$received;[pscustomobject]@{process_completed=$true;exit_code=0;process_id=4242}}
$result=Invoke-AgentExecutionSpecification -Specification $specification -StandardOutputPath (Join-Path $env:TEMP 'mock.out') -StandardErrorPath (Join-Path $env:TEMP 'mock.err') -TimeoutSeconds 1 -ProcessRunner $runner
Assert ($preflight.specification_id -eq $specification.specification_id) 'Preflight did not validate adapter specification'
Assert ($global:AgentHubMockReceived.specification_id -eq $specification.specification_id) 'Runner did not receive the preflight specification'
Assert ($global:AgentHubMockReceived.arguments[1] -eq '--adapter-sentinel') 'Generic runner reconstructed adapter arguments'
Assert ($result.exit_code -eq 0) 'Mock runner did not execute'
Remove-Variable AgentHubMockReceived -Scope Global -ErrorAction SilentlyContinue
Remove-Item Function:\global:Resolve-MockExecutionSpecification -ErrorAction SilentlyContinue
Remove-Item Function:\global:Test-MockExecutionSpecification -ErrorAction SilentlyContinue
Write-Output 'Adapter boundary mock specification identity test passed.'
