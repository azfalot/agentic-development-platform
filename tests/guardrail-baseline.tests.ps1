$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\GuardrailGate.psm1') -Force
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function New-Finding([int]$number,[string]$repository='legacy'){
  [pscustomobject]@{rule='DUPLICATE_POSTGRES_SERVICE';repository=$repository;path="$repository/project-$number/compose.yml"}
}
function New-Baseline($findings){
  $items=@($findings|ForEach-Object{[pscustomobject]@{id=(Get-GuardrailIdentity $_);rule=$_.rule;repository=$_.repository;path=$_.path}})
  [pscustomobject]@{schema_version=1;initialization=[pscustomobject]@{authorized_by='test'};findings=$items}
}
$baseFindings=@(1..24|ForEach-Object{New-Finding $_})
$baseline=New-Baseline $baseFindings

# A and F: same identities, including legacy/unrelated findings, pass the task gate.
$same=Compare-GuardrailFindings -Baseline $baseline -Current $baseFindings -TaskRepository 'task-repository'
Assert ($same.task_guardrail_gate -eq 'PASS_NO_NEW_REGRESSIONS' -and $same.unchanged_baseline_count -eq 24) 'A/F baseline-only comparison failed'
# B: a distinct current identity fails.
$withNew=Compare-GuardrailFindings -Baseline $baseline -Current @($baseFindings+(New-Finding 25))
Assert ($withNew.task_guardrail_gate -eq 'FAIL_NEW_REGRESSION' -and $withNew.new_regression_count -eq 1) 'B new regression was not blocked'
# C: removal is a positive resolved-baseline result.
$resolved=Compare-GuardrailFindings -Baseline $baseline -Current $baseFindings[0..22]
Assert ($resolved.task_guardrail_gate -eq 'PASS_NO_NEW_REGRESSIONS' -and $resolved.resolved_baseline_count -eq 1) 'C resolved baseline was not recorded'
# D: equal counts do not hide identity replacement.
$replacement=Compare-GuardrailFindings -Baseline $baseline -Current @($baseFindings[0..22]+(New-Finding 25))
Assert ($replacement.new_regression_count -eq 1 -and $replacement.resolved_baseline_count -eq 1 -and $replacement.task_guardrail_gate -eq 'FAIL_NEW_REGRESSION') 'D identity swap was not blocked'
# E: new task-repository finding is identified and blocked.
$taskNew=New-Finding 1 'task-repository'
$taskResult=Compare-GuardrailFindings -Baseline $baseline -Current @($baseFindings+$taskNew) -TaskRepository 'task-repository'
Assert ($taskResult.task_guardrail_gate -eq 'FAIL_NEW_REGRESSION' -and $taskResult.task_scope_new_regressions.Count -eq 1) 'E task-scope regression was not blocked'
# G/H: absent or malformed baseline fails closed.
try{Test-GuardrailBaseline $null|Out-Null;throw 'G missing baseline accepted'}catch{Assert ($_.Exception.Message -eq 'GUARDRAIL_BASELINE_INVALID') 'G incorrect missing-baseline result'}
try{Test-GuardrailBaseline ([pscustomobject]@{schema_version=1;initialization=$null;findings=@()})|Out-Null;throw 'H malformed baseline accepted'}catch{Assert ($_.Exception.Message -eq 'GUARDRAIL_BASELINE_INVALID') 'H incorrect malformed-baseline result'}
Write-Output 'Guardrail baseline and regression identity tests A-H passed.'
