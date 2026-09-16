$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1') -Force
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function New-TestPath([string]$name){$root=Join-Path $env:TEMP ('agenthub-budget-'+[guid]::NewGuid());New-Item -ItemType Directory $root|Out-Null;Join-Path $root $name}

# Regression reproduction: File.Replace with an empty backup path throws on Windows/.NET.
$repro=New-TestPath 'budget.json';Initialize-ExecutionBudget $repro 1|Out-Null;$reproTemp=$repro+'.repro.tmp';Set-Content -LiteralPath $reproTemp -Value '{}' -Encoding utf8
try{[IO.File]::Replace($reproTemp,$repro,$null);throw 'Empty backup path was accepted'}catch{Assert ($_.Exception.Message -match 'path is empty|path.*empty') 'Original empty-backup failure was not reproduced'}finally{if(Test-Path $reproTemp){Remove-Item $reproTemp -Force}}

# Initial creation and an existing-file update use owned temp/backup paths.
$path=New-TestPath 'budget.json';$initial=Initialize-ExecutionBudget $path 1;Assert ($initial.remaining_real_invocations -eq 1 -and (Test-Path $path)) 'Initial budget creation failed'
$transaction=Consume-ExecutionBudgetAtomically $path;Assert ($transaction.before.consumed_real_invocations -eq 0 -and $transaction.after.consumed_real_invocations -eq 1) 'Existing budget was not atomically consumed'
Assert ([bool]$transaction.backup_path -and (Test-Path $transaction.backup_path)) 'Atomic replacement did not use a valid backup path'
$stored=Get-Content -Raw $path|ConvertFrom-Json;Assert ($stored.remaining_real_invocations -eq 0) 'Persisted budget is incorrect'
try{Consume-ExecutionBudgetAtomically $path|Out-Null;throw 'Exactly-once budget was consumed twice'}catch{Assert ($_.Exception.Message -eq 'REAL_EXECUTION_BUDGET_DENIED') 'Exactly-once denial is incorrect'}

# Owned orphan temps are safely removed under the budget lock.
$orphan=$path+'.orphan.tmp';Set-Content -LiteralPath $orphan -Value 'orphan';$fresh=New-TestPath 'fresh.json';Initialize-ExecutionBudget $fresh 1|Out-Null;$freshOrphan=$fresh+'.orphan.tmp';Set-Content -LiteralPath $freshOrphan -Value 'orphan';Consume-ExecutionBudgetAtomically $fresh|Out-Null;Assert (-not(Test-Path $freshOrphan)) 'Owned orphan temporary file was not cleaned'

# A persistence failure is fail-closed and never invokes the agent executor.
$failed=New-TestPath 'failed.json';Initialize-ExecutionBudget $failed 1|Out-Null;$global:BudgetExecutorCalled=$false
try{Invoke-AuthorizedExecution -BudgetPath $failed -PersistenceAction {param($tmp,$dest,$backup)throw 'SIMULATED_PERSISTENCE_FAILURE'} -Executor {param($transaction)$global:BudgetExecutorCalled=$true};throw 'Persistence failure was accepted'}catch{Assert ($_.Exception.Message -eq 'SIMULATED_PERSISTENCE_FAILURE') 'Unexpected persistence failure'}
Assert (-not $global:BudgetExecutorCalled) 'Failed persistence spawned executor';Assert ((Get-Content -Raw $failed|ConvertFrom-Json).consumed_real_invocations -eq 0) 'Failed persistence consumed budget'
Remove-Variable BudgetExecutorCalled -Scope Global -ErrorAction SilentlyContinue

# Concurrent consumers of one authorization produce exactly one success.
$concurrent=New-TestPath 'concurrent.json';Initialize-ExecutionBudget $concurrent 1|Out-Null;$module=Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1'
$jobs=1..4|ForEach-Object{Start-Job -ScriptBlock {param($modulePath,$budgetPath)Import-Module $modulePath -Force;try{Consume-ExecutionBudgetAtomically $budgetPath|Out-Null;'SUCCESS'}catch{'DENIED'}} -ArgumentList $module,$concurrent}
Wait-Job $jobs|Out-Null;$out=@($jobs|Receive-Job);$jobs|Remove-Job
Assert ((@($out|Where-Object{$_ -eq 'SUCCESS'}).Count -eq 1) -and (@($out|Where-Object{$_ -eq 'DENIED'}).Count -eq 3)) 'Concurrent consumption was not exactly-once'
Assert ((Get-Content -Raw $concurrent|ConvertFrom-Json).consumed_real_invocations -eq 1) 'Concurrent persisted state is incorrect'
Write-Output 'Execution-budget persistence regression tests passed.'
