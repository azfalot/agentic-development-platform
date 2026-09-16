param(
  [string]$TargetDirectory=(Join-Path $env:USERPROFILE 'Documents'),
  [string]$BaselinePath=(Join-Path $PSScriptRoot '..\guardrails\baseline-v1.json'),
  [string]$TaskRepository='',
  [switch]$AsJson
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'GuardrailGate.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'GlobalGuardrailAudit.psm1') -Force
if(-not(Test-Path -LiteralPath $BaselinePath)){throw 'GUARDRAIL_BASELINE_MISSING'}
$baseline=Get-Content -Raw $BaselinePath|ConvertFrom-Json
$current=Get-GlobalGuardrailFindings -TargetDirectory $TargetDirectory
$report=Compare-GuardrailFindings -Baseline $baseline -Current $current -TaskRepository $TaskRepository
if($AsJson){$report|ConvertTo-Json -Depth 10;exit 0}
Write-Host '=== Auditoria de Guardrails Globales ===' -ForegroundColor Cyan
Write-Host "GLOBAL_GUARDRAIL_STATUS = $($report.global_guardrail_status)"
Write-Host "TASK_GUARDRAIL_GATE = $($report.task_guardrail_gate)"
Write-Host "baseline_count=$($report.baseline_count); current_count=$($report.current_count); unchanged_baseline_count=$($report.unchanged_baseline_count); new_regression_count=$($report.new_regression_count); resolved_baseline_count=$($report.resolved_baseline_count)"
foreach($finding in $report.baseline_findings){Write-Host "[BASELINE_FINDING] $($finding.id)" -ForegroundColor Yellow}
foreach($finding in $report.new_regressions){Write-Host "[NEW_REGRESSION] $($finding.id)" -ForegroundColor Red}
foreach($finding in $report.resolved_baseline){Write-Host "[RESOLVED_BASELINE] $($finding.id)" -ForegroundColor Green}
