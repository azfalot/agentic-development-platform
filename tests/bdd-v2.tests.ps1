$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\BDDValidator.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$contract = @{ schema_version = 2; task = @{ id = 'platform-1'; source = 'manual'; repository = 'platform'; issue = $null }; goal = 'Validate the foundation'; assignment = @{ role = 'validator'; engine = 'unassigned' }; state = 'CREATED'; scope = @{ bounded_context = 'platform'; allowed = @('bdd/**'); forbidden = @('**/secrets/**') }; permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $false; merge = $false; production = 'denied' }; ownership = @{ task = 'platform-1'; branch = $null; bounded_context = 'platform'; files = @('bdd/**'); migrations = @() }; acceptance_criteria = @(@{ id = 'AC-1'; description = 'Contract validates'; status = 'PENDING' }); verification = @{ build = 'NOT_RUN'; lint = 'NOT_RUN'; unit = 'NOT_RUN'; integration = 'NOT_APPLICABLE'; e2e = 'NOT_APPLICABLE'; guardrails = 'NOT_RUN'; ci = 'NOT_RUN' }; evidence = @{ commit_sha = $null; changed_files = @(); test_results = @(); build_result = $null; playwright = $null; ci = $null; pull_request = $null }; handoff = @{ target_role = 'human'; reason = 'Foundation review required' }; timestamps = @{ created = '2026-09-15T00:00:00Z'; updated = '2026-09-15T00:00:00Z' } }
$path = Join-Path ([System.IO.Path]::GetTempPath()) ('bdd-v2-' + [guid]::NewGuid() + '.json'); $contract | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
$result = Test-BddV2Contract -Path $path; Assert $result.IsValid ('Expected valid contract: ' + ($result.Errors -join '; '))
Assert (Test-Json -LiteralPath $path -SchemaFile (Join-Path $PSScriptRoot '..\bdd\v2\contract.schema.json')) 'The JSON Schema rejected a valid v2 contract'
$contract.state = 'WAITING_REVIEW'; $contract | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
$result = Test-BddV2Contract -Path $path; Assert (-not $result.IsValid) 'Retired WAITING_REVIEW must be rejected'
$contract.state = 'CREATED'; $contract.unapproved = 'must fail'; $contract | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
$result = Test-BddV2Contract -Path $path; Assert (-not $result.IsValid) 'Unknown contract fields must be rejected'
Assert (Test-BddStateTransition -From 'CREATED' -To 'PLANNING') 'Expected CREATED -> PLANNING'
Assert (-not (Test-BddStateTransition -From 'CREATED' -To 'DONE')) 'Illegal CREATED -> DONE was accepted'
Assert ((Get-BddRoleDefinition -Role implementer).permissions.merge -eq $false) 'Implementer must not merge'
Write-Output 'BDD v2 tests passed.'
exit 0
