$ErrorActionPreference='Stop'
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}

$hub=Join-Path $PSScriptRoot '..\scripts\agenthub.ps1'
$root=Join-Path $env:TEMP ('agenthub-status-'+[guid]::NewGuid())
New-Item -ItemType Directory $root|Out-Null
$contract=@{
  schema_version=2
  task=@{id='status-task';source='local';repository=$root;issue=$null}
  goal='Display task status'
  assignment=@{role='implementer';engine='codex'}
  state='IMPLEMENTING'
  scope=@{bounded_context='status-command';allowed=@('scripts/**');forbidden=@('.git/**')}
  permissions=@{filesystem='scoped-write';git_write=$true;github_write=$true;merge=$false;production='denied'}
  ownership=@{task='status-task';branch='feature/status-task';bounded_context='status-command';files=@('scripts/**');migrations=@()}
  acceptance_criteria=@()
  verification=@{build='NOT_APPLICABLE';lint='NOT_APPLICABLE';unit='NOT_RUN';integration='NOT_APPLICABLE';e2e='NOT_APPLICABLE';guardrails='NOT_RUN';ci='NOT_RUN'}
  evidence=@{commit_sha=$null;changed_files=@();test_results=@();build_result=$null;playwright=$null;ci=$null;pull_request=$null}
  handoff=@{target_role='human';reason='test'}
  timestamps=@{created='2026-09-17T00:00:00Z';updated='2026-09-17T00:00:00Z'}
}
$path=Join-Path $root 'contract.json'
$contract|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding utf8
$before=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
$output=@(& pwsh -NoProfile -File $hub status $path)
Assert ($LASTEXITCODE -eq 0) 'Status failed without a budget'
Assert (($output -join "`n") -eq (@(
  'Task ID: status-task',
  'State: IMPLEMENTING',
  'Assigned role: implementer',
  'Engine: codex',
  "Repository: $root",
  'Bounded context: status-command',
  'Execution budget: not present'
) -join "`n")) 'Status output without a budget was not deterministic'
Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $before) 'Status mutated the contract'

Import-Module (Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1') -Force -DisableNameChecking
$budgetPath=Get-TaskExecutionBudgetPath -Repository $root -TaskId 'status-task'
Initialize-ExecutionBudget -Path $budgetPath -TaskId 'status-task' -AuthorizedRealInvocations 3|Out-Null
$budget=Get-Content -Raw -LiteralPath $budgetPath|ConvertFrom-Json -AsHashtable
$budget.consumed_real_invocations=1
$budget.remaining_real_invocations=2
$budget|ConvertTo-Json|Set-Content -LiteralPath $budgetPath -Encoding utf8
$output=@(& pwsh -NoProfile -File $hub status $path)
Assert ($LASTEXITCODE -eq 0) 'Status failed with a budget'
Assert (($output -join "`n") -eq (@(
  'Task ID: status-task',
  'State: IMPLEMENTING',
  'Assigned role: implementer',
  'Engine: codex',
  "Repository: $root",
  'Bounded context: status-command',
  'Execution budget: remaining 2 of 3 (consumed 1)'
) -join "`n")) 'Status output with a budget was not deterministic'
Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $before) 'Status mutated the contract while reading a budget'
Write-Output 'AgentHub status command tests passed.'
