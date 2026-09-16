$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1') -Force
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
$root=Join-Path $env:TEMP ('agenthub-task-budgets-'+[guid]::NewGuid());New-Item -ItemType Directory $root|Out-Null
function BudgetPath([string]$task){Get-TaskExecutionBudgetPath -Repository $root -TaskId $task}

# Historical global budget is read-only migration evidence and cannot authorize another task.
$historical=Join-Path $root '.agenthub-execution-budget.json'
@{authorized_real_invocations=1;consumed_real_invocations=1;remaining_real_invocations=0}|ConvertTo-Json|Set-Content $historical -Encoding utf8
$historicalHash=(Get-FileHash $historical).Hash
$taskA='DOGFOODING_01';$taskB='DOGFOODING_02';$pathA=BudgetPath $taskA;$pathB=BudgetPath $taskB
Assert ($pathA -ne $pathB -and $pathA -ne $historical) 'Task budgets are not isolated from each other and legacy state'

# Task A exhausted does not block explicitly authorized task B; reinitialization cannot replenish A.
Initialize-ExecutionBudget -Path $pathA -TaskId $taskA -AuthorizedRealInvocations 1|Out-Null
Consume-ExecutionBudgetAtomically -Path $pathA -TaskId $taskA|Out-Null
$aBefore=Get-Content $pathA -Raw
$aRestart=Initialize-ExecutionBudget -Path $pathA -TaskId $taskA -AuthorizedRealInvocations 1
Assert ($aRestart.authorized_real_invocations -eq 1 -and $aRestart.consumed_real_invocations -eq 1 -and $aRestart.remaining_real_invocations -eq 0) 'Exhausted task replenished itself'
Assert ((Get-Content $pathA -Raw) -eq $aBefore) 'Restart modified exhausted task budget'
$b=Initialize-ExecutionBudget -Path $pathB -TaskId $taskB -AuthorizedRealInvocations 1
Assert ($b.authorized_real_invocations -eq 1 -and $b.consumed_real_invocations -eq 0 -and $b.remaining_real_invocations -eq 1) 'Authorized task B did not receive an independent budget'
Assert ((Get-FileHash $historical).Hash -eq $historicalHash) 'Historical global budget was modified'

# Cross-task borrowing and task-ID mismatches fail closed.
try{Consume-ExecutionBudgetAtomically -Path $pathB -TaskId $taskA|Out-Null;throw 'Task A consumed task B budget'}catch{Assert ($_.Exception.Message -eq 'EXECUTION_BUDGET_TASK_ID_MISMATCH') 'Cross-task mismatch did not fail closed'}
Assert ((Get-Content $pathB -Raw|ConvertFrom-Json).remaining_real_invocations -eq 1) 'Cross-task attempt changed task B budget'

# A newly created task without explicit authorization remains blocked.
$taskC='unapproved';$pathC=BudgetPath $taskC;Initialize-ExecutionBudget -Path $pathC -TaskId $taskC -AuthorizedRealInvocations 0|Out-Null
try{Consume-ExecutionBudgetAtomically -Path $pathC -TaskId $taskC|Out-Null;throw 'Unapproved task consumed budget'}catch{Assert ($_.Exception.Message -eq 'REAL_EXECUTION_BUDGET_DENIED') 'Unapproved task did not fail closed'}

# Exactly-once consumption persists across a restart.
Consume-ExecutionBudgetAtomically -Path $pathB -TaskId $taskB|Out-Null
try{Consume-ExecutionBudgetAtomically -Path $pathB -TaskId $taskB|Out-Null;throw 'Task B consumed twice'}catch{Assert ($_.Exception.Message -eq 'REAL_EXECUTION_BUDGET_DENIED') 'Exactly-once denial is incorrect'}
$bRestart=Initialize-ExecutionBudget -Path $pathB -TaskId $taskB -AuthorizedRealInvocations 1
Assert ($bRestart.consumed_real_invocations -eq 1 -and $bRestart.remaining_real_invocations -eq 0) 'Task B restart changed persisted consumption'

