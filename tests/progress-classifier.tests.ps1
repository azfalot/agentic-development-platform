$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\ProgressClassifier.psm1') -Force
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function New-Contract([string[]]$Allowed){
  [pscustomobject]@{scope=[pscustomobject]@{allowed=$Allowed;forbidden=@('private/**')};ownership=[pscustomobject]@{files=$Allowed}}
}
function Assert-Classification([string]$Name,[string[]]$Allowed,[string[]]$Changed,[bool]$Progress,[bool]$Source,[bool]$Tests,[bool]$Scope){
  $result=Get-AgentHubChangeClassification -ChangedFiles $Changed -Contract (New-Contract $Allowed)
  Assert ($result.progress_detected -eq $Progress) "$Name progress mismatch"
  Assert ($result.source_change_detected -eq $Source) "$Name source mismatch"
  Assert ($result.test_change_detected -eq $Tests) "$Name test mismatch"
  Assert ($result.scope_valid -eq $Scope) "$Name scope mismatch"
  $result
}

# 1. src + tests
Assert-Classification 'src-and-tests' @('src/**','tests/**') @('src/widget.ps1','tests/widget.tests.ps1') $true $true $true $true | Out-Null
# 2. DOGFOODING_01 fixture: scripts implementation + tests + docs
$dog=Assert-Classification 'dogfooding-01' @('scripts/agenthub.ps1','tests/**','README.md') @('README.md','scripts/agenthub.ps1','tests/version-command.tests.ps1') $true $true $true $true
Assert ($dog.documentation_change_detected) 'DOGFOODING_01 documentation change was not classified'
Assert ($dog.invalid_files.Count -eq 0) 'DOGFOODING_01 fixture has unexpected invalid files'
# 3. arbitrary implementation directory
Assert-Classification 'custom-implementation' @('domain-code/**','qa/**') @('domain-code/runner.ps1','qa/runner.tests.ps1') $true $true $true $true | Out-Null
# 4. tests only
Assert-Classification 'tests-only' @('scripts/**','tests/**') @('tests/version-command.tests.ps1') $false $false $true $true | Out-Null
# 5. documentation only
Assert-Classification 'documentation-only' @('scripts/**','README.md') @('README.md') $false $false $false $true | Out-Null
# 6. out-of-scope implementation
$out=Assert-Classification 'out-of-scope' @('scripts/**','tests/**') @('lib/escape.ps1','tests/escape.tests.ps1') $false $false $true $false
Assert ($out.invalid_files -contains 'lib/escape.ps1') 'Out-of-scope implementation was not retained as invalid'
# 7. implementation + tests + docs
Assert-Classification 'implementation-tests-docs' @('modules/**','tests/**','docs/**') @('modules/core.psm1','tests/core.tests.ps1','docs/usage.md') $true $true $true $true | Out-Null
# 8. process exit zero with no meaningful changes is represented by no progress
Assert-Classification 'no-changes' @('scripts/**','tests/**') @() $false $false $false $true | Out-Null
Write-Output 'Contract-aware progress classifier regression tests passed.'
exit 0
