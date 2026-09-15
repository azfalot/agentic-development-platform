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
function Get-CodexCommandContract { param([string]$Executable,[string]$Prompt,[string]$WorkingDirectory)
  if($Prompt -match "[\r\n]"){throw 'PROMPT_BOUNDARY_INVALID'};return @{file=$Executable;arguments=@('exec','--sandbox','elevated',$Prompt);working_directory=$WorkingDirectory;inherits_environment=$true}
}
Export-ModuleMember -Function Get-AgentHubExecutionResult,Test-AgentHubTaskSuccess,Test-ExecutionBudget,Consume-ExecutionBudget,Get-CodexCommandContract
