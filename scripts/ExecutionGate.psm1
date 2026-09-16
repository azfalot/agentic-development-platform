function Get-AgentHubExecutionResult {
  param([bool]$ProcessCompleted,[bool]$ProgressDetected,[bool]$ScopeValid,[bool]$VerificationPassed,[bool]$ToolFailure)
  if(-not $ProcessCompleted){return 'PROCESS_FAILURE'}
  if($ToolFailure){return 'TOOL_FAILURE'}
  if(-not $ProgressDetected){return 'NO_PROGRESS'}
  if(-not $ScopeValid){return 'SCOPE_VIOLATION'}
  if(-not $VerificationPassed){return 'VERIFICATION_FAILURE'}
  return 'SUCCESS'
}
function Test-AgentHubTaskSuccess { param($Result) return $Result -eq 'SUCCESS' }
function Test-ExecutionBudget { param([hashtable]$Budget,[bool]$IsMock)
  if($IsMock){return $true};return ($Budget.authorized_real_invocations - $Budget.consumed_real_invocations) -gt 0
}
function Consume-ExecutionBudget { param([hashtable]$Budget,[bool]$IsMock)
  if(-not(Test-ExecutionBudget $Budget $IsMock)){throw 'REAL_EXECUTION_BUDGET_DENIED'};if(-not$IsMock){$Budget.consumed_real_invocations++};$Budget.remaining_real_invocations=$Budget.authorized_real_invocations-$Budget.consumed_real_invocations;return $Budget
}
function Remove-ExecutionBudgetTemporaryFiles {
  param([string]$Path)
  $directory=Split-Path $Path -Parent;$name=Split-Path $Path -Leaf
  foreach($file in @(Get-ChildItem -LiteralPath $directory -Filter ($name+'.*.tmp') -File -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $file.FullName -Force}
}
function Initialize-ExecutionBudget {
  param([string]$Path,[int]$AuthorizedRealInvocations)
  if(Test-Path -LiteralPath $Path){return Get-Content -Raw $Path|ConvertFrom-Json -AsHashtable}
  $budget=@{authorized_real_invocations=$AuthorizedRealInvocations;consumed_real_invocations=0;remaining_real_invocations=$AuthorizedRealInvocations}
  $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try{$budget|ConvertTo-Json|Set-Content -LiteralPath $temporary -Encoding utf8;[IO.File]::Move($temporary,$Path);return $budget}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
}
function Enter-ExecutionBudgetLock {
  param([string]$Path,[int]$TimeoutMilliseconds=5000)
  $lockPath=$Path+'.lock';$stopwatch=[Diagnostics.Stopwatch]::StartNew()
  do {try{return [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch [IO.IOException] {Start-Sleep -Milliseconds 25}} while($stopwatch.ElapsedMilliseconds -lt $TimeoutMilliseconds)
  throw 'EXECUTION_BUDGET_LOCK_UNAVAILABLE'
}
function Consume-ExecutionBudgetAtomically {
  param([string]$Path,[scriptblock]$PersistenceAction)
  $lock=Enter-ExecutionBudgetLock $Path
  try {
    Remove-ExecutionBudgetTemporaryFiles $Path
    if(-not(Test-Path -LiteralPath $Path)){throw 'EXECUTION_BUDGET_MISSING'}
    $budget=Get-Content -Raw $Path|ConvertFrom-Json -AsHashtable
    $before=@{authorized_real_invocations=$budget.authorized_real_invocations;consumed_real_invocations=$budget.consumed_real_invocations;remaining_real_invocations=$budget.remaining_real_invocations}
    if(-not(Test-ExecutionBudget $budget $false)){throw 'REAL_EXECUTION_BUDGET_DENIED'}
    Consume-ExecutionBudget $budget $false|Out-Null
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp';$backup=$Path+'.'+[guid]::NewGuid().ToString('N')+'.bak'
    try {
      $budget|ConvertTo-Json|Set-Content -LiteralPath $temporary -Encoding utf8
      if($PersistenceAction){& $PersistenceAction $temporary $Path $backup}else{[IO.File]::Replace($temporary,$Path,$backup)}
    } catch {throw $_} finally {if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
    [pscustomobject]@{before=$before;after=$budget;backup_path=$backup}
  } finally {$lock.Dispose();Remove-Item -LiteralPath ($Path+'.lock') -Force -ErrorAction SilentlyContinue}
}
function Invoke-AuthorizedExecution {
  param([string]$BudgetPath,[scriptblock]$Executor,[scriptblock]$PersistenceAction)
  $transaction=Consume-ExecutionBudgetAtomically -Path $BudgetPath -PersistenceAction $PersistenceAction
  $result=& $Executor $transaction
  [pscustomobject]@{transaction=$transaction;result=$result}
}
function Get-CodexCommandContract { param([string]$Executable,[string]$Prompt,[string]$WorkingDirectory)
  if($Prompt -match "[\r\n]"){throw 'PROMPT_BOUNDARY_INVALID'};return @{file=$Executable;arguments=@('exec','--sandbox','elevated',$Prompt);working_directory=$WorkingDirectory;inherits_environment=$true}
}
Export-ModuleMember -Function Get-AgentHubExecutionResult,Test-AgentHubTaskSuccess,Test-ExecutionBudget,Consume-ExecutionBudget,Initialize-ExecutionBudget,Consume-ExecutionBudgetAtomically,Invoke-AuthorizedExecution,Get-CodexCommandContract
