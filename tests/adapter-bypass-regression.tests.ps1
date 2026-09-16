$ErrorActionPreference='Stop'
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
$hub=Get-Content -Raw (Join-Path $PSScriptRoot '..\scripts\agenthub.ps1')
$forbidden=@('--sandbox','workspace-write','codex.exe','Get-CodexCapabilities','Resolve-CodexExecutionSpecification','New-CodexExecutionContract','Test-CodexExecutionSpecification')
foreach($token in $forbidden){Assert (-not $hub.Contains($token)) "Generic AgentHub code contains adapter-specific token: $token"}
Assert ($hub.Contains('Resolve-AgentExecutionSpecification') -and $hub.Contains('Invoke-AgentExecutionSpecification')) 'Generic execution core is not used'
Write-Output 'Adapter bypass structural regression test passed.'