# Malformed persisted budget fails closed.
$taskMalformed='malformed';$pathMalformed=BudgetPath $taskMalformed;New-Item -ItemType Directory (Split-Path $pathMalformed) -Force|Out-Null;Set-Content $pathMalformed '{not-json' -Encoding utf8
try{Initialize-ExecutionBudget -Path $pathMalformed -TaskId $taskMalformed -AuthorizedRealInvocations 1|Out-Null;throw 'Malformed budget accepted'}catch{Assert ($_.Exception.Message -eq 'EXECUTION_BUDGET_MALFORMED') 'Malformed budget did not fail closed'}

# Failed persistence never runs an executor and leaves authorization available.
$taskFailure='persistence-failure';$pathFailure=BudgetPath $taskFailure;Initialize-ExecutionBudget -Path $pathFailure -TaskId $taskFailure -AuthorizedRealInvocations 1|Out-Null;$global:BudgetExecutorCalled=$false
try{Invoke-AuthorizedExecution -BudgetPath $pathFailure -TaskId $taskFailure -PersistenceAction {param($tmp,$dest,$backup)throw 'SIMULATED_PERSISTENCE_FAILURE'} -Executor {param($transaction)$global:BudgetExecutorCalled=$true};throw 'Persistence failure was accepted'}catch{Assert ($_.Exception.Message -eq 'SIMULATED_PERSISTENCE_FAILURE') 'Unexpected persistence failure'}
Assert (-not $global:BudgetExecutorCalled) 'Failed persistence spawned executor';Assert ((Get-Content $pathFailure -Raw|ConvertFrom-Json).consumed_real_invocations -eq 0) 'Failed persistence consumed budget'
Remove-Variable BudgetExecutorCalled -Scope Global -ErrorAction SilentlyContinue

# Concurrent consumers of a single task authorization produce exactly one success.
$taskConcurrent='concurrent';$pathConcurrent=BudgetPath $taskConcurrent;Initialize-ExecutionBudget -Path $pathConcurrent -TaskId $taskConcurrent -AuthorizedRealInvocations 1|Out-Null;$module=Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1'
$jobs=1..4|ForEach-Object{Start-Job -ScriptBlock {param($modulePath,$budgetPath,$taskId)Import-Module $modulePath -Force;try{Consume-ExecutionBudgetAtomically -Path $budgetPath -TaskId $taskId|Out-Null;'SUCCESS'}catch{'DENIED'}} -ArgumentList $module,$pathConcurrent,$taskConcurrent}
Wait-Job $jobs|Out-Null;$out=@($jobs|Receive-Job);$jobs|Remove-Job
Assert ((@($out|Where-Object{$_ -eq 'SUCCESS'}).Count -eq 1) -and (@($out|Where-Object{$_ -eq 'DENIED'}).Count -eq 3)) 'Concurrent consumption was not exactly-once'
Assert ((Get-Content $pathConcurrent -Raw|ConvertFrom-Json).consumed_real_invocations -eq 1) 'Concurrent persisted state is incorrect'
Assert ((Get-FileHash $historical).Hash -eq $historicalHash) 'Historical task budget changed outside valid consumption'

# Regression reproduction: an empty File.Replace backup path is invalid, while the gate supplies an owned backup.
$repro=BudgetPath 'replace-repro';Initialize-ExecutionBudget -Path $repro -TaskId 'replace-repro' -AuthorizedRealInvocations 1|Out-Null;$reproTemp=$repro+'.repro.tmp';Set-Content $reproTemp '{}' -Encoding utf8
try{[IO.File]::Replace($reproTemp,$repro,$null);throw 'Empty backup path was accepted'}catch{Assert ($_.Exception.Message -match 'path is empty|path.*empty') 'Original empty-backup failure was not reproduced'}finally{if(Test-Path $reproTemp){Remove-Item $reproTemp -Force}}
Write-Output 'Task-scoped execution-budget lifecycle and atomic persistence tests passed.'
exit 0
